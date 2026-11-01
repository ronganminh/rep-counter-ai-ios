// JWT helpers for calling Apple and Google server APIs from Edge Functions
// (WebCrypto only, no remote imports).

export const b64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

const enc = (o: unknown) => b64url(new TextEncoder().encode(JSON.stringify(o)));

export function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

async function sign(
  header: Record<string, unknown>,
  payload: Record<string, unknown>,
  key: CryptoKey,
  algorithm: AlgorithmIdentifier | EcdsaParams,
): Promise<string> {
  const input = `${enc(header)}.${enc(payload)}`;
  const sig = new Uint8Array(
    await crypto.subtle.sign(algorithm, key, new TextEncoder().encode(input)),
  );
  return `${input}.${b64url(sig)}`;
}

/** ES256 JWT with a PKCS#8 .p8 key (App Store Server API). */
export async function signEs256(
  header: Record<string, unknown>,
  payload: Record<string, unknown>,
  privateKeyPem: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(privateKeyPem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  // WebCrypto returns the IEEE P1363 r||s form that JWS ES256 expects.
  return sign({ alg: "ES256", typ: "JWT", ...header }, payload, key, {
    name: "ECDSA",
    hash: "SHA-256",
  });
}

/** RS256 JWT with a PKCS#8 RSA key (Google service account). */
export async function signRs256(
  payload: Record<string, unknown>,
  privateKeyPem: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(privateKeyPem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return sign({ alg: "RS256", typ: "JWT" }, payload, key, {
    name: "RSASSA-PKCS1-v1_5",
  });
}

/**
 * The payload of a JWS without checking its signature. Only for reading an
 * identifier that is then confirmed with the store's own server API; never
 * trust what it says otherwise.
 */
export function decodeJwsPayloadUnverified(
  jws: string,
): Record<string, unknown> | null {
  const parts = jws.split(".");
  if (parts.length !== 3) return null;
  try {
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const json = new TextDecoder().decode(
      Uint8Array.from(
        atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4)),
        (c) => c.charCodeAt(0),
      ),
    );
    const value = JSON.parse(json);
    return value && typeof value === "object" && !Array.isArray(value)
      ? value as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}
