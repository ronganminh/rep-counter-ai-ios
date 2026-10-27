# Supabase (D-12)

Staging project: `rvysencgtomkzwgdjaqh` (Tokyo). No production project yet.

| Path                        | What                                                                                                                                                                                                                                                            |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `functions/delete-account/` | Account deletion (App Store 5.1.1(v)): verify JWT → revoke Sign in with Apple (if the app sent an authorization code) → delete the user's rows → `auth.admin.deleteUser`. `handler.ts` holds the logic, `apple.ts` the Apple revocation, `index.ts` the wiring. |
| `migrations/`               | User-owned tables: `user_id … references auth.users on delete cascade`, RLS on, explicit grants (the project does not auto-expose tables).                                                                                                                      |

## Tests

```
deno test --no-remote supabase/functions/delete-account/
```

CI runs this in `.github/workflows/supabase-functions.yml`. The tests use
generated keys and a mocked `fetch`; there are no network calls and no secrets.

## Deploy to staging (owner, on your machine)

The agent has no Supabase access token, so nothing has been deployed. Run these
yourself. The token comes from `supabase login`, and is never stored in this
repo.

```bash
# 0. Supabase CLI ≥ 2.x  (brew install supabase/tap/supabase  or  npm i -g supabase)
supabase login                                   # opens the browser; stores your personal token locally
cd <repo root>                                   # the folder that contains supabase/
supabase link --project-ref rvysencgtomkzwgdjaqh # asks for the database password

# 1. Apple secrets for token revocation. The .p8 stays outside the repo.
supabase secrets set --project-ref rvysencgtomkzwgdjaqh \
  APPLE_TEAM_ID=NW22NWLTK4 \
  APPLE_KEY_ID=ANA4NT26KP \
  APPLE_CLIENT_ID=com.ronganminh.repCounterApp \
  APPLE_PRIVATE_KEY="$(cat ~/secure/AuthKey_ANA4NT26KP.p8)"
#    SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by Supabase; do not set them.

# 2. Schema (profiles + RLS). Review the SQL first; this changes the staging database.
supabase db push --linked

# 3. The function. JWT verification stays ON (default): only signed-in users can call it.
supabase functions deploy delete-account --project-ref rvysencgtomkzwgdjaqh

# 4. Check
supabase functions list --project-ref rvysencgtomkzwgdjaqh
supabase secrets list   --project-ref rvysencgtomkzwgdjaqh   # names only, values are hidden
```

**Smoke test on staging, without deleting a real user.** Expect
`401 {"error":"unauthorized"}`:

```bash
curl -i -X POST https://rvysencgtomkzwgdjaqh.supabase.co/functions/v1/delete-account \
  -H "Authorization: Bearer invalid"
```

**Full test:** run device step D9 in `docs/implementation/05_SUPABASE_SETUP.md`
§11 with a throwaway account. Then check in the dashboard:

- the user is gone from Authentication › Users;
- the `profiles` row is gone;
- for an Apple account, the function log shows
  `{"event":"apple_revoke","ok":true}`, and the app disappears from Settings ›
  Apple ID › Sign in with Apple on the iPhone.

## Production

Not created yet. When it is, repeat the steps with the production project ref
and its own secrets, after an explicit owner approval.
