"""Local CI staging harness: real RepCoach HTTP handler, fake AI provider output."""
from __future__ import annotations

import os
from http.server import ThreadingHTTPServer

import server


def _synthetic_feedback(workout: dict, deadline: float) -> str:
    del deadline
    return (
        "Synthetic staging feedback for "
        f"{workout['exercise']} with {workout['reps']} reps."
    )


server.generate_feedback = _synthetic_feedback
server.provider_configuration_ready = lambda: True

if __name__ == "__main__":
    host = os.getenv("BIND_HOST", "127.0.0.1")
    port = int(os.getenv("PORT", "8787"))
    print(f"RepCoach synthetic staging backend: http://{host}:{port}", flush=True)
    ThreadingHTTPServer((host, port), server.Handler).serve_forever()
