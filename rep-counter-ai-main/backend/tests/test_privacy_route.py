import http.client
import re
import sys
import threading
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server


REQUEST_ID_RE = re.compile(r"^[0-9a-f]{32}$")


class PrivacyRouteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.httpd = server.ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
        cls.port = cls.httpd.server_address[1]
        cls.thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()
        cls.thread.join(timeout=2)

    def test_privacy_policy_is_served_by_backend(self):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=3)
        conn.request("GET", "/privacy-policy.html")
        response = conn.getresponse()
        body = response.read().decode("utf-8")
        headers = dict(response.getheaders())
        conn.close()

        self.assertEqual(response.status, 200)
        self.assertEqual(headers.get("content-type"), "text/html; charset=utf-8")
        self.assertEqual(headers.get("cache-control"), "no-store")
        self.assertRegex(headers.get("x-request-id", ""), REQUEST_ID_RE)
        self.assertIn("GroqCloud", body)
        self.assertIn("2026-10-01-groq", body)

    def test_unknown_route_stays_json_404(self):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=3)
        conn.request("GET", "/privacy-policy.txt")
        response = conn.getresponse()
        body = response.read().decode("utf-8")
        conn.close()

        self.assertEqual(response.status, 404)
        self.assertIn("NOT_FOUND", body)


if __name__ == "__main__":
    unittest.main()
