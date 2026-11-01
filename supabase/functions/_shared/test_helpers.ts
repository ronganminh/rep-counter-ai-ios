// Test-only helpers: fake JWS strings and generated keys (no network, no
// real credentials).
import { b64url } from "./jwt.ts";

export const fakeJws = (payload: Record<string, unknown>) =>
  `${b64url(new TextEncoder().encode('{"alg":"ES256"}'))}.${
    b64url(new TextEncoder().encode(JSON.stringify(payload)))
  }.c2ln`;

async function pkcs8Pem(key: CryptoKey): Promise<string> {
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", key));
  const b64 = btoa(String.fromCharCode(...der));
  return `-----BEGIN PRIVATE KEY-----\n${
    b64.match(/.{1,64}/g)!.join("\n")
  }\n-----END PRIVATE KEY-----\n`;
}

export async function ecKeyPem() {
  const pair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  ) as CryptoKeyPair;
  return { pem: await pkcs8Pem(pair.privateKey), publicKey: pair.publicKey };
}

export async function rsaKeyPem() {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  ) as CryptoKeyPair;
  return { pem: await pkcs8Pem(pair.privateKey), publicKey: pair.publicKey };
}

export function b64urlDecode(s: string): Uint8Array<ArrayBuffer> {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(
    atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4)),
    (c) => c.charCodeAt(0),
  );
}

export const jsonResponse = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status });
