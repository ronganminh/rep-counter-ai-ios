#!/usr/bin/env python3
"""Generate the Sign in with Apple OAuth client secret for Supabase (D-12).

Supabase's Apple provider needs a "Secret Key (for OAuth)": an ES256 JWT
signed with the Sign in with Apple key (.p8). Apple accepts at most six
months of validity, so this must be re-run before it expires.

Run it locally; the .p8 never enters the repository:

    python3 tool/apple_oauth_secret.py \\
        --p8 ~/secure/AuthKey_ANA4NT26KP.p8 \\
        --team-id NW22NWLTK4 --key-id ANA4NT26KP \\
        --client-id com.ronganminh.repcoach.signin

The JWT is printed to stdout (paste it into Supabase > Authentication >
Providers > Apple > Secret Key) and the expiry date to stderr. Nothing is
written to disk. Only the Python standard library and the `openssl` CLI are
used.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import json
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

AUDIENCE = "https://appleid.apple.com"
# Apple's limit is 15777000 s (~182.6 days).
MAX_SECONDS = 15_777_000
DEFAULT_DAYS = 180
APPLE_ID = re.compile(r"^[A-Z0-9]{10}$")


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _der_int(data: bytes, i: int) -> tuple[int, int]:
    if data[i] != 0x02:
        raise ValueError("expected DER INTEGER")
    length = data[i + 1]
    start = i + 2
    return int.from_bytes(data[start:start + length], "big"), start + length


def der_to_raw(sig: bytes, size: int = 32) -> bytes:
    """ECDSA DER SEQUENCE{r, s} -> JWS raw r||s (64 bytes for P-256)."""
    if sig[0] != 0x30:
        raise ValueError("expected DER SEQUENCE")
    i = 2 if sig[1] < 0x80 else 2 + (sig[1] & 0x7F)
    r, i = _der_int(sig, i)
    s, _ = _der_int(sig, i)
    return r.to_bytes(size, "big") + s.to_bytes(size, "big")


def _repo_root(start: Path) -> Path | None:
    for parent in [start, *start.parents]:
        if (parent / ".git").exists():
            return parent
    return None


def build_secret(p8: Path, team_id: str, key_id: str, client_id: str,
                 days: int = DEFAULT_DAYS, now: int | None = None) -> tuple[str, int]:
    """Returns (jwt, exp). Signs with `openssl dgst -sha256 -sign`."""
    for name, value in (("team id", team_id), ("key id", key_id)):
        if not APPLE_ID.match(value):
            raise ValueError(f"{name} must be 10 upper-case letters/digits")
    if not client_id or " " in client_id:
        raise ValueError("client id (Services ID) is required")
    iat = int(time.time()) if now is None else now
    exp = iat + min(days * 86_400, MAX_SECONDS)
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    claims = {"iss": team_id, "iat": iat, "exp": exp,
              "aud": AUDIENCE, "sub": client_id}
    signing_input = (b64url(json.dumps(header, separators=(",", ":")).encode())
                     + "." +
                     b64url(json.dumps(claims, separators=(",", ":")).encode()))
    with tempfile.NamedTemporaryFile() as data:
        data.write(signing_input.encode("ascii"))
        data.flush()
        der = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", str(p8), data.name],
            check=True, capture_output=True).stdout
    return signing_input + "." + b64url(der_to_raw(der)), exp


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--p8", required=True, type=Path,
                    help="Sign in with Apple key (.p8), kept outside the repo")
    ap.add_argument("--team-id", required=True)
    ap.add_argument("--key-id", required=True)
    ap.add_argument("--client-id", required=True,
                    help="Services ID, e.g. com.ronganminh.repcoach.signin")
    ap.add_argument("--days", type=int, default=DEFAULT_DAYS,
                    help=f"validity in days (max ~182, default {DEFAULT_DAYS})")
    args = ap.parse_args(argv)

    p8 = args.p8.expanduser().resolve()
    if not p8.is_file():
        print(f"error: {p8} not found", file=sys.stderr)
        return 2
    root = _repo_root(Path(__file__).resolve().parent)
    if root is not None and root in p8.parents:
        print("error: the .p8 key must not live inside the repository "
              f"({root}); move it to a private location", file=sys.stderr)
        return 2
    try:
        jwt, exp = build_secret(p8, args.team_id, args.key_id,
                                args.client_id, args.days)
    except (ValueError, subprocess.CalledProcessError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    expires = dt.datetime.fromtimestamp(exp, dt.timezone.utc)
    print(jwt)
    print(f"Paste into Supabase > Authentication > Providers > Apple > "
          f"Secret Key (for OAuth). Expires {expires:%Y-%m-%d %H:%M} UTC; "
          f"set a reminder to regenerate before then.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
