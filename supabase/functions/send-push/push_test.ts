import { assert, assertEquals, assertFalse } from "../_shared/assert.ts";
import {
  b64urlDecode,
  ecKeyPem,
  jsonResponse,
  rsaKeyPem,
} from "../_shared/test_helpers.ts";
import { apnsToken, sendApns, sendFcm } from "./push.ts";

const msg = {
  title: "New friend request",
  link: "repcoach://friends/requests",
};

Deno.test("APNs: ES256 provider token, topic, payload, status mapping", async () => {
  const { pem, publicKey } = await ecKeyPem();
  const cfg = {
    teamId: "TEAM",
    keyId: "KEY",
    privateKeyPem: pem,
    bundleId: "com.ronganminh.repCounterApp",
    sandbox: true,
  };
  const jwt = await apnsToken(cfg, 1000);
  const [h, p, s] = jwt.split(".");
  assertEquals(JSON.parse(new TextDecoder().decode(b64urlDecode(h))), {
    alg: "ES256",
    typ: "JWT",
    kid: "KEY",
  });
  assertEquals(JSON.parse(new TextDecoder().decode(b64urlDecode(p))), {
    iss: "TEAM",
    iat: 1000,
  });
  assert(
    await crypto.subtle.verify(
      { name: "ECDSA", hash: "SHA-256" },
      publicKey,
      b64urlDecode(s),
      new TextEncoder().encode(`${h}.${p}`),
    ),
  );

  let seen: { url: string; init: RequestInit } | null = null;
  const reply =
    (status: number, body: unknown = {}): typeof fetch => (url, init) => {
      seen = { url: String(url), init: init! };
      return Promise.resolve(jsonResponse(status, body));
    };
  assertEquals(await sendApns("abc", msg, cfg, reply(200)), "delivered");
  assertEquals(seen!.url, "https://api.sandbox.push.apple.com/3/device/abc");
  const headers = seen!.init.headers as Record<string, string>;
  assertEquals(headers["apns-topic"], "com.ronganminh.repCounterApp");
  assertEquals(headers["apns-push-type"], "alert");
  assertEquals(JSON.parse(String(seen!.init.body)), {
    aps: { alert: { title: msg.title } },
    link: msg.link,
  });
  assertEquals(
    await sendApns("abc", msg, { ...cfg, sandbox: false }, reply(200)),
    "delivered",
  );
  assertEquals(seen!.url, "https://api.push.apple.com/3/device/abc");
  assertEquals(await sendApns("abc", msg, cfg, reply(410)), "invalid_token");
  assertEquals(
    await sendApns("abc", msg, cfg, reply(400, { reason: "BadDeviceToken" })),
    "invalid_token",
  );
  assertEquals(
    await sendApns("abc", msg, cfg, reply(400, { reason: "PayloadTooLarge" })),
    "failed",
  );
  assertEquals(await sendApns("abc", msg, cfg, reply(503)), "failed");
});

Deno.test("FCM v1: messaging scope, title + link only, 404 drops the token", async () => {
  const { pem } = await rsaKeyPem();
  const cfg = {
    projectId: "repcoach-app",
    clientEmail: "fcm@x.iam.gserviceaccount.com",
    privateKeyPem: pem,
  };
  const calls: { url: string; init?: RequestInit }[] = [];
  const reply = (status: number): typeof fetch => (url, init) => {
    calls.push({ url: String(url), init });
    return Promise.resolve(
      String(url).startsWith("https://oauth2")
        ? jsonResponse(200, { access_token: "at" })
        : jsonResponse(status, {}),
    );
  };
  assertEquals(await sendFcm("tok", msg, cfg, reply(200)), "delivered");
  const assertion = new URLSearchParams(String(calls[0].init!.body)).get(
    "assertion",
  )!;
  const claims = JSON.parse(
    new TextDecoder().decode(b64urlDecode(assertion.split(".")[1])),
  );
  assertEquals(
    claims.scope,
    "https://www.googleapis.com/auth/firebase.messaging",
  );
  assertEquals(
    calls[1].url,
    "https://fcm.googleapis.com/v1/projects/repcoach-app/messages:send",
  );
  const body = JSON.parse(String(calls[1].init!.body));
  assertEquals(body, {
    message: {
      token: "tok",
      notification: { title: msg.title },
      data: { link: msg.link },
    },
  });
  assertFalse("body" in body.message.notification);
  assertEquals(await sendFcm("tok", msg, cfg, reply(404)), "invalid_token");
  assertEquals(await sendFcm("tok", msg, cfg, reply(500)), "failed");
});
