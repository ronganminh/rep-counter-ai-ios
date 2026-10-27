// deno test supabase/functions/delete-account/
import { type DeleteAccountDeps, handleDeleteAccount } from "./handler.ts";
import { appleClientSecret, revokeAppleAuthorizationCode } from "./apple.ts";

function assertEquals(actual: unknown, expected: unknown, msg = "") {
  const a = JSON.stringify(actual), e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${msg} expected ${e}, got ${a}`);
}

function deps(over: Partial<DeleteAccountDeps> = {}) {
  const calls: string[] = [];
  const logs: string[] = [];
  const d: DeleteAccountDeps = {
    getUserId: (jwt) => {
      calls.push("getUser");
      return Promise.resolve(jwt === "good-jwt" ? "user-1" : null);
    },
    appleConfigured: true,
    revokeApple: (code) => {
      calls.push(`revoke:${code}`);
      return Promise.resolve(true);
    },
    deleteUserData: (id) => {
      calls.push(`data:${id}`);
      return Promise.resolve();
    },
    deleteUser: (id) => {
      calls.push(`user:${id}`);
      return Promise.resolve();
    },
    log: (event, fields) => logs.push(JSON.stringify({ event, ...fields })),
    ...over,
  };
  return { d, calls, logs };
}

const req = (body?: unknown, auth = "Bearer good-jwt", method = "POST") =>
  new Request("https://x/functions/v1/delete-account", {
    method,
    headers: auth ? { authorization: auth } : {},
    body: body === undefined
      ? undefined
      : typeof body === "string"
      ? body
      : JSON.stringify(body),
  });

Deno.test("deletes data then the auth user", async () => {
  const { d, calls } = deps();
  const res = await handleDeleteAccount(req(), d);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { deleted: true, apple_revoked: null });
  assertEquals(calls, ["getUser", "data:user-1", "user:user-1"]);
});

Deno.test("Apple code: revoke runs before anything is deleted", async () => {
  const { d, calls } = deps();
  const res = await handleDeleteAccount(
    req({ apple_authorization_code: "c0de" }),
    d,
  );
  assertEquals(await res.json(), { deleted: true, apple_revoked: true });
  assertEquals(calls, ["getUser", "revoke:c0de", "data:user-1", "user:user-1"]);
});

Deno.test("failed or unconfigured revoke still deletes, reported", async () => {
  for (
    const over of [
      { revokeApple: () => Promise.reject(new Error("apple down")) },
      { revokeApple: () => Promise.resolve(false) },
      { appleConfigured: false },
    ]
  ) {
    const { d, calls } = deps(over);
    const res = await handleDeleteAccount(
      req({ apple_authorization_code: "c0de" }),
      d,
    );
    assertEquals(await res.json(), { deleted: true, apple_revoked: false });
    assertEquals(calls.slice(-2), ["data:user-1", "user:user-1"]);
  }
});

Deno.test("no or bad token: 401 and nothing deleted", async () => {
  for (const auth of ["", "Basic abc", "Bearer bad-jwt"]) {
    const { d, calls } = deps();
    const res = await handleDeleteAccount(req(undefined, auth), d);
    assertEquals(res.status, 401, auth);
    assertEquals(calls.filter((c) => c !== "getUser"), []);
  }
  const { d } = deps({ getUserId: () => Promise.reject(new Error("x")) });
  assertEquals((await handleDeleteAccount(req(), d)).status, 401);
});

Deno.test("wrong method and invalid bodies are rejected", async () => {
  const { d, calls } = deps();
  assertEquals(
    (await handleDeleteAccount(req(undefined, undefined, "GET"), d)).status,
    405,
  );
  for (
    const body of ["{oops", { apple_authorization_code: 42 }, {
      apple_authorization_code: "",
    }]
  ) {
    assertEquals((await handleDeleteAccount(req(body), d)).status, 400);
  }
  assertEquals(calls, []);
});

Deno.test("deletion failure: 500 without details, user not reported deleted", async () => {
  const { d } = deps({
    deleteUser: () => Promise.reject(new Error("secret db detail")),
  });
  const res = await handleDeleteAccount(req(), d);
  assertEquals(res.status, 500);
  const text = await res.text();
  if (text.includes("secret")) throw new Error("leaked error detail");
});

Deno.test("logs never contain the token or the Apple code", async () => {
  const { d, logs } = deps();
  await handleDeleteAccount(req({ apple_authorization_code: "c0de" }), d);
  const all = logs.join("\n");
  for (const s of ["good-jwt", "c0de"]) {
    if (all.includes(s)) throw new Error(`log leaked ${s}`);
  }
});

async function testKeyPem(): Promise<{ pem: string; pub: CryptoKey }> {
  const pair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const der = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", pair.privateKey),
  );
  const b64 = btoa(String.fromCharCode(...der)).replace(/(.{64})/g, "$1\n");
  return {
    pem: `-----BEGIN PRIVATE KEY-----\n${b64}\n-----END PRIVATE KEY-----\n`,
    pub: pair.publicKey,
  };
}

const b64urlDecode = (s: string): Uint8Array<ArrayBuffer> =>
  Uint8Array.from(
    atob(
      s.replace(/-/g, "+").replace(/_/g, "/") +
        "=".repeat((4 - s.length % 4) % 4),
    ),
    (c) => c.charCodeAt(0),
  );

Deno.test("Apple client secret is a valid ES256 JWT", async () => {
  const { pem, pub } = await testKeyPem();
  const jwt = await appleClientSecret({
    teamId: "NW22NWLTK4",
    keyId: "ANA4NT26KP",
    clientId: "com.ronganminh.repCounterApp",
    privateKeyPem: pem,
  }, 1_700_000_000);
  const [h, c, s] = jwt.split(".");
  assertEquals(JSON.parse(new TextDecoder().decode(b64urlDecode(h))), {
    alg: "ES256",
    kid: "ANA4NT26KP",
    typ: "JWT",
  });
  assertEquals(JSON.parse(new TextDecoder().decode(b64urlDecode(c))), {
    iss: "NW22NWLTK4",
    iat: 1_700_000_000,
    exp: 1_700_000_300,
    aud: "https://appleid.apple.com",
    sub: "com.ronganminh.repCounterApp",
  });
  const ok = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    pub,
    b64urlDecode(s),
    new TextEncoder().encode(`${h}.${c}`),
  );
  assertEquals(ok, true, "signature");
});

Deno.test("revoke: exchanges the code, then revokes the refresh token", async () => {
  const { pem } = await testKeyPem();
  const seen: { url: string; form: Record<string, string> }[] = [];
  const fakeFetch = ((url: string | URL | Request, init?: RequestInit) => {
    const form = Object.fromEntries(new URLSearchParams(String(init?.body)));
    seen.push({ url: String(url), form });
    if (String(url).endsWith("/auth/token")) {
      return Promise.resolve(
        new Response(JSON.stringify({ refresh_token: "rt-1" })),
      );
    }
    return Promise.resolve(new Response(null, { status: 200 }));
  }) as typeof fetch;
  const ok = await revokeAppleAuthorizationCode("c0de", {
    teamId: "NW22NWLTK4",
    keyId: "ANA4NT26KP",
    clientId: "com.ronganminh.repCounterApp",
    privateKeyPem: pem,
  }, fakeFetch);
  assertEquals(ok, true);
  assertEquals(seen.map((s) => s.url), [
    "https://appleid.apple.com/auth/token",
    "https://appleid.apple.com/auth/revoke",
  ]);
  assertEquals(seen[0].form.grant_type, "authorization_code");
  assertEquals(seen[0].form.code, "c0de");
  assertEquals(seen[0].form.client_id, "com.ronganminh.repCounterApp");
  assertEquals(seen[1].form.token, "rt-1");
  assertEquals(seen[1].form.token_type_hint, "refresh_token");
});

Deno.test("revoke: a rejected code returns false without revoking", async () => {
  const { pem } = await testKeyPem();
  let calls = 0;
  const fakeFetch = (() => {
    calls++;
    return Promise.resolve(new Response("{}", { status: 400 }));
  }) as typeof fetch;
  const ok = await revokeAppleAuthorizationCode("bad", {
    teamId: "NW22NWLTK4",
    keyId: "ANA4NT26KP",
    clientId: "com.ronganminh.repCounterApp",
    privateKeyPem: pem,
  }, fakeFetch);
  assertEquals(ok, false);
  assertEquals(calls, 1);
});
