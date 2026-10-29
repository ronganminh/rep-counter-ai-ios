import { assert, assertEquals, assertFalse } from "../_shared/assert.ts";
import contract from "../../contracts/entitlements.json" with { type: "json" };
import { type StoreState, StoreUnavailable } from "../_shared/stores.ts";
import { fakeJws } from "../_shared/test_helpers.ts";
import { handleVerifyPurchase, type VerifyDeps } from "./handler.ts";

const edge = contract.edge_functions["verify-purchase"];
const USER = "6f2c4b1e-0000-4000-8000-000000000001";

const state = (over: Partial<StoreState> = {}): StoreState => ({
  platform: "app_store",
  productId: "pro.monthly",
  originalTransactionId: "o-1",
  status: "active",
  expiresAt: "2026-11-29T00:00:00.000Z",
  accountId: USER,
  ...over,
});

function deps(over: Partial<VerifyDeps> = {}) {
  const recorded: StoreState[] = [];
  const acked: StoreState[] = [];
  const lookups: string[] = [];
  const logs: string[] = [];
  const d: VerifyDeps = {
    getUserId: (jwt) => Promise.resolve(jwt === "good" ? USER : null),
    productIds: ["pro.monthly", "pro.annual"],
    storeConfigured: () => true,
    lookup: (_p, id) => {
      lookups.push(id);
      return Promise.resolve({ state: state(), needsAck: false });
    },
    acknowledge: (s) => {
      acked.push(s);
      return Promise.resolve();
    },
    record: (_u, s) => {
      recorded.push(s);
      return Promise.resolve({
        product_id: s.productId,
        status: s.status,
        expires_at: s.expiresAt,
        verified_at: "2026-10-29T12:00:00Z",
        pro: s.status === "active" || s.status === "grace",
      });
    },
    log: (e, f) => logs.push(JSON.stringify({ e, ...f })),
    ...over,
  };
  return { d, recorded, acked, lookups, logs };
}

const req = (body: unknown, auth = "Bearer good") =>
  new Request("http://x/verify-purchase", {
    method: "POST",
    headers: { authorization: auth },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });

const appStoreBody = {
  platform: "app_store",
  product_id: "pro.monthly",
  token: fakeJws({ transactionId: "2000000123" }),
};

Deno.test("verified App Store purchase: recorded and returned (contract)", async () => {
  const f = deps();
  const res = await handleVerifyPurchase(req(appStoreBody), f.d);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(Object.keys(body).sort(), [...edge.response].sort());
  assert(body.pro);
  assertEquals(
    f.lookups,
    ["2000000123"],
    "looked up by transaction id at Apple",
  );
  assertEquals(f.recorded.length, 1);
  assertEquals(Object.keys(appStoreBody).sort(), [...edge.request].sort());
});

Deno.test("pending stays Free (D-10); Play purchases are acknowledged", async () => {
  const f = deps({
    lookup: () =>
      Promise.resolve({
        state: state({
          platform: "play",
          status: "pending",
          originalTransactionId: "tok",
        }),
        needsAck: true,
      }),
  });
  const res = await handleVerifyPurchase(
    req({ platform: "play", product_id: "pro.annual", token: "tok" }),
    f.d,
  );
  assertEquals(res.status, 200);
  assertFalse((await res.json()).pro);
  assertEquals(f.acked.length, 1);
  const ackFails = deps({
    lookup: () =>
      Promise.resolve({ state: state({ platform: "play" }), needsAck: true }),
    acknowledge: () => Promise.reject(new Error("x")),
  });
  assertEquals(
    (await handleVerifyPurchase(
      req({ platform: "play", product_id: "pro.annual", token: "t" }),
      ackFails.d,
    )).status,
    200,
  );
});

Deno.test("refusals", async () => {
  const cases: [Partial<VerifyDeps>, unknown, number, string][] = [
    [{}, { ...appStoreBody, platform: "web" }, 400, "invalid_body"],
    [{}, { ...appStoreBody, token: "" }, 400, "invalid_body"],
    [{}, "{bad", 400, "invalid_body"],
    [{ productIds: [] }, appStoreBody, 503, "not_configured"],
    [{ storeConfigured: () => false }, appStoreBody, 503, "not_configured"],
    [
      {},
      { ...appStoreBody, product_id: "free.trial" },
      422,
      "verification_failed",
    ],
    [{}, { ...appStoreBody, token: "not-a-jws" }, 422, "verification_failed"],
    [
      { lookup: () => Promise.resolve(null) },
      appStoreBody,
      422,
      "verification_failed",
    ],
    [
      { lookup: () => Promise.reject(new StoreUnavailable("apple 500")) },
      appStoreBody,
      502,
      "store_unavailable",
    ],
    [
      {
        lookup: () =>
          Promise.resolve({
            state: state({ accountId: "someone-else" }),
            needsAck: false,
          }),
      },
      appStoreBody,
      403,
      "account_mismatch",
    ],
    [
      { record: () => Promise.resolve({ error: "owned_by_other_account" }) },
      appStoreBody,
      409,
      "owned_by_other_account",
    ],
  ];
  for (const [over, body, status, error] of cases) {
    const f = deps(over);
    const res = await handleVerifyPurchase(req(body), f.d);
    assertEquals(res.status, status, error);
    assertEquals((await res.json()).error, error);
    assertEquals(
      edge.errors[String(status) as keyof typeof edge.errors],
      error,
    );
    if (status !== 409) {
      assertEquals(f.recorded.length, 0, `${error}: nothing recorded`);
    }
  }
});

Deno.test("method, auth, and no account binding set by the app", async () => {
  const f = deps();
  assertEquals(
    (await handleVerifyPurchase(new Request("http://x"), f.d)).status,
    405,
  );
  assertEquals(
    (await handleVerifyPurchase(req(appStoreBody, ""), f.d)).status,
    401,
  );
  assertEquals(
    (await handleVerifyPurchase(req(appStoreBody, "Bearer bad"), f.d)).status,
    401,
  );
  const unbound = deps({
    lookup: () =>
      Promise.resolve({ state: state({ accountId: null }), needsAck: false }),
  });
  assertEquals(
    (await handleVerifyPurchase(req(appStoreBody), unbound.d)).status,
    200,
  );
});

Deno.test("logs carry no token or user id", async () => {
  const f = deps();
  await handleVerifyPurchase(req(appStoreBody), f.d);
  const all = f.logs.join("\n");
  assert(f.logs.length > 0);
  assertFalse(all.includes(appStoreBody.token));
  assertFalse(all.includes(USER));
});
