"""Tests for seed_demo_accounts.py against a fake Supabase on localhost.

    python3 tool/test_seed_demo_accounts.py

No network beyond 127.0.0.1; also run by the app's contract test
(rep_counter_app/test/tool/seed_demo_accounts_test.dart).
"""

import contextlib
import datetime as dt
import io
import json
import os
import pathlib
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import seed_demo_accounts as seed  # noqa: E402

SERVICE = "service-key-for-tests"


class FakeSupabase:
    """Just enough of GoTrue admin/token, PostgREST rpc and the ledger."""

    def __init__(self):
        self.users = {}  # id -> {email, password, confirmed}
        self.workouts = {}  # (uid, client_id) -> row
        self.plans = {}
        self.ledger = []  # (uid, kind, amount)
        self.calls = []
        self.seq = 0

    def _uid(self, auth):
        token = auth.removeprefix("Bearer ")
        return token.removeprefix("user:") if token.startswith("user:") else None

    def handle(self, method, path, headers, body):
        self.calls.append((method, path.split("?")[0], body))
        if path.startswith("/auth/v1/admin/"):
            assert headers["Authorization"] == f"Bearer {SERVICE}"
            if method == "GET":
                return 200, {"users": [
                    {"id": i, "email": u["email"]} for i, u in self.users.items()]}
            if method == "POST":
                uid = f"u{len(self.users) + 1}"
                self.users[uid] = {"email": body["email"],
                                   "password": body["password"],
                                   "confirmed": body["email_confirm"]}
                return 200, {"id": uid, "email": body["email"]}
            if method == "PUT":
                uid = path.rsplit("/", 1)[1]
                self.users[uid].update(password=body["password"],
                                       confirmed=body["email_confirm"])
                return 200, {"id": uid}
        if path.startswith("/auth/v1/token"):
            for uid, u in self.users.items():
                if u["email"] == body["email"] and u["password"] == body["password"]:
                    assert u["confirmed"]
                    return 200, {"access_token": f"user:{uid}"}
            return 400, {"error": "invalid_grant"}
        if path == "/rest/v1/ai_credit_ledger":
            assert headers["Authorization"] == f"Bearer {SERVICE}"
            self.ledger.append((body["user_id"], body["kind"], body["amount"]))
            return 201, None
        if path.startswith("/rest/v1/rpc/"):
            uid = self._uid(headers["Authorization"])
            assert uid, "rpc must run as the user"
            name = path.rsplit("/", 1)[1]
            return 200, getattr(self, name)(uid, body)
        return 404, {"error": path}

    def _push(self, table, key, field, uid, rows):
        out = []
        for r in rows:
            self.seq += 1
            row = {key: r[key], field: r[field],
                   "client_updated_at": r["client_updated_at"],
                   "deleted_at": r["deleted_at"], "server_seq": self.seq}
            table[(uid, r[key])] = row
            out.append(row)
        return out

    def _pull(self, table, uid, body):
        rows = sorted((r for (u, _), r in table.items() if u == uid),
                      key=lambda r: r["server_seq"])
        rows = [r for r in rows if r["server_seq"] > body["p_after"]]
        return {"rows": rows, "cursor": rows[-1]["server_seq"] if rows else
                body["p_after"], "has_more": False}

    def sync_push_workouts(self, uid, body):
        return self._push(self.workouts, "client_id", "raw", uid, body["p_rows"])

    def sync_push_plans(self, uid, body):
        return self._push(self.plans, "plan_id", "doc", uid, body["p_rows"])

    def sync_pull_workouts(self, uid, body):
        return self._pull(self.workouts, uid, body)

    def sync_pull_plans(self, uid, body):
        return self._pull(self.plans, uid, body)

    def ai_credit_balance(self, uid, _):
        bal = sum(a for u, _, a in self.ledger if u == uid)
        if not any(u == uid and k == "weekly_allowance" for u, k, _ in self.ledger):
            self.ledger.append((uid, "weekly_allowance", 10 - bal))
            bal = 10
        return {"balance": bal, "weekly_allowance": 10}

    def balance(self, uid):
        return sum(a for u, _, a in self.ledger if u == uid)


class _Handler(BaseHTTPRequestHandler):
    fake: FakeSupabase

    def _do(self):
        n = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(n)) if n else None
        status, out = self.fake.handle(self.command, self.path,
                                       dict(self.headers), body)
        data = b"" if out is None else json.dumps(out).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = do_POST = do_PUT = _do

    def log_message(self, *_):
        pass


class SeedTest(unittest.TestCase):
    def setUp(self):
        self.fake = FakeSupabase()
        handler = type("H", (_Handler,), {"fake": self.fake})
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.url = f"http://127.0.0.1:{self.server.server_port}"

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()

    def run_seed(self, *args, env=None):
        sb = seed.Supabase(self.url, SERVICE, SERVICE)
        out, err = io.StringIO(), io.StringIO()
        base = {"REPCOACH_ENV": "staging", "SUPABASE_URL": "https://example.test",
                "SUPABASE_SERVICE_ROLE_KEY": SERVICE}
        with mock.patch.dict(os.environ, {**base, **(env or {})}, clear=True), \
                mock.patch.object(seed, "Supabase", return_value=sb), \
                contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = seed.main(list(args))
        return code, out.getvalue(), err.getvalue()

    def test_missing_env_does_nothing(self):
        for missing in ("REPCOACH_ENV", "SUPABASE_URL",
                        "SUPABASE_SERVICE_ROLE_KEY"):
            out, err = io.StringIO(), io.StringIO()
            env = {"REPCOACH_ENV": "staging",
                   "SUPABASE_URL": "https://example.test",
                   "SUPABASE_SERVICE_ROLE_KEY": SERVICE}
            del env[missing]
            with mock.patch.dict(os.environ, env, clear=True), \
                    contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                self.assertEqual(seed.main([]), 1)
            self.assertIn(missing, err.getvalue())
        self.assertEqual(self.fake.calls, [])
        code, _, err = self.run_seed(env={"REPCOACH_ENV": "production"})
        self.assertEqual(code, 1)
        self.assertEqual(self.fake.calls, [])

    def test_creates_two_confirmed_users_with_data(self):
        code, out, _ = self.run_seed()
        self.assertEqual(code, 0)
        emails = sorted(u["email"] for u in self.fake.users.values())
        self.assertEqual(emails, ["reviewer-apple@repcoach-ai.duckdns.org",
                                  "reviewer-google@repcoach-ai.duckdns.org"])
        for uid, u in self.fake.users.items():
            self.assertTrue(u["confirmed"])
            # The password is printed once, only in the final summary.
            self.assertEqual(out.count(u["password"]), 1)
            mine = [r for (x, _), r in self.fake.workouts.items() if x == uid]
            self.assertEqual(len(mine), 5)
            self.assertEqual({r["raw"]["exercise_id"] for r in mine},
                             {"push_up", "curl"})
            plan = self.fake.plans[(uid, "demo-plan")]["doc"]["plan"]
            self.assertEqual(plan["status"], "active")
            self.assertEqual(self.fake.balance(uid), 10)
        self.assertIn("consent screen", out)

    def test_second_run_resets_password_and_tops_up(self):
        self.run_seed()
        first = {i: u["password"] for i, u in self.fake.users.items()}
        uid = next(iter(first))
        self.fake.ledger.append((uid, "consume", -7))  # reviewer used credits
        code, out, _ = self.run_seed()
        self.assertEqual(code, 0)
        self.assertEqual(len(self.fake.users), 2)  # no duplicates
        for i, u in self.fake.users.items():
            self.assertNotEqual(u["password"], first[i])
            self.assertIn(u["password"], out)
        self.assertEqual(self.fake.balance(uid), 10)
        self.assertIn("password reset", out)
        self.assertEqual(len([w for w in self.fake.workouts if w[0] == uid]), 5)

    def test_reset_tombstones_other_workouts_and_plans(self):
        self.run_seed()
        uid = next(iter(self.fake.users))
        self.fake.workouts[(uid, "mine")] = {
            "client_id": "mine", "raw": {"id": "mine", "started_at": "x"},
            "client_updated_at": "x", "deleted_at": None, "server_seq": 999}
        self.fake.plans[(uid, "other")] = {
            "plan_id": "other", "doc": {"plan": {}}, "client_updated_at": "x",
            "deleted_at": None, "server_seq": 1000}
        self.run_seed()
        self.assertIsNone(self.fake.workouts[(uid, "mine")]["deleted_at"])
        self.run_seed("--reset")
        self.assertIsNotNone(self.fake.workouts[(uid, "mine")]["deleted_at"])
        self.assertEqual(self.fake.workouts[(uid, "mine")]["raw"]["started_at"], "x")
        self.assertIsNotNone(self.fake.plans[(uid, "other")]["deleted_at"])
        self.assertIsNone(self.fake.workouts[(uid, "demo-w1")]["deleted_at"])
        self.assertIsNone(self.fake.plans[(uid, "demo-plan")]["deleted_at"])

    def test_custom_domain_and_prod_needs_a_terminal(self):
        self.run_seed(env={"DEMO_EMAIL_DOMAIN": "example.org"})
        self.assertIn("reviewer-apple@example.org",
                      [u["email"] for u in self.fake.users.values()])
        before = len(self.fake.calls)
        with mock.patch.object(sys.stdin, "isatty", return_value=False):
            code, _, err = self.run_seed(env={"REPCOACH_ENV": "prod"})
        self.assertEqual(code, 1)
        self.assertIn("interactive", err)
        self.assertEqual(len(self.fake.calls), before)

    def test_passwords_are_strong_and_random(self):
        ps = {seed.new_password() for _ in range(50)}
        self.assertEqual(len(ps), 50)
        for p in ps:
            self.assertEqual(len(p), 20)
            self.assertTrue(any(c.isupper() for c in p))
            self.assertTrue(any(c.islower() for c in p))
            self.assertTrue(any(c.isdigit() for c in p))
            self.assertTrue(any(c in "-_.!" for c in p))

    def test_docs_follow_d32(self):
        today = dt.date(2026, 11, 26)  # Thursday
        docs = seed.build_docs(today, dt.datetime(2026, 11, 26, 12,
                                                  tzinfo=dt.timezone.utc),
                               "America/Los_Angeles")
        days = sorted(dt.datetime.fromisoformat(
            w["started_at"].replace("Z", "+00:00")).date()
            for w in docs["workouts"])
        self.assertEqual(len(days), 5)
        self.assertGreaterEqual((today - days[0]).days + 1, 15)
        self.assertTrue(all(d < today + dt.timedelta(days=1) for d in days))
        plan = docs["plan"]["plan"]
        self.assertEqual(plan["weekdays"], [1, 2, 4, 5, 6, 7])  # rest: Wed
        self.assertEqual(docs["plan"]["sessions"], [])


if __name__ == "__main__":
    unittest.main()
