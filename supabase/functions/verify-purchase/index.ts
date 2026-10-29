// Supabase Edge Function: verify-purchase. See handler.ts for the contract
// and supabase/README.md for deployment and secrets.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleVerifyPurchase, type Recorded } from "./handler.ts";
import { loadStoreConfig, storeLookup } from "../_shared/store_config.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);
const cfg = loadStoreConfig((n) => Deno.env.get(n));
const stores = storeLookup(cfg);

Deno.serve((req) =>
  handleVerifyPurchase(req, {
    async getUserId(jwt) {
      const { data, error } = await admin.auth.getUser(jwt);
      return error || !data.user ? null : data.user.id;
    },
    productIds: cfg.productIds,
    ...stores,
    async record(userId, s) {
      const { data, error } = await admin.rpc("entitlement_record", {
        p_user: userId,
        p_platform: s.platform,
        p_product_id: s.productId,
        p_original_transaction_id: s.originalTransactionId,
        p_status: s.status,
        p_expires_at: s.expiresAt,
      });
      if (error) throw new Error("entitlement_record failed");
      return data as Recorded | { error: string };
    },
    log: (event, fields) => console.log(JSON.stringify({ event, ...fields })),
  })
);
