#!/usr/bin/env python3
"""Fail when the production replay adds reps inside annotated rest windows."""

import argparse
import json
import pathlib
import re
import sys


STATUS = re.compile(
    r"\[CI_VIDEO_STATUS\].*\bat_ms=(\d+).*\breps=(\d+)(?:\s|$)"
)
RESULT = re.compile(r"\[CI_VIDEO_RESULT\].*\bhud_reps=(\d+)(?:\s|$)")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeline", required=True, type=pathlib.Path)
    parser.add_argument("--result", required=True, type=pathlib.Path)
    parser.add_argument("--manifest", required=True, type=pathlib.Path)
    parser.add_argument("--fixture", required=True)
    args = parser.parse_args()

    metadata = json.loads(args.manifest.read_text(encoding="utf-8"))[args.fixture]
    windows = metadata.get("rest_intervals_ms", [])
    if not windows:
        raise ValueError(f"{args.fixture} has no annotated rest intervals")

    samples = []
    for line in args.timeline.read_text(encoding="utf-8").splitlines():
        match = STATUS.search(line)
        if match:
            samples.append((int(match.group(1)), int(match.group(2))))

    result_match = RESULT.search(args.result.read_text(encoding="utf-8"))
    if result_match is None:
        raise ValueError("CI replay result is missing hud_reps")
    final_reps = int(result_match.group(1))
    if final_reps <= 0:
        raise AssertionError(
            "fixture contains real push-ups but production replay counted none"
        )

    failures = []
    for start_ms, end_ms in windows:
        inside = [(at_ms, reps) for at_ms, reps in samples
                  if start_ms <= at_ms <= end_ms]
        if len(inside) < 2:
            failures.append(
                f"rest {start_ms}-{end_ms}ms has only {len(inside)} timeline sample(s)"
            )
            continue
        first_reps = inside[0][1]
        last_reps = inside[-1][1]
        if first_reps != last_reps:
            failures.append(
                f"rest {start_ms}-{end_ms}ms changed reps {first_reps}->{last_reps}"
            )

    if failures:
        raise AssertionError("; ".join(failures))

    print(
        f"PASS: {args.fixture} kept reps stable across "
        f"{len(windows)} annotated rest intervals; final reps={final_reps}"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (AssertionError, KeyError, OSError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
