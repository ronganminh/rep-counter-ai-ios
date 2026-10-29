// verify-purchase (P-1; D-10, D-13). Billing stays off until product ids
// exist (D-14): with no STORE_PRODUCT_IDS the function answers 503 and
// records nothing.
//
// The app sends what the store gave it, untouched: the StoreKit 2 signed
// transaction (App Store) or the purchase token (Google Play). The function
// asks Apple / Google for the current state with the project's own
// credentials, checks the purchase belongs to this account (the app sets
// appAccountToken / obfuscatedExternalAccountId to the user id), records
// it (entitlement_record) and acknowledges Play purchases. Pro comes only
// from that server answer; pending purchases and failures stay Free.
// Shapes: supabase/contracts/entitlements.json.
import type { Platform, StoreState } from "../_shared/stores.ts";
import { appStoreTransactionId, StoreUnavailable } from "../_shared/stores.ts";

export interface Recorded {
  product_id: string;
  status: string;
  expires_at: string | null;
  verified_at: string;
  pro: boolean;
}

export interface VerifyDeps {
  getUserId(jwt: string): Promise<string | null>;
  /** STORE_PRODUCT_IDS; empty = billing not configured (D-14). */
  productIds: readonly string[];
  storeConfigured(platform: Platform): boolean;
  /** Apple: a transaction id; Play: the purchase token. Throws
   * StoreUnavailable when the store cannot be reached. */
  lookup(
    platform: Platform,
    id: string,
  ): Promise<{ state: StoreState; needsAck: boolean } | null>;
  acknowledge(state: StoreState): Promise<void>;
  record(
    userId: string,
    state: StoreState,
  ): Promise<Recorded | { error: string }>;
  log?(event: string, fields?: Record<string, unknown>): void;
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

export async function handleVerifyPurchase(
  req: Request,
  deps: VerifyDeps,
): Promise<Response> {
  const log = deps.log ?? (() => {});
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const match = /^Bearer\s+(.+)$/i.exec(req.headers.get("authorization") ?? "");
  if (!match) return json(401, { error: "unauthorized" });
  let userId: string | null;
  try {
    userId = await deps.getUserId(match[1].trim());
  } catch {
    userId = null;
  }
  if (!userId) return json(401, { error: "unauthorized" });

  let body: Record<string, unknown>;
  try {
    const text = await req.text();
    if (text.length > 32_768) return json(400, { error: "invalid_body" });
    body = JSON.parse(text);
  } catch {
    return json(400, { error: "invalid_body" });
  }
  const platform = body?.["platform"];
  const productId = body?.["product_id"];
  const token = body?.["token"];
  if (
    (platform !== "app_store" && platform !== "play") ||
    typeof productId !== "string" || productId.length === 0 ||
    typeof token !== "string" || token.length === 0 ||
    token.length > (platform === "play" ? 1024 : 30_000)
  ) return json(400, { error: "invalid_body" });

  if (deps.productIds.length === 0 || !deps.storeConfigured(platform)) {
    return json(503, { error: "not_configured" });
  }
  if (!deps.productIds.includes(productId)) {
    return json(422, { error: "verification_failed" });
  }

  const id = platform === "app_store" ? appStoreTransactionId(token) : token;
  if (!id) return json(422, { error: "verification_failed" });

  let found;
  try {
    found = await deps.lookup(platform, id);
  } catch (e) {
    log("verify_purchase", { platform, outcome: "store_unavailable" });
    return json(e instanceof StoreUnavailable ? 502 : 500, {
      error: e instanceof StoreUnavailable ? "store_unavailable" : "internal",
    });
  }
  if (!found) {
    log("verify_purchase", { platform, outcome: "not_found" });
    return json(422, { error: "verification_failed" });
  }
  const { state, needsAck } = found;
  if (state.accountId !== null && state.accountId !== userId.toLowerCase()) {
    log("verify_purchase", { platform, outcome: "account_mismatch" });
    return json(403, { error: "account_mismatch" });
  }

  const recorded = await deps.record(userId, state);
  if ("error" in recorded) {
    log("verify_purchase", { platform, outcome: recorded.error });
    return json(409, { error: recorded.error });
  }
  if (needsAck) {
    try {
      await deps.acknowledge(state);
    } catch {
      // store-webhook acknowledges on the next notification; Play gives 3 days.
      log("verify_purchase", { platform, outcome: "ack_failed" });
    }
  }
  log("verify_purchase", { platform, outcome: "ok", status: state.status });
  return json(200, recorded);
}
