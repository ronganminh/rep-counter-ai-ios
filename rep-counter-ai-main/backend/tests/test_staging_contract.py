import http.client
import json
import sys
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

BACKEND = Path(__file__).resolve().parents[1]
PROJECT = BACKEND.parent
sys.path.insert(0, str(BACKEND))

import server

FIXTURE = json.loads(
    (PROJECT / "contracts" / "workout_feedback_v2.json").read_text(encoding="utf-8")
)


class CrossStackContractTests(unittest.TestCase):
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

    def test_shared_v2_fixture_is_accepted_over_real_backend_http(self):
        body = json.dumps(FIXTURE).encode("utf-8")
        with patch.object(
            server, "generate_feedback", return_value="Synthetic staging feedback"
        ):
            conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=3)
            conn.request(
                "POST",
                "/v1/workout-feedback",
                body=body,
                headers={"content-type": "application/json"},
            )
            response = conn.getresponse()
            raw = response.read()
            headers = {key.lower(): value for key, value in response.getheaders()}
            conn.close()

        self.assertEqual(response.status, 200)
        self.assertEqual(
            json.loads(raw.decode("utf-8")),
            {
                "schema_version": 1,
                "feedback": "Synthetic staging feedback",
            },
        )
        self.assertRegex(headers["x-request-id"], r"^[0-9a-f]{32}$")


if __name__ == "__main__":
    unittest.main()
