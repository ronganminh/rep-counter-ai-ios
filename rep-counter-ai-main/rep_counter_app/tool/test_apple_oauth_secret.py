"""Tests for apple_oauth_secret.py with a throwaway P-256 key.

    python3 -m unittest tool/test_apple_oauth_secret.py
"""
from __future__ import annotations

import base64
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import apple_oauth_secret as tool  # noqa: E402


def _b64d(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def _raw_to_der(raw: bytes) -> bytes:
    def integer(b: bytes) -> bytes:
        b = b.lstrip(b"\x00") or b"\x00"
        if b[0] & 0x80:
            b = b"\x00" + b
        return b"\x02" + bytes([len(b)]) + b
    body = integer(raw[:32]) + integer(raw[32:])
    return b"\x30" + bytes([len(body)]) + body


class AppleOAuthSecretTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        d = Path(self.tmp.name)
        self.p8 = d / "AuthKey_TEST.p8"
        self.pub = d / "pub.pem"
        subprocess.run(["openssl", "genpkey", "-algorithm", "EC", "-pkeyopt",
                        "ec_paramgen_curve:P-256", "-out", str(self.p8)],
                       check=True, capture_output=True)
        subprocess.run(["openssl", "pkey", "-in", str(self.p8), "-pubout",
                        "-out", str(self.pub)], check=True, capture_output=True)

    def tearDown(self):
        self.tmp.cleanup()

    def test_claims_header_and_valid_signature(self):
        jwt, exp = tool.build_secret(self.p8, "NW22NWLTK4", "ANA4NT26KP",
                                     "com.ronganminh.repcoach.signin",
                                     now=1_700_000_000)
        h, c, s = jwt.split(".")
        self.assertEqual(json.loads(_b64d(h)),
                         {"alg": "ES256", "kid": "ANA4NT26KP", "typ": "JWT"})
        claims = json.loads(_b64d(c))
        self.assertEqual(claims["iss"], "NW22NWLTK4")
        self.assertEqual(claims["sub"], "com.ronganminh.repcoach.signin")
        self.assertEqual(claims["aud"], "https://appleid.apple.com")
        self.assertEqual(claims["iat"], 1_700_000_000)
        self.assertEqual(claims["exp"], exp)
        raw = _b64d(s)
        self.assertEqual(len(raw), 64)
        with tempfile.NamedTemporaryFile() as data, \
                tempfile.NamedTemporaryFile() as sig:
            data.write(f"{h}.{c}".encode())
            data.flush()
            sig.write(_raw_to_der(raw))
            sig.flush()
            out = subprocess.run(
                ["openssl", "dgst", "-sha256", "-verify", str(self.pub),
                 "-signature", sig.name, data.name],
                capture_output=True, text=True)
        self.assertIn("Verified OK", out.stdout)

    def test_validity_is_capped_at_apple_maximum(self):
        _, exp = tool.build_secret(self.p8, "NW22NWLTK4", "ANA4NT26KP",
                                   "svc", days=400, now=0)
        self.assertEqual(exp, tool.MAX_SECONDS)
        _, exp = tool.build_secret(self.p8, "NW22NWLTK4", "ANA4NT26KP",
                                   "svc", days=180, now=0)
        self.assertEqual(exp, 180 * 86_400)

    def test_rejects_bad_ids(self):
        with self.assertRaises(ValueError):
            tool.build_secret(self.p8, "nw22", "ANA4NT26KP", "svc")
        with self.assertRaises(ValueError):
            tool.build_secret(self.p8, "NW22NWLTK4", "ANA4NT26KP", "")

    def test_refuses_key_inside_repository(self):
        inside = Path(tool.__file__).resolve().parent / "AuthKey_TMP.p8"
        inside.write_bytes(self.p8.read_bytes())
        try:
            self.assertEqual(tool.main([
                "--p8", str(inside), "--team-id", "NW22NWLTK4",
                "--key-id", "ANA4NT26KP", "--client-id", "svc"]), 2)
        finally:
            inside.unlink()

    def test_der_to_raw_pads_short_integers(self):
        der = _raw_to_der(b"\x00" * 31 + b"\x05" + b"\x7f" * 32)
        self.assertEqual(tool.der_to_raw(der), b"\x00" * 31 + b"\x05" + b"\x7f" * 32)


if __name__ == "__main__":
    unittest.main()
