// Store purchase state, read from Apple's and Google's server APIs with the
// project's own credentials (never from what the app or a webhook claims).
// Used by verify-purchase and store-webhook (P-1, D-10).
//
// Apple: App Store Server API "Get All Subscription Statuses"
//   GET /inApps/v1/subscriptions/{transactionId}, ES256 JWT (In-App
//   Purchase key .p8, issuer id, key id), production then sandbox on 404.
// Google: Play Developer API purchases.subscriptionsv2.get, OAuth token
//   from a service account (scope androidpublisher), and acknowledge.
import { decodeJwsPayloadUnverified, signEs256, signRs256 } from "./jwt.ts";

export type Platform = "app_store" | "play";
export type EntitlementStatus =
  | "active"
  | "grace"
  | "billing_retry"
  | "expired"
  | "revoked"
  | "pending";

export interface StoreState {
  platform: Platform;
  productId: string;
  originalTransactionId: string;
  status: EntitlementStatus;
  expiresAt: string | null;
  /** appAccountToken (Apple) / obfuscatedExternalAccountId (Google), set
   * by the app at purchase to the user's id; null when not set. */
  accountId: string | null;
}

export class StoreUnavailable extends Error {}

export interface AppStoreConfig {
  issuerId: string;
  keyId: string;
  privateKeyPem: string;
  bundleId: string;
}

export interface PlayConfig {
  packageName: string;
  clientEmail: string;
  privateKeyPem: string;
}

const APPLE_HOSTS = [
  "https://api.storekit.itunes.apple.com",
  "https://api.storekit-sandbox.itunes.apple.com",
];

// https://developer.apple.com/documentation/appstoreserverapi/status
const APPLE_STATUS: Record<number, EntitlementStatus> = {
  1: "active",
  2: "expired",
  3: "billing_retry",
  4: "grace",
  5: "revoked",
};

export function appStoreToken(
  cfg: AppStoreConfig,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<string> {
  return signEs256({ kid: cfg.keyId }, {
    iss: cfg.issuerId,
    iat: nowSeconds,
    exp: nowSeconds + 300,
    aud: "appstoreconnect-v1",
    bid: cfg.bundleId,
  }, cfg.privateKeyPem);
}

/** The transaction id inside a StoreKit 2 signed transaction (JWS). */
export function appStoreTransactionId(
  signedTransaction: string,
): string | null {
  const p = decodeJwsPayloadUnverified(signedTransaction);
  const id = p?.["transactionId"] ?? p?.["originalTransactionId"];
  return typeof id === "string" && /^\d{1,30}$/.test(id) ? id : null;
}

/**
 * The current state of the subscription that [transactionId] belongs to,
 * for one of [productIds]; null when Apple does not know it.
 */
export async function appStoreState(
  transactionId: string,
  productIds: readonly string[],
  cfg: AppStoreConfig,
  fetchFn: typeof fetch = fetch,
): Promise<StoreState | null> {
  const token = await appStoreToken(cfg);
  for (const host of APPLE_HOSTS) {
    const res = await fetchFn(
      `${host}/inApps/v1/subscriptions/${encodeURIComponent(transactionId)}`,
      { headers: { authorization: `Bearer ${token}` } },
    );
    if (res.status === 404) continue;
    if (!res.ok) throw new StoreUnavailable(`apple ${res.status}`);
    // Fetched from Apple over TLS with our credentials: the payloads are
    // Apple's answer, not the client's claim.
    const body = await res.json() as {
      bundleId?: string;
      data?: {
        lastTransactions?: {
          originalTransactionId?: string;
          status?: number;
          signedTransactionInfo?: string;
        }[];
      }[];
    };
    if (body.bundleId !== cfg.bundleId) return null;
    for (const group of body.data ?? []) {
      for (const t of group.lastTransactions ?? []) {
        const info = decodeJwsPayloadUnverified(t.signedTransactionInfo ?? "");
        const productId = info?.["productId"];
        if (
          typeof productId !== "string" || !productIds.includes(productId) ||
          typeof t.originalTransactionId !== "string"
        ) continue;
        const expires = info?.["expiresDate"];
        const account = info?.["appAccountToken"];
        return {
          platform: "app_store",
          productId,
          originalTransactionId: t.originalTransactionId,
          status: APPLE_STATUS[t.status ?? 0] ?? "expired",
          expiresAt: typeof expires === "number"
            ? new Date(expires).toISOString()
            : null,
          accountId: typeof account === "string" ? account.toLowerCase() : null,
        };
      }
    }
    return null;
  }
  return null;
}

export async function googleAccessToken(
  cfg: PlayConfig,
  fetchFn: typeof fetch = fetch,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<string> {
  const assertion = await signRs256({
    iss: cfg.clientEmail,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: nowSeconds,
    exp: nowSeconds + 600,
  }, cfg.privateKeyPem);
  const res = await fetchFn("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) throw new StoreUnavailable(`google token ${res.status}`);
  const token = (await res.json() as { access_token?: unknown }).access_token;
  if (typeof token !== "string") throw new StoreUnavailable("google token");
  return token;
}

// https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2
function playStatus(
  state: string,
  expiresAt: string | null,
): EntitlementStatus {
  switch (state) {
    case "SUBSCRIPTION_STATE_ACTIVE":
      return "active";
    case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD":
      return "grace";
    case "SUBSCRIPTION_STATE_ON_HOLD":
      return "billing_retry";
    case "SUBSCRIPTION_STATE_PENDING":
      return "pending";
    case "SUBSCRIPTION_STATE_CANCELED":
      // Cancelled renewals keep access until the paid period ends.
      return expiresAt && Date.parse(expiresAt) > Date.now()
        ? "active"
        : "expired";
    default: // EXPIRED, PAUSED, PENDING_PURCHASE_CANCELED, unknown
      return "expired";
  }
}

const PLAY = "https://androidpublisher.googleapis.com/androidpublisher/v3";

export async function playState(
  purchaseToken: string,
  productIds: readonly string[],
  cfg: PlayConfig,
  fetchFn: typeof fetch = fetch,
): Promise<{ state: StoreState; needsAck: boolean } | null> {
  const access = await googleAccessToken(cfg, fetchFn);
  const res = await fetchFn(
    `${PLAY}/applications/${encodeURIComponent(cfg.packageName)}` +
      `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
    { headers: { authorization: `Bearer ${access}` } },
  );
  if (res.status === 404 || res.status === 400 || res.status === 410) {
    return null;
  }
  if (!res.ok) throw new StoreUnavailable(`google ${res.status}`);
  const body = await res.json() as {
    subscriptionState?: string;
    acknowledgementState?: string;
    lineItems?: { productId?: string; expiryTime?: string }[];
    externalAccountIdentifiers?: { obfuscatedExternalAccountId?: string };
  };
  const item = (body.lineItems ?? []).find((i) =>
    typeof i.productId === "string" && productIds.includes(i.productId)
  );
  if (!item) return null;
  const expiresAt = item.expiryTime ?? null;
  return {
    state: {
      platform: "play",
      productId: item.productId!,
      originalTransactionId: purchaseToken,
      status: playStatus(body.subscriptionState ?? "", expiresAt),
      expiresAt,
      accountId: body.externalAccountIdentifiers?.obfuscatedExternalAccountId
        ?.toLowerCase() ?? null,
    },
    needsAck: body.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING",
  };
}

/** Play refunds subscriptions not acknowledged within 3 days. */
export async function playAcknowledge(
  purchaseToken: string,
  productId: string,
  cfg: PlayConfig,
  fetchFn: typeof fetch = fetch,
): Promise<void> {
  const access = await googleAccessToken(cfg, fetchFn);
  const res = await fetchFn(
    `${PLAY}/applications/${encodeURIComponent(cfg.packageName)}` +
      `/purchases/subscriptions/${encodeURIComponent(productId)}` +
      `/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${access}`,
        "content-type": "application/json",
      },
      body: "{}",
    },
  );
  if (!res.ok) throw new StoreUnavailable(`google ack ${res.status}`);
}
