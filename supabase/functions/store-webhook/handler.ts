// store-webhook (P-1): App Store Server Notifications v2 and Google Play
// Real-time Developer Notifications (Pub/Sub push).
//
// Both stores call a URL that carries ?secret=<STORE_WEBHOOK_SECRET>; any
// other call is refused. The notification is stored raw (store_events,
// service role only) and used only to know WHICH purchase changed: its
// current state is then read from Apple / Google with the project's own
// credentials (the same lookup as verify-purchase), so a forged or replayed
// notification can at most trigger a re-check. Unknown purchases are
// ignored (the app verifies them first). Store errors return 5xx so the
// store retries.
import { decodeJwsPayloadUnverified } from "../_shared/jwt.ts";
import type { Platform, StoreState } from "../_shared/stores.ts";
import { StoreUnavailable } from "../_shared/stores.ts";

export interface WebhookDeps {
  secret: string;
  bundleId: string;
  packageName: string;
  storeConfigured(platform: Platform): boolean;
  lookup(
    platform: Platform,
    id: string,
  ): Promise<{ state: StoreState; needsAck: boolean } | null>;
  acknowledge(state: StoreState): Promise<void>;
  update(state: StoreState): Promise<{ updated: boolean }>;
  logEvent(platform: Platform, payload: unknown): Promise<void>;
  log?(event: string, fields?: Record<string, unknown>): void;
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

// Play notificationType 12 = SUBSCRIPTION_REVOKED (refunded / voided).
const PLAY_REVOKED = 12;

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export async function handleStoreWebhook(
  req: Request,
  deps: WebhookDeps,
): Promise<Response> {
  const log = deps.log ?? (() => {});
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  const secret = new URL(req.url).searchParams.get("secret") ?? "";
  if (deps.secret.length < 16 || !timingSafeEqual(secret, deps.secret)) {
    return json(401, { error: "unauthorized" });
  }

  let body: Record<string, unknown>;
  try {
    const text = await req.text();
    if (text.length > 65_536) return json(400, { error: "invalid_body" });
    body = JSON.parse(text);
  } catch {
    return json(400, { error: "invalid_body" });
  }

  // Which purchase changed, and on which store.
  let platform: Platform;
  let id: string | null = null;
  let revoked = false;
  if (typeof body?.["signedPayload"] === "string") {
    platform = "app_store";
    const n = decodeJwsPayloadUnverified(body["signedPayload"] as string);
    const data = n?.["data"] as Record<string, unknown> | undefined;
    if (data?.["bundleId"] !== deps.bundleId) {
      return json(200, { ok: true, ignored: "other_app" });
    }
    const tx = decodeJwsPayloadUnverified(
      String(data?.["signedTransactionInfo"] ?? ""),
    );
    const txId = tx?.["transactionId"] ?? tx?.["originalTransactionId"];
    id = typeof txId === "string" ? txId : null;
  } else if (
    typeof (body?.["message"] as Record<string, unknown>)?.["data"] === "string"
  ) {
    platform = "play";
    let n: Record<string, unknown> | null = null;
    try {
      n = JSON.parse(
        atob((body["message"] as Record<string, string>)["data"]),
      );
    } catch {
      return json(400, { error: "invalid_body" });
    }
    if (n?.["packageName"] !== deps.packageName) {
      return json(200, { ok: true, ignored: "other_app" });
    }
    if (n?.["testNotification"]) return json(200, { ok: true, test: true });
    const sub = n?.["subscriptionNotification"] as
      | Record<string, unknown>
      | undefined;
    id = typeof sub?.["purchaseToken"] === "string"
      ? sub["purchaseToken"] as string
      : null;
    revoked = sub?.["notificationType"] === PLAY_REVOKED;
  } else {
    return json(400, { error: "invalid_body" });
  }

  await deps.logEvent(platform, body);
  if (!id) return json(200, { ok: true, ignored: "no_purchase" });
  if (!deps.storeConfigured(platform)) {
    log("store_webhook", { platform, outcome: "not_configured" });
    return json(200, { ok: true, ignored: "not_configured" });
  }

  try {
    const found = await deps.lookup(platform, id);
    if (!found) return json(200, { ok: true, ignored: "unknown_purchase" });
    const state = revoked
      ? { ...found.state, status: "revoked" as const }
      : found.state;
    const { updated } = await deps.update(state);
    if (updated && found.needsAck) await deps.acknowledge(found.state);
    log("store_webhook", {
      platform,
      outcome: updated ? "updated" : "unknown",
    });
    return json(200, { ok: true, updated });
  } catch (e) {
    log("store_webhook", {
      platform,
      outcome: e instanceof StoreUnavailable ? "store_unavailable" : "error",
    });
    return json(503, { error: "retry" });
  }
}
