import { assertEquals, assertFalse } from "../_shared/assert.ts";
import contract from "../../contracts/push_inbox.json" with { type: "json" };
import {
  type DeviceToken,
  handleSendPush,
  KINDS,
  type SendPushDeps,
} from "./handler.ts";

const edge = contract.edge_functions["send-push"];
const SECRET = "push-secret-0123456789";
const USER = "6f2c4b1e-0000-4000-8000-000000000001";

function deps(tokens: DeviceToken[], over: Partial<SendPushDeps> = {}) {
  const pushed: { token: string; msg: unknown }[] = [];
  const dropped: string[] = [];
  const inbox: unknown[] = [];
  const d: SendPushDeps = {
    secret: SECRET,
    createInbox: (...args) => {
      inbox.push(args);
      return Promise.resolve({ item: { id: "n1" }, tokens });
    },
    deliver: (t, msg) => {
      pushed.push({ token: t.token, msg });
      return Promise.resolve(
        t.token.startsWith("gone")
          ? "invalid_token"
          : t.token.startsWith("down")
          ? "failed"
          : "delivered",
      );
    },
    dropToken: (t) => {
      dropped.push(t);
      return Promise.resolve();
    },
    ...over,
  };
  return { d, pushed, dropped, inbox };
}

const req = (body: unknown, secret = SECRET) =>
  new Request("http://x/send-push", {
    method: "POST",
    headers: { "x-push-secret": secret },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });

const good = {
  user_id: USER,
  kind: "friend_request",
  link: "repcoach://friends/requests",
  title: "New friend request",
  body: "Ann wants to train with you",
};

Deno.test("inbox first, then title + link only to each device (contract)", async () => {
  assertEquals([...KINDS], contract.kinds);
  assertEquals(Object.keys(good).sort(), [...edge.request].sort());
  const f = deps([
    { token: "ok-1", platform: "apns" },
    { token: "gone-2", platform: "fcm" },
    { token: "down-3", platform: "fcm" },
  ]);
  const res = await handleSendPush(req(good), f.d);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(Object.keys(body).sort(), [...edge.response].sort());
  assertEquals(body, { inbox_id: "n1", sent: 1, dropped: 1, failed: 1 });
  assertEquals(f.inbox.length, 1);
  assertEquals(f.dropped, ["gone-2"]);
  for (const p of f.pushed) {
    assertEquals(p.msg, {
      title: "New friend request",
      link: "repcoach://friends/requests",
    });
  }
  assertFalse(
    JSON.stringify(f.pushed).includes("Ann wants"),
    "no body in pushes",
  );
});

Deno.test("no push service configured: inbox written, nothing pushed", async () => {
  const f = deps([{ token: "ok-1", platform: "apns" }], {
    deliver: () => null,
  });
  const res = await handleSendPush(req(good), f.d);
  assertEquals(await res.json(), {
    inbox_id: "n1",
    sent: 0,
    dropped: 0,
    failed: 0,
  });
  assertEquals(f.inbox.length, 1);
  const none = deps([{ token: "ok-1", platform: "apns" }], { deliver: null });
  assertEquals((await handleSendPush(req(good), none.d)).status, 200);
});

Deno.test("refused", async () => {
  const f = deps([]);
  assertEquals((await handleSendPush(req(good, "wrong"), f.d)).status, 401);
  const weak = deps([], { secret: "short" });
  assertEquals((await handleSendPush(req(good, "short"), weak.d)).status, 401);
  assertEquals(
    (await handleSendPush(new Request("http://x"), f.d)).status,
    405,
  );
  const bad: Record<string, unknown>[] = [
    { link: "https://example.com" },
    { link: "repcoach://" + "x".repeat(300) },
    { kind: "marketing" },
    { user_id: "not-a-uuid" },
    { title: "" },
    { title: "x".repeat(121) },
    { body: "x".repeat(501) },
  ];
  for (const over of bad) {
    assertEquals(
      (await handleSendPush(req({ ...good, ...over }), f.d)).status,
      400,
      JSON.stringify(over),
    );
  }
  assertEquals((await handleSendPush(req("{bad"), f.d)).status, 400);
  assertEquals(f.inbox.length, 0);
  const broken = deps([], {
    createInbox: () => Promise.reject(new Error("db")),
  });
  assertEquals((await handleSendPush(req(good), broken.d)).status, 500);
});
