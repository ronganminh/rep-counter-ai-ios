// send-push (NT-2, D-19). Called by the backend only (never the app), with
// the x-push-secret header. Writes the inbox row first (inbox_create), then
// pushes the title and the repcoach:// link to each of the user's devices;
// tokens the push service rejects are dropped. Without APNs / FCM
// credentials the inbox row is still written and nothing is pushed.
// Shapes: supabase/contracts/push_inbox.json.

export const KINDS = [
  "friend_request",
  "race",
  "invite",
  "billing",
  "system",
] as const;

export interface DeviceToken {
  token: string;
  platform: "apns" | "fcm";
}

export interface SendPushDeps {
  secret: string;
  createInbox(
    userId: string,
    kind: string,
    link: string,
    title: string,
    body: string | null,
  ): Promise<{ item: { id: string }; tokens: DeviceToken[] }>;
  /** null when that push service is not configured. */
  deliver:
    | ((
      t: DeviceToken,
      msg: { title: string; link: string },
    ) => Promise<"delivered" | "invalid_token" | "failed"> | null)
    | null;
  dropToken(token: string): Promise<void>;
  log?(event: string, fields?: Record<string, unknown>): void;
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export async function handleSendPush(
  req: Request,
  deps: SendPushDeps,
): Promise<Response> {
  const log = deps.log ?? (() => {});
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  const given = req.headers.get("x-push-secret") ?? "";
  if (deps.secret.length < 16 || !timingSafeEqual(given, deps.secret)) {
    return json(401, { error: "unauthorized" });
  }

  let b: Record<string, unknown>;
  try {
    b = JSON.parse(await req.text());
  } catch {
    return json(400, { error: "invalid_body" });
  }
  const userId = b?.["user_id"], kind = b?.["kind"], link = b?.["link"];
  const title = b?.["title"], body = b?.["body"] ?? null;
  if (
    typeof userId !== "string" || !UUID.test(userId) ||
    typeof kind !== "string" || !KINDS.includes(kind as typeof KINDS[number]) ||
    typeof link !== "string" || !link.startsWith("repcoach://") ||
    link.length > 300 ||
    typeof title !== "string" || title.trim().length === 0 ||
    title.length > 120 ||
    (body !== null && (typeof body !== "string" || body.length > 500))
  ) return json(400, { error: "invalid_body" });

  let created;
  try {
    created = await deps.createInbox(
      userId,
      kind,
      link,
      title,
      body as string | null,
    );
  } catch {
    log("send_push", { kind, outcome: "inbox_error" });
    return json(500, { error: "internal" });
  }

  let sent = 0, dropped = 0, failed = 0;
  for (const t of created.tokens) {
    const outcome = await (deps.deliver?.(t, { title, link }) ?? null)?.catch(
      () => "failed" as const,
    );
    if (outcome === null || outcome === undefined) continue; // not configured
    if (outcome === "delivered") sent++;
    else if (outcome === "invalid_token") {
      dropped++;
      await deps.dropToken(t.token).catch(() => {});
    } else failed++;
  }
  log("send_push", { kind, sent, dropped, failed });
  return json(200, { inbox_id: created.item.id, sent, dropped, failed });
}
