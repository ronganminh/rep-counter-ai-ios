// Delivery to APNs (token-based auth, .p8) and FCM HTTP v1 (service
// account). The payload is only a short title and the repcoach:// link
// (06 §7): no body, no personal data.
import { signEs256 } from "../_shared/jwt.ts";
import { googleAccessToken } from "../_shared/stores.ts";

export interface ApnsConfig {
  teamId: string;
  keyId: string;
  privateKeyPem: string;
  bundleId: string;
  sandbox: boolean;
}

export interface FcmConfig {
  projectId: string;
  clientEmail: string;
  privateKeyPem: string;
}

export interface PushMessage {
  title: string;
  link: string;
}

/** delivered | invalid_token (drop it) | failed (keep it, try next time) */
export type PushOutcome = "delivered" | "invalid_token" | "failed";

export function apnsToken(
  cfg: ApnsConfig,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<string> {
  return signEs256(
    { kid: cfg.keyId },
    { iss: cfg.teamId, iat: nowSeconds },
    cfg.privateKeyPem,
  );
}

export async function sendApns(
  deviceToken: string,
  msg: PushMessage,
  cfg: ApnsConfig,
  fetchFn: typeof fetch = fetch,
): Promise<PushOutcome> {
  const host = cfg.sandbox
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
  const res = await fetchFn(
    `${host}/3/device/${encodeURIComponent(deviceToken)}`,
    {
      method: "POST",
      headers: {
        authorization: `bearer ${await apnsToken(cfg)}`,
        "apns-topic": cfg.bundleId,
        "apns-push-type": "alert",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        aps: { alert: { title: msg.title } },
        link: msg.link,
      }),
    },
  );
  if (res.ok) return "delivered";
  if (res.status === 410) return "invalid_token";
  if (res.status === 400) {
    const reason = await res.json().then((b) => b?.reason, () => null);
    if (reason === "BadDeviceToken" || reason === "DeviceTokenNotForTopic") {
      return "invalid_token";
    }
  }
  return "failed";
}

export async function sendFcm(
  deviceToken: string,
  msg: PushMessage,
  cfg: FcmConfig,
  fetchFn: typeof fetch = fetch,
): Promise<PushOutcome> {
  const access = await googleAccessToken(
    cfg,
    fetchFn,
    undefined,
    "https://www.googleapis.com/auth/firebase.messaging",
  );
  const res = await fetchFn(
    `https://fcm.googleapis.com/v1/projects/${
      encodeURIComponent(cfg.projectId)
    }/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${access}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: { title: msg.title },
          data: { link: msg.link },
        },
      }),
    },
  );
  if (res.ok) return "delivered";
  if (res.status === 404) return "invalid_token"; // UNREGISTERED
  return "failed";
}
