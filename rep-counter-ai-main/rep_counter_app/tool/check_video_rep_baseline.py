#!/usr/bin/env python3
"""Fail when a production replay regresses below its recorded baseline."""

import argparse
import json
import pathlib
import re
import sys


RESULT = re.compile(r"\[CI_VIDEO_RESULT\].*\bhud_reps=(\d+)(?:\s|$)")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--result", required=True, type=pathlib.Path)
    parser.add_argument("--manifest", required=True, type=pathlib.Path)
    parser.add_argument("--fixture", required=True)
    args = parser.parse_args()

    metadata = json.loads(args.manifest.read_text(encoding="utf-8"))[args.fixture]
    expected = metadata.get("current_engine_count")
    if not isinstance(expected, int):
        raise ValueError(f"{args.fixture} has no integer current_engine_count")

    match = RESULT.search(args.result.read_text(encoding="utf-8"))
    if match is None:
        raise ValueError("CI replay result is missing hud_reps")
    actual = int(match.group(1))
    if actual != expected:
        raise AssertionError(
            f"{args.fixture} rep regression: expected {expected}, got {actual}"
        )

    print(f"PASS: {args.fixture} preserved the {expected}-rep baseline")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (AssertionError, KeyError, OSError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
