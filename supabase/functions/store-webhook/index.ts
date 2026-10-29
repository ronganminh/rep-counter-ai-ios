// Supabase Edge Function: store-webhook. Deployed with --no-verify-jwt (the
// stores send no Supabase JWT); calls must carry ?secret=STORE_WEBHOOK_SECRET.
// See handler.ts and supabase/README.md.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleStoreWebhook } from "./handler.ts";
import { loadStoreConfig, storeLookup } from "../_shared/store_config.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);
const cfg = loadStoreConfig((n) => Deno.env.get(n));
const stores = storeLookup(cfg);

Deno.serve((req) =>
  handleStoreWebhook(req, {
    secret: Deno.env.get("STORE_WEBHOOK_SECRET") ?? "",
    bundleId: cfg.bundleId,
    packageName: cfg.packageName,
    // No product ids yet (D-14): nothing to look up.
    storeConfigured: (p) =>
      cfg.productIds.length > 0 && stores.storeConfigured(p),
    lookup: stores.lookup,
    acknowledge: stores.acknowledge,
    async update(s) {
      const { data, error } = await admin.rpc("entitlement_update_from_store", {
        p_platform: s.platform,
        p_original_transaction_id: s.originalTransactionId,
        p_product_id: s.productId,
        p_status: s.status,
        p_expires_at: s.expiresAt,
      });
      if (error) throw new Error("entitlement_update_from_store failed");
      return { updated: (data as { updated?: boolean })?.updated === true };
    },
    async logEvent(platform, payload) {
      const { error } = await admin.from("store_events").insert({
        platform,
        payload,
      });
      if (error) throw new Error("store_events insert failed");
    },
    log: (event, fields) => console.log(JSON.stringify({ event, ...fields })),
  })
);
