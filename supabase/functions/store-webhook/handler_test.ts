import { assert, assertEquals } from "../_shared/assert.ts";
import { type StoreState, StoreUnavailable } from "../_shared/stores.ts";
import { fakeJws } from "../_shared/test_helpers.ts";
import { handleStoreWebhook, type WebhookDeps } from "./handler.ts";

const SECRET = "0123456789abcdef0123";
const BUNDLE = "com.ronganminh.repCounterApp";
const PACKAGE = "com.ronganminh.repcoach";

const found = (over: Partial<StoreState> = {}) => ({
  state: {
    platform: "app_store" as const,
    productId: "pro.monthly",
    originalTransactionId: "o-1",
    status: "billing_retry" as const,
    expiresAt: null,
    accountId: null,
    ...over,
  },
  needsAck: false,
});

function deps(over: Partial<WebhookDeps> = {}) {
  const updates: StoreState[] = [];
  const events: string[] = [];
  const lookups: string[] = [];
  const acked: string[] = [];
  const d: WebhookDeps = {
    secret: SECRET,
    bundleId: BUNDLE,
    packageName: PACKAGE,
    storeConfigured: () => true,
    lookup: (_p, id) => {
      lookups.push(id);
      return Promise.resolve(found());
    },
    acknowledge: (s) => {
      acked.push(s.originalTransactionId);
      return Promise.resolve();
    },
    update: (s) => {
      updates.push(s);
      return Promise.resolve({ updated: true });
    },
    logEvent: (p) => {
      events.push(p);
      return Promise.resolve();
    },
    ...over,
  };
  return { d, updates, events, lookups, acked };
}

const post = (body: unknown, secret = SECRET) =>
  new Request(`http://x/store-webhook?secret=${secret}`, {
    method: "POST",
    body: typeof body === "string" ? body : JSON.stringify(body),
  });

const apple = (bundleId = BUNDLE) => ({
  signedPayload: fakeJws({
    notificationType: "DID_FAIL_TO_RENEW",
    data: {
      bundleId,
      signedTransactionInfo: fakeJws({ transactionId: "2000000123" }),
    },
  }),
});

const play = (n: Record<string, unknown>) => ({
  message: { data: btoa(JSON.stringify({ packageName: PACKAGE, ...n })) },
});

Deno.test("App Store notification: the state is re-read from Apple", async () => {
  const f = deps();
  const res = await handleStoreWebhook(post(apple()), f.d);
  assertEquals(res.status, 200);
  assertEquals(f.lookups, ["2000000123"]);
  assertEquals(
    f.updates[0].status,
    "billing_retry",
    "from the lookup, not the payload",
  );
  assertEquals(f.events, ["app_store"]);
});

Deno.test("Play notification: revoked, acknowledged when needed, test pings", async () => {
  const f = deps({
    lookup: () =>
      Promise.resolve({
        ...found({
          platform: "play",
          status: "expired",
          originalTransactionId: "tok",
        }),
        needsAck: true,
      }),
  });
  const res = await handleStoreWebhook(
    post(
      play({
        subscriptionNotification: {
          notificationType: 12,
          purchaseToken: "tok",
          subscriptionId: "pro.annual",
        },
      }),
    ),
    f.d,
  );
  assertEquals(res.status, 200);
  assertEquals(f.updates[0].status, "revoked");
  assertEquals(f.acked, ["tok"]);
  const t = deps();
  const ping = await handleStoreWebhook(
    post(play({ testNotification: { version: "1.0" } })),
    t.d,
  );
  assertEquals((await ping.json()).test, true);
  assertEquals(t.updates.length, 0);
});

Deno.test("refused or ignored", async () => {
  const f = deps();
  assertEquals(
    (await handleStoreWebhook(post(apple(), "wrong-secret-0000000"), f.d))
      .status,
    401,
  );
  assertEquals((await handleStoreWebhook(post(apple(), ""), f.d)).status, 401);
  const weak = deps({ secret: "short" });
  assertEquals(
    (await handleStoreWebhook(post(apple(), "short"), weak.d)).status,
    401,
    "weak secret refused",
  );
  assertEquals(
    (await handleStoreWebhook(new Request(`http://x?secret=${SECRET}`), f.d))
      .status,
    405,
  );
  assertEquals((await handleStoreWebhook(post("{bad"), f.d)).status, 400);
  assertEquals((await handleStoreWebhook(post({ hello: 1 }), f.d)).status, 400);
  const other = await handleStoreWebhook(post(apple("other.app")), f.d);
  assertEquals((await other.json()).ignored, "other_app");
  const unknown = deps({ lookup: () => Promise.resolve(null) });
  const u = await handleStoreWebhook(post(apple()), unknown.d);
  assertEquals((await u.json()).ignored, "unknown_purchase");
  assertEquals(unknown.updates.length, 0);
  const off = deps({ storeConfigured: () => false });
  assertEquals(
    (await (await handleStoreWebhook(post(apple()), off.d)).json()).ignored,
    "not_configured",
  );
  assert(f.updates.length === 0);
});

Deno.test("store errors ask the store to retry", async () => {
  const f = deps({
    lookup: () => Promise.reject(new StoreUnavailable("apple 500")),
  });
  assertEquals((await handleStoreWebhook(post(apple()), f.d)).status, 503);
});
