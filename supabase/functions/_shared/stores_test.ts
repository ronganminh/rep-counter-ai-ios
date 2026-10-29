import { assert, assertEquals } from "./assert.ts";
import {
  appStoreState,
  appStoreToken,
  appStoreTransactionId,
  playAcknowledge,
  playState,
  StoreUnavailable,
} from "./stores.ts";
import { loadStoreConfig } from "./store_config.ts";
import {
  b64urlDecode,
  ecKeyPem,
  fakeJws,
  jsonResponse,
  rsaKeyPem,
} from "./test_helpers.ts";

const PRODUCTS = ["pro.monthly", "pro.annual"];

Deno.test("App Store token: ES256, kid, audience and bundle id", async () => {
  const { pem, publicKey } = await ecKeyPem();
  const cfg = {
    issuerId: "iss",
    keyId: "KEY1",
    privateKeyPem: pem,
    bundleId: "b",
  };
  const jwt = await appStoreToken(cfg, 1_000);
  const [h, p, s] = jwt.split(".");
  const header = JSON.parse(new TextDecoder().decode(b64urlDecode(h)));
  const payload = JSON.parse(new TextDecoder().decode(b64urlDecode(p)));
  assertEquals(header, { alg: "ES256", typ: "JWT", kid: "KEY1" });
  assertEquals(payload, {
    iss: "iss",
    iat: 1000,
    exp: 1300,
    aud: "appstoreconnect-v1",
    bid: "b",
  });
  assert(
    await crypto.subtle.verify(
      { name: "ECDSA", hash: "SHA-256" },
      publicKey,
      b64urlDecode(s),
      new TextEncoder().encode(`${h}.${p}`),
    ),
    "signature verifies",
  );
});

Deno.test("transaction id is read from the signed transaction", () => {
  assertEquals(
    appStoreTransactionId(fakeJws({ transactionId: "2000000123" })),
    "2000000123",
  );
  assertEquals(
    appStoreTransactionId(fakeJws({ transactionId: "x; drop" })),
    null,
  );
  assertEquals(appStoreTransactionId("not a jws"), null);
});

Deno.test("App Store state: sandbox fallback, mapping, product and bundle checks", async () => {
  const { pem } = await ecKeyPem();
  const cfg = {
    issuerId: "i",
    keyId: "k",
    privateKeyPem: pem,
    bundleId: "com.ronganminh.repCounterApp",
  };
  const urls: string[] = [];
  const answer = (status: number, bundleId = cfg.bundleId) => ({
    bundleId,
    data: [{
      lastTransactions: [
        {
          originalTransactionId: "o-other",
          status: 1,
          signedTransactionInfo: fakeJws({ productId: "other.product" }),
        },
        {
          originalTransactionId: "o-1",
          status,
          signedTransactionInfo: fakeJws({
            productId: "pro.monthly",
            expiresDate: Date.UTC(2026, 10, 29),
            appAccountToken: "AAAA-BBBB",
          }),
        },
      ],
    }],
  });
  const fetchFn = (status: number, bundle?: string): typeof fetch => (url) => {
    urls.push(String(url));
    return Promise.resolve(
      String(url).includes("sandbox")
        ? jsonResponse(200, answer(status, bundle))
        : new Response("", { status: 404 }),
    );
  };
  const s = await appStoreState("123", PRODUCTS, cfg, fetchFn(1));
  assertEquals(urls, [
    "https://api.storekit.itunes.apple.com/inApps/v1/subscriptions/123",
    "https://api.storekit-sandbox.itunes.apple.com/inApps/v1/subscriptions/123",
  ]);
  assertEquals(s, {
    platform: "app_store",
    productId: "pro.monthly",
    originalTransactionId: "o-1",
    status: "active",
    expiresAt: "2026-11-29T00:00:00.000Z",
    accountId: "aaaa-bbbb",
  });
  const statuses: [number, string][] = [[2, "expired"], [3, "billing_retry"], [
    4,
    "grace",
  ], [5, "revoked"]];
  for (const [code, status] of statuses) {
    assertEquals(
      (await appStoreState("1", PRODUCTS, cfg, fetchFn(code)))?.status,
      status,
    );
  }
  assertEquals(
    await appStoreState("1", PRODUCTS, cfg, fetchFn(1, "other.app")),
    null,
  );
  assertEquals(await appStoreState("1", ["nothing"], cfg, fetchFn(1)), null);
  const notFound: typeof fetch = () =>
    Promise.resolve(new Response("", { status: 404 }));
  assertEquals(await appStoreState("1", PRODUCTS, cfg, notFound), null);
  let threw = false;
  try {
    await appStoreState(
      "1",
      PRODUCTS,
      cfg,
      () => Promise.resolve(new Response("", { status: 500 })),
    );
  } catch (e) {
    threw = e instanceof StoreUnavailable;
  }
  assert(threw);
});

Deno.test("Play state: service-account token, mapping, ack", async () => {
  const { pem } = await rsaKeyPem();
  const cfg = {
    packageName: "com.ronganminh.repcoach",
    clientEmail: "sa@x.iam.gserviceaccount.com",
    privateKeyPem: pem,
  };
  const calls: { url: string; init?: RequestInit }[] = [];
  const sub = (
    state: string,
    expiry: string,
    ack = "ACKNOWLEDGEMENT_STATE_PENDING",
  ) => ({
    subscriptionState: state,
    acknowledgementState: ack,
    lineItems: [{ productId: "pro.annual", expiryTime: expiry }],
    externalAccountIdentifiers: { obfuscatedExternalAccountId: "USER-1" },
  });
  const fetchFn = (body: unknown): typeof fetch => (url, init) => {
    calls.push({ url: String(url), init });
    if (String(url).startsWith("https://oauth2.googleapis.com/token")) {
      return Promise.resolve(jsonResponse(200, { access_token: "at" }));
    }
    return Promise.resolve(jsonResponse(200, body));
  };
  const future = new Date(Date.now() + 86_400_000).toISOString();
  const past = new Date(Date.now() - 86_400_000).toISOString();
  const r = await playState(
    "tok",
    PRODUCTS,
    cfg,
    fetchFn(sub("SUBSCRIPTION_STATE_ACTIVE", future)),
  );
  assertEquals(r?.state, {
    platform: "play",
    productId: "pro.annual",
    originalTransactionId: "tok",
    status: "active",
    expiresAt: future,
    accountId: "user-1",
  });
  assert(r!.needsAck);
  const form = new URLSearchParams(String(calls[0].init!.body));
  assertEquals(
    form.get("grant_type"),
    "urn:ietf:params:oauth:grant-type:jwt-bearer",
  );
  assertEquals(
    calls[1].url,
    "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.ronganminh.repcoach/purchases/subscriptionsv2/tokens/tok",
  );
  assertEquals(
    (calls[1].init!.headers as Record<string, string>).authorization,
    "Bearer at",
  );

  const cases: [string, string, string][] = [
    ["SUBSCRIPTION_STATE_IN_GRACE_PERIOD", future, "grace"],
    ["SUBSCRIPTION_STATE_ON_HOLD", future, "billing_retry"],
    ["SUBSCRIPTION_STATE_PENDING", future, "pending"],
    ["SUBSCRIPTION_STATE_CANCELED", future, "active"],
    ["SUBSCRIPTION_STATE_CANCELED", past, "expired"],
    ["SUBSCRIPTION_STATE_EXPIRED", past, "expired"],
    ["SUBSCRIPTION_STATE_PAUSED", future, "expired"],
  ];
  for (const [state, expiry, want] of cases) {
    const got = await playState(
      "t",
      PRODUCTS,
      cfg,
      fetchFn(sub(state, expiry, "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED")),
    );
    assertEquals(got?.state.status, want, state);
    assertEquals(got?.needsAck, false);
  }
  assertEquals(
    await playState(
      "t",
      ["x"],
      cfg,
      fetchFn(sub("SUBSCRIPTION_STATE_ACTIVE", future)),
    ),
    null,
  );

  calls.length = 0;
  await playAcknowledge("tok", "pro.annual", cfg, fetchFn({}));
  assertEquals(
    calls[1].url,
    "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.ronganminh.repcoach/purchases/subscriptions/pro.annual/tokens/tok:acknowledge",
  );
  assertEquals(calls[1].init!.method, "POST");
});

Deno.test("config: nothing configured without secrets; product ids parsed", () => {
  const empty = loadStoreConfig(() => undefined);
  assertEquals(empty.productIds, []);
  assertEquals(empty.appStore, null);
  assertEquals(empty.play, null);
  assertEquals(empty.bundleId, "com.ronganminh.repCounterApp");
  assertEquals(empty.packageName, "com.ronganminh.repcoach");
  const env: Record<string, string> = {
    STORE_PRODUCT_IDS: " a , b ,",
    APPSTORE_ISSUER_ID: "i",
    APPSTORE_KEY_ID: "k",
    APPSTORE_PRIVATE_KEY: "pem",
    PLAY_SERVICE_ACCOUNT_JSON: '{"client_email":"e","private_key":"p"}',
  };
  const full = loadStoreConfig((n) => env[n]);
  assertEquals(full.productIds, ["a", "b"]);
  assert(full.appStore !== null && full.play !== null);
  assertEquals(
    loadStoreConfig((n) =>
      n === "PLAY_SERVICE_ACCOUNT_JSON" ? "{bad" : undefined
    ).play,
    null,
  );
});
