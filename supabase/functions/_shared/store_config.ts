// Store credentials for verify-purchase and store-webhook, from Edge
// Function secrets only (supabase/README.md). Nothing here is in git.
import {
  type AppStoreConfig,
  appStoreState,
  type Platform,
  playAcknowledge,
  type PlayConfig,
  playState,
  type StoreState,
} from "./stores.ts";

export interface StoreConfig {
  /** STORE_PRODUCT_IDS (comma separated). Empty until D-14 is decided. */
  productIds: string[];
  appStore: AppStoreConfig | null;
  play: PlayConfig | null;
  bundleId: string;
  packageName: string;
}

export function loadStoreConfig(
  get: (name: string) => string | undefined,
): StoreConfig {
  const bundleId = get("APPSTORE_BUNDLE_ID") || "com.ronganminh.repCounterApp";
  const packageName = get("PLAY_PACKAGE_NAME") || "com.ronganminh.repcoach";
  const issuerId = get("APPSTORE_ISSUER_ID");
  const keyId = get("APPSTORE_KEY_ID");
  const privateKeyPem = get("APPSTORE_PRIVATE_KEY");
  let play: PlayConfig | null = null;
  try {
    const sa = JSON.parse(get("PLAY_SERVICE_ACCOUNT_JSON") ?? "");
    if (
      typeof sa?.client_email === "string" &&
      typeof sa?.private_key === "string"
    ) {
      play = {
        packageName,
        clientEmail: sa.client_email,
        privateKeyPem: sa.private_key,
      };
    }
  } catch {
    play = null;
  }
  return {
    productIds: (get("STORE_PRODUCT_IDS") ?? "")
      .split(",").map((s) => s.trim()).filter((s) => s.length > 0),
    appStore: issuerId && keyId && privateKeyPem
      ? { issuerId, keyId, privateKeyPem, bundleId }
      : null,
    play,
    bundleId,
    packageName,
  };
}

export function storeLookup(cfg: StoreConfig, fetchFn: typeof fetch = fetch) {
  return {
    storeConfigured: (p: Platform) =>
      p === "app_store" ? cfg.appStore !== null : cfg.play !== null,
    async lookup(platform: Platform, id: string) {
      if (platform === "app_store") {
        const state = await appStoreState(
          id,
          cfg.productIds,
          cfg.appStore!,
          fetchFn,
        );
        return state ? { state, needsAck: false } : null;
      }
      return await playState(id, cfg.productIds, cfg.play!, fetchFn);
    },
    acknowledge: (state: StoreState) =>
      state.platform === "play"
        ? playAcknowledge(
          state.originalTransactionId,
          state.productId,
          cfg.play!,
          fetchFn,
        )
        : Promise.resolve(),
  };
}
