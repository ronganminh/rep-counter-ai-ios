#!/usr/bin/env python3
"""Creates (or resets) the two App Review demo accounts and seeds their data.

Run on the owner's machine only. Nothing here is committed or logged:

    export REPCOACH_ENV=staging            # or prod
    export SUPABASE_URL=https://<project-ref>.supabase.co
    export SUPABASE_SERVICE_ROLE_KEY=...   # from Supabase > Project Settings > API
    python3 tool/seed_demo_accounts.py

What it does, for reviewer-apple@<domain> and reviewer-google@<domain>
(docs/qa/DEMO_ACCOUNTS.md):

1. Admin API: creates the user with a new random password and
   email_confirm=true, or, when it exists, sets a new random password
   (idempotent: running it again resets the password instead of failing).
2. Signs in as that user (email + password) and pushes, through the same
   sync functions the app uses (sync_push_workouts / sync_push_plans):
   5 saved workouts over the last 2 weeks (push-up and dumbbell curl) and
   one active plan with a session every day except the day before the run.
3. Tops the AI credits up to the weekly allowance (ledger `admin_adjust`).
4. AI Coach consent is not touched: it is kept on the phone, so a fresh
   install shows the consent screen.

The passwords are printed once, to this terminal, at the end. They are not
written to a file and not sent anywhere else.

Flags:
  --reset        also delete (tombstone) the demo users' other workouts and
                 plans, e.g. ones recorded during an earlier review
  --print-docs   print the seed documents as JSON and exit (no network, no
                 env needed); used by the app's contract test
  --today DATE   with --print-docs: the day to build around (YYYY-MM-DD)
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import secrets
import string
import sys
import urllib.error
import urllib.parse
import urllib.request

try:
    from zoneinfo import ZoneInfo
except ImportError:  # Python < 3.9
    ZoneInfo = None  # type: ignore

DEFAULT_DOMAIN = "repcoach-ai.duckdns.org"
DEFAULT_TIMEZONE = "America/Los_Angeles"
ACCOUNTS = (
    ("apple", "reviewer-apple", "App Review (Apple)"),
    ("google", "reviewer-google", "App Review (Google Play)"),
)
PLAN_ID = "demo-plan"

# Same as PlanTemplates.fullBody(PlanDifficulty.beginner) in the app
# (lib/features/plan/domain/plan_templates.dart); the contract test
# (test/tool/seed_demo_accounts_test.dart) fails when they drift apart.
TEMPLATES = [
    {"id": "full_body_a", "name": "Full Body A", "targets": [
        {"exercise_id": "push_up", "sets": 3, "reps": 6, "tracking": "camera"},
        {"exercise_id": "curl", "sets": 3, "reps": 10, "tracking": "camera"},
        {"exercise_id": "overhead_extension", "sets": 2, "reps": 10,
         "tracking": "camera"},
    ]},
    {"id": "full_body_b", "name": "Full Body B", "targets": [
        {"exercise_id": "pull_up", "sets": 3, "reps": 3, "tracking": "camera"},
        {"exercise_id": "push_up", "sets": 2, "reps": 6, "tracking": "camera"},
        {"exercise_id": "curl", "sets": 2, "reps": 10, "tracking": "camera"},
    ]},
    {"id": "full_body_c", "name": "Full Body C", "targets": [
        {"exercise_id": "push_up", "sets": 1, "seconds": 45,
         "tracking": "camera"},
        {"exercise_id": "overhead_extension", "sets": 3, "reps": 10,
         "tracking": "camera"},
        {"exercise_id": "pull_up", "sets": 2, "reps": 3, "tracking": "camera"},
    ]},
]

# (days ago, exercise, reps, sets, target reps, seconds, quality score,
# flagged reps). 5 workouts, first one 14 days ago: 3+ workouts for
# Coach's pick and 14+ days of history for "next week" (D-32) in any time
# zone. Each at noon local time, so the day is the same almost everywhere.
WORKOUTS = [
    (14, "push_up", 15, 3, 18, 210, 74, 2),
    (11, "curl", 27, 3, 30, 240, 81, 1),
    (8, "push_up", 17, 3, 18, 205, 79, 1),
    (4, "curl", 30, 3, 30, 230, 85, 0),
    (1, "push_up", 19, 3, 18, 200, 83, 1),
]
EXERCISE_NAMES = {"push_up": "Push-up", "curl": "Dumbbell curl"}


class SeedError(Exception):
    pass


# Documents ------------------------------------------------------------------


def _iso(t: dt.datetime) -> str:
    return t.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def _zone(name: str):
    if ZoneInfo is None:
        return dt.timezone.utc
    try:
        return ZoneInfo(name)
    except Exception as e:  # noqa: BLE001
        raise SeedError(f"unknown DEMO_TIMEZONE {name!r}") from e


def build_docs(today: dt.date, now: dt.datetime, tz_name: str) -> dict:
    """The workouts (raw, as WorkoutRecord.toJson) and the plan doc (as
    PlanSyncSource.docOf) for one account."""
    tz = _zone(tz_name)
    workouts = []
    for i, (ago, ex, reps, sets, target, secs, score, flagged) in enumerate(
            WORKOUTS, start=1):
        day = today - dt.timedelta(days=ago)
        started = dt.datetime(day.year, day.month, day.day, 12, 0, tzinfo=tz)
        poses = secs * 15
        workouts.append({
            "id": f"demo-w{i}",
            "exercise_id": ex,
            "exercise_name": EXERCISE_NAMES[ex],
            "started_at": _iso(started),
            "duration_seconds": secs,
            "reps": reps,
            "sets": sets,
            "target_reps": target,
            "mode": "targetReps",
            "pose_frames": poses,
            "ready_frames": poses * 94 // 100,
            "lost_frames": poses * 3 // 100,
            "quality": {
                "flagged_reps": flagged,
                "avg_rep_sec": 2.4 if ex == "push_up" else 2.1,
                "avg_amplitude": 0.62,
                "amplitude_drop_percent": 12.0,
                "left_right_diff_percent": 6.0,
                "quality_score": score,
                "range_of_motion": score + 2,
                "cadence_consistency": score - 3,
                "left_right_balance": score + 1,
                "pose_alignment": score,
                "has_enough_data": True,
            },
        })
    # Six training days (the plan's maximum): every weekday except the
    # day before the run, so the next six days all have a session.
    rest = (today - dt.timedelta(days=1)).isoweekday()
    plan = {
        "id": PLAN_ID,
        "name": "Full Body · 6 days",
        "goal": "generalFitness",
        "difficulty": "beginner",
        "weekdays": [d for d in range(1, 8) if d != rest],
        "templates": TEMPLATES,
        "timezone": tz_name,
        "start_date": (today - dt.timedelta(days=14)).isoformat(),
        "status": "active",
        "version": 1,
        "day_overrides": {},
        "progressive_overload": False,
        "created_at": _iso(now),
        "updated_at": _iso(now),
    }
    # Sessions are generated by the app from today on (PlanRepository.load).
    return {"workouts": workouts, "plan": {"plan": plan, "sessions": []}}


# HTTP -------------------------------------------------------------------------


class Supabase:
    def __init__(self, url: str, service_key: str, user_apikey: str):
        self.url = url.rstrip("/")
        self._service = service_key
        self._user_apikey = user_apikey

    def _call(self, method: str, path: str, body=None, token: str | None = None,
              extra: dict | None = None):
        headers = {
            "apikey": self._user_apikey if token else self._service,
            "Authorization": f"Bearer {token or self._service}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
        headers.update(extra or {})
        data = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request(self.url + path, data=data,
                                     headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as res:
                raw = res.read()
        except urllib.error.HTTPError as e:
            # Never echo the request (it may hold a password); the server's
            # error code is enough.
            detail = e.read()[:300].decode(errors="replace")
            raise SeedError(f"{method} {path.split('?')[0]} -> {e.code}: "
                            f"{detail}") from None
        except urllib.error.URLError as e:
            raise SeedError(f"{method} {path.split('?')[0]}: {e.reason}") \
                from None
        return json.loads(raw) if raw else None

    # Auth admin (service role)
    def find_user(self, email: str):
        page = 1
        while True:
            res = self._call("GET", f"/auth/v1/admin/users?page={page}"
                                    "&per_page=200")
            users = res.get("users", []) if isinstance(res, dict) else res
            for u in users:
                if (u.get("email") or "").lower() == email.lower():
                    return u
            if len(users) < 200:
                return None
            page += 1

    def create_user(self, email: str, password: str, name: str):
        return self._call("POST", "/auth/v1/admin/users", {
            "email": email,
            "password": password,
            "email_confirm": True,
            "user_metadata": {"name": name, "repcoach_demo": True},
        })

    def reset_user(self, user_id: str, password: str):
        return self._call("PUT", f"/auth/v1/admin/users/{user_id}", {
            "password": password,
            "email_confirm": True,
            "ban_duration": "none",
        })

    # As the user
    def sign_in(self, email: str, password: str) -> str:
        res = self._call("POST", "/auth/v1/token?grant_type=password",
                         {"email": email, "password": password},
                         extra={"apikey": self._user_apikey,
                                "Authorization": f"Bearer {self._user_apikey}"})
        return res["access_token"]

    def rpc(self, token: str, name: str, args: dict):
        return self._call("POST", f"/rest/v1/rpc/{name}", args, token=token)

    # Credits ledger (service role)
    def top_up_credits(self, user_id: str, token: str) -> int:
        state = self.rpc(token, "ai_credit_balance", {})  # grants the week
        allowance = int(state["weekly_allowance"])
        missing = allowance - int(state["balance"])
        if missing > 0:
            self._call("POST", "/rest/v1/ai_credit_ledger", {
                "user_id": user_id, "kind": "admin_adjust", "amount": missing,
            }, extra={"Prefer": "return=minimal"})
        return allowance


# Seeding ---------------------------------------------------------------------


def new_password() -> str:
    """20 characters with upper, lower, digit and symbol (passes the
    strictest Supabase password policy)."""
    pools = [string.ascii_uppercase, string.ascii_lowercase, string.digits,
             "-_.!"]
    chars = [secrets.choice(p) for p in pools]
    alphabet = "".join(pools)
    chars += [secrets.choice(alphabet) for _ in range(16)]
    secrets.SystemRandom().shuffle(chars)
    return "".join(chars)


def seed_account(sb: Supabase, email: str, name: str, docs: dict,
                 reset: bool) -> tuple[str, bool, int]:
    password = new_password()
    existing = sb.find_user(email)
    if existing:
        sb.reset_user(existing["id"], password)
        user_id = existing["id"]
    else:
        user_id = (sb.create_user(email, password, name) or {})["id"]
    token = sb.sign_in(email, password)
    now = _iso(dt.datetime.now(dt.timezone.utc))

    if reset:
        keep = {w["id"] for w in docs["workouts"]}
        for kind, key, field, pull, push in (
                ("workouts", "client_id", "raw", "sync_pull_workouts",
                 "sync_push_workouts"),
                ("plans", "plan_id", "doc", "sync_pull_plans",
                 "sync_push_plans")):
            rows, after = [], 0
            while True:
                page = sb.rpc(token, pull, {"p_after": after, "p_limit": 500})
                rows += page.get("rows", [])
                after = page.get("cursor", after)
                if not page.get("has_more"):
                    break
            ours = keep if kind == "workouts" else {PLAN_ID}
            gone = [r for r in rows
                    if r[key] not in ours and not r.get("deleted_at")]
            if gone:
                sb.rpc(token, push, {"p_rows": [
                    {key: r[key], field: r[field], "client_updated_at": now,
                     "deleted_at": now} for r in gone]})

    sb.rpc(token, "sync_push_workouts", {"p_rows": [
        {"client_id": w["id"], "raw": w, "client_updated_at": now,
         "deleted_at": None} for w in docs["workouts"]]})
    sb.rpc(token, "sync_push_plans", {"p_rows": [
        {"plan_id": PLAN_ID, "doc": docs["plan"], "client_updated_at": now,
         "deleted_at": None}]})
    credits = sb.top_up_credits(user_id, token)
    return password, existing is None, credits


def _env(name: str) -> str:
    v = os.environ.get(name, "").strip()
    if not v:
        raise SeedError(f"{name} is not set (see docs/qa/DEMO_ACCOUNTS.md); "
                        "nothing was done")
    return v


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--reset", action="store_true")
    ap.add_argument("--print-docs", action="store_true")
    ap.add_argument("--today")
    args = ap.parse_args(argv)
    tz_name = os.environ.get("DEMO_TIMEZONE", "").strip() or DEFAULT_TIMEZONE

    if args.print_docs:
        today = (dt.date.fromisoformat(args.today) if args.today
                 else dt.datetime.now(_zone(tz_name)).date())
        now = dt.datetime(today.year, today.month, today.day, 12,
                          tzinfo=dt.timezone.utc)
        print(json.dumps(build_docs(today, now, tz_name), indent=2,
                         ensure_ascii=False))
        return 0

    try:
        env = _env("REPCOACH_ENV").lower()
        if env not in ("staging", "prod"):
            raise SeedError("REPCOACH_ENV must be 'staging' or 'prod'; "
                            "nothing was done")
        url = _env("SUPABASE_URL")
        if not url.startswith("https://"):
            raise SeedError("SUPABASE_URL must start with https://")
        service = _env("SUPABASE_SERVICE_ROLE_KEY")
        anon = os.environ.get("SUPABASE_ANON_KEY", "").strip() or service
        domain = (os.environ.get("DEMO_EMAIL_DOMAIN", "").strip()
                  or DEFAULT_DOMAIN)
        host = urllib.parse.urlparse(url).hostname
        print(f"Project: {env} ({host})")
        print("Accounts: " + ", ".join(f"{a[1]}@{domain}" for a in ACCOUNTS))
        if env == "prod":
            if not sys.stdin.isatty():
                raise SeedError("prod needs an interactive terminal to confirm")
            if input("Type 'prod' to continue: ").strip() != "prod":
                raise SeedError("not confirmed; nothing was done")

        sb = Supabase(url, service, anon)
        today = dt.datetime.now(_zone(tz_name)).date()
        docs = build_docs(today, dt.datetime.now(dt.timezone.utc), tz_name)
        results = []
        for store, local, name in ACCOUNTS:
            email = f"{local}@{domain}"
            password, created, credits = seed_account(sb, email, name, docs,
                                                      args.reset)
            results.append((store, email, password, created, credits))
    except SeedError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    print()
    print("Done. Copy these now; they are not saved anywhere.")
    for store, email, password, created, credits in results:
        state = "created" if created else "password reset"
        print(f"  [{store}] {email}  password: {password}  ({state}, "
              f"5 workouts, 1 plan, {credits} AI credits)")
    print("AI Coach consent is not set: the reviewer sees the consent screen.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
