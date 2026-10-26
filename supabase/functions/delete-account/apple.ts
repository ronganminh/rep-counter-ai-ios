// Sign in with Apple token revocation for account deletion.
// https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens
//
// The app sends a fresh authorization code from the native sheet. It is
// exchanged for a refresh token at /auth/token and that token is revoked at
// /auth/revoke. Both calls need a client secret: an ES256 JWT signed with
// the Sign in with Apple key (.p8), held only in Edge Function secrets.

export interface AppleConfig {
  teamId: string;
  keyId: string;
  /** The audience of codes from the native iOS sheet: the app bundle id. */
  clientId: string;
  /** PKCS#8 PEM contents of the .p8 key. */
  privateKeyPem: string;
}

const APPLE = "https://appleid.apple.com";

const b64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

const enc = (o: unknown) => b64url(new TextEncoder().encode(JSON.stringify(o)));

function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

/** ES256 client secret, valid for [ttlSeconds] (short: used immediately). */
export async function appleClientSecret(
  cfg: AppleConfig,
  nowSeconds = Math.floor(Date.now() / 1000),
  ttlSeconds = 300,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(cfg.privateKeyPem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const input = `${enc({ alg: "ES256", kid: cfg.keyId, typ: "JWT" })}.${
    enc({
      iss: cfg.teamId,
      iat: nowSeconds,
      exp: nowSeconds + ttlSeconds,
      aud: APPLE,
      sub: cfg.clientId,
    })
  }`;
  // WebCrypto returns the IEEE P1363 r||s form that JWS ES256 expects.
  const sig = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      new TextEncoder().encode(input),
    ),
  );
  return `${input}.${b64url(sig)}`;
}

export async function revokeAppleAuthorizationCode(
  code: string,
  cfg: AppleConfig,
  fetchFn: typeof fetch = fetch,
): Promise<boolean> {
  const secret = await appleClientSecret(cfg);
  const form = (fields: Record<string, string>) =>
    fetchFn(`${APPLE}${fields.path}`, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams(
        Object.fromEntries(
          Object.entries(fields).filter(([k]) => k !== "path"),
        ),
      ),
    });

  const tokenRes = await form({
    path: "/auth/token",
    client_id: cfg.clientId,
    client_secret: secret,
    code,
    grant_type: "authorization_code",
  });
  if (!tokenRes.ok) return false;
  const tokens = await tokenRes.json() as {
    refresh_token?: string;
    access_token?: string;
  };
  const token = tokens.refresh_token ?? tokens.access_token;
  if (!token) return false;

  const revokeRes = await form({
    path: "/auth/revoke",
    client_id: cfg.clientId,
    client_secret: secret,
    token,
    token_type_hint: tokens.refresh_token ? "refresh_token" : "access_token",
  });
  return revokeRes.ok;
}
