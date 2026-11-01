// Supabase Edge Function: send-push. Deployed with --no-verify-jwt; the
// caller (backend code, never the app) sends x-push-secret. See handler.ts
// and supabase/README.md.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleSendPush } from "./handler.ts";
import { type ApnsConfig, type FcmConfig, sendApns, sendFcm } from "./push.ts";

const env = (n: string) => Deno.env.get(n);
const admin = createClient(
  env("SUPABASE_URL")!,
  env("SUPABASE_SERVICE_ROLE_KEY")!,
  {
    auth: { persistSession: false, autoRefreshToken: false },
  },
);

const apns: ApnsConfig | null = env("APNS_TEAM_ID") && env("APNS_KEY_ID") &&
    env("APNS_PRIVATE_KEY")
  ? {
    teamId: env("APNS_TEAM_ID")!,
    keyId: env("APNS_KEY_ID")!,
    privateKeyPem: env("APNS_PRIVATE_KEY")!,
    bundleId: env("APNS_BUNDLE_ID") || "com.ronganminh.repCounterApp",
    sandbox: env("APNS_ENV") !== "production",
  }
  : null;

const fcm: FcmConfig | null = (() => {
  try {
    const sa = JSON.parse(env("FCM_SERVICE_ACCOUNT_JSON") ?? "");
    return typeof sa?.project_id === "string"
      ? {
        projectId: sa.project_id,
        clientEmail: sa.client_email,
        privateKeyPem: sa.private_key,
      }
      : null;
  } catch {
    return null;
  }
})();

Deno.serve((req) =>
  handleSendPush(req, {
    secret: env("PUSH_SEND_SECRET") ?? "",
    async createInbox(userId, kind, link, title, body) {
      const { data, error } = await admin.rpc("inbox_create", {
        p_user: userId,
        p_kind: kind,
        p_link: link,
        p_title: title,
        p_body: body,
      });
      if (error) throw new Error("inbox_create failed");
      return data;
    },
    deliver: (t, msg) =>
      t.platform === "apns"
        ? (apns ? sendApns(t.token, msg, apns) : null)
        : (fcm ? sendFcm(t.token, msg, fcm) : null),
    async dropToken(token) {
      await admin.rpc("push_drop_token", { p_token: token });
    },
    log: (event, fields) => console.log(JSON.stringify({ event, ...fields })),
  })
);
