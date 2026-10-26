// delete-account (D-12, App Store guideline 5.1.1(v)).
//
// Pure request handling with injected dependencies, so it is unit-tested
// without Supabase or Apple (handler_test.ts). index.ts wires the real ones.
//
// Order: authenticate the caller's JWT -> revoke Sign in with Apple (when the
// app sent a fresh authorization code) -> delete the user's server rows ->
// delete the auth user (FKs with ON DELETE CASCADE remove anything left).
// Tokens, codes and error details are never logged or returned.

export interface DeleteAccountDeps {
  /** Resolves the bearer token to a user id, or null when invalid. */
  getUserId(jwt: string): Promise<string | null>;
  /** Whether the Apple secrets are configured in this function. */
  appleConfigured: boolean;
  /** Exchanges the code and revokes the Apple token; true on success. */
  revokeApple(authorizationCode: string): Promise<boolean>;
  /** Deletes rows owned by the user in public tables. */
  deleteUserData(userId: string): Promise<void>;
  /** Deletes the auth user (auth.admin.deleteUser). */
  deleteUser(userId: string): Promise<void>;
  log?(event: string, fields?: Record<string, unknown>): void;
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

export async function handleDeleteAccount(
  req: Request,
  deps: DeleteAccountDeps,
): Promise<Response> {
  const log = deps.log ?? (() => {});
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const auth = req.headers.get("authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(auth);
  if (!match) return json(401, { error: "unauthorized" });

  let code: string | undefined;
  const text = await req.text();
  if (text.trim().length > 0) {
    let body: unknown;
    try {
      body = JSON.parse(text);
    } catch {
      return json(400, { error: "invalid_body" });
    }
    const raw = (body as Record<string, unknown> | null)?.[
      "apple_authorization_code"
    ];
    if (raw !== undefined && raw !== null) {
      if (typeof raw !== "string" || raw.length === 0 || raw.length > 4096) {
        return json(400, { error: "invalid_body" });
      }
      code = raw;
    }
  }

  let userId: string | null;
  try {
    userId = await deps.getUserId(match[1].trim());
  } catch {
    userId = null;
  }
  if (!userId) return json(401, { error: "unauthorized" });

  // Apple first: once the auth user is gone the request cannot be retried.
  // A failed revoke does not block deletion (the user asked to delete);
  // it is reported so support can follow up.
  let appleRevoked: boolean | null = null;
  if (code) {
    if (deps.appleConfigured) {
      try {
        appleRevoked = await deps.revokeApple(code);
      } catch {
        appleRevoked = false;
      }
    } else {
      appleRevoked = false;
    }
    log("apple_revoke", { ok: appleRevoked });
  }

  try {
    await deps.deleteUserData(userId);
    await deps.deleteUser(userId);
  } catch {
    log("delete_failed");
    return json(500, { error: "delete_failed" });
  }
  log("deleted", { apple_revoked: appleRevoked });
  return json(200, { deleted: true, apple_revoked: appleRevoked });
}
