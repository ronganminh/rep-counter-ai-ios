// Supabase Edge Function: delete-account. See handler.ts for the contract
// and supabase/README.md for deployment and secrets.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleDeleteAccount } from "./handler.ts";
import { type AppleConfig, revokeAppleAuthorizationCode } from "./apple.ts";

// Public tables keyed by user_id. Each also has a foreign key to auth.users
// with ON DELETE CASCADE (supabase/migrations), so this explicit pass is a
// second line of defence. Add every new user-owned table here.
export const USER_TABLES = [
  "profiles",
  "workouts",
  "plans",
  "ai_credit_ledger",
  "xp_events",
  "user_progress",
  "achievements_unlocked",
  "entitlements",
] as const;

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const apple: AppleConfig | null = (() => {
  const teamId = Deno.env.get("APPLE_TEAM_ID");
  const keyId = Deno.env.get("APPLE_KEY_ID");
  const privateKeyPem = Deno.env.get("APPLE_PRIVATE_KEY");
  const clientId = Deno.env.get("APPLE_CLIENT_ID") ??
    "com.ronganminh.repCounterApp";
  return teamId && keyId && privateKeyPem
    ? { teamId, keyId, privateKeyPem, clientId }
    : null;
})();

Deno.serve((req) =>
  handleDeleteAccount(req, {
    async getUserId(jwt) {
      const { data, error } = await admin.auth.getUser(jwt);
      return error || !data.user ? null : data.user.id;
    },
    appleConfigured: apple !== null,
    revokeApple: (code) => revokeAppleAuthorizationCode(code, apple!),
    async deleteUserData(userId) {
      for (const table of USER_TABLES) {
        const { error } = await admin.from(table).delete().eq(
          "user_id",
          userId,
        );
        if (error) throw new Error(`delete ${table} failed`);
      }
    },
    async deleteUser(userId) {
      const { error } = await admin.auth.admin.deleteUser(userId);
      if (error) throw new Error("deleteUser failed");
    },
    log: (event, fields) => console.log(JSON.stringify({ event, ...fields })),
  })
);
