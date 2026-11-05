#!/usr/bin/env python3
"""Report one clip smoke replay (plan 07 PR B). Measure only.

Reads the replay result and status timeline, compares the app count with the
eye-counted ground truth in test/fixtures/clip_smoke_set.json and prints one
Markdown row: clip | platform | real reps | app counted | right | missed |
extra | reason. "Reason" summarises the CI debug fields (pose, placement,
gate, raw_l/raw_r, signal) over the sampled frames.

Exit code is 0 whatever the count is. It is 1 only when the harness itself
failed: no CI_VIDEO_RESULT, or the replay ran another exercise than the
clip's (for example the locked pull-up did not open).
"""

import argparse
import collections
import json
import os
import pathlib
import re
import sys

RESULT = re.compile(r"\[CI_VIDEO_RESULT\].*\bhud_reps=(\d+)(?:\s|$)")
STARTED = re.compile(r"production_workout_started\b.*\bexercise=(\w+)")
SAMPLE = re.compile(r"\[CI_VIDEO_STATUS\] production_workout at_ms=(\d+)\b(.*)")
FIELD = re.compile(r"(\w+)=(\S+)")


def score(truth: int, counted: int) -> tuple[int, int, int]:
    """(right, missed, extra) for one clip."""
    right = min(truth, counted)
    return right, truth - right, counted - right


def reasons(samples: list[dict[str, str]]) -> str:
    """Why frames could not count, as shares of the sampled frames."""
    if not samples:
        return "no timeline samples"
    n = len(samples)
    parts = []
    no_pose = sum(1 for s in samples if s.get("pose") == "false")
    if no_pose:
        parts.append(f"pose lost {no_pose}/{n}")
    placements = collections.Counter(
        s.get("placement") for s in samples
        if s.get("pose") == "true" and s.get("placement") not in (None, "ok", "ready"))
    if placements:
        top = ", ".join(f"{k} {v}" for k, v in placements.most_common(2))
        parts.append(f"placement {top}/{n}")
    closed = sum(1 for s in samples
                 if s.get("pose") == "true" and s.get("gate") == "false")
    if closed:
        parts.append(f"gate closed {closed}/{n}")
    not_countable = sum(1 for s in samples if s.get("countable") == "false")
    if not_countable and not parts:
        parts.append(f"not countable {not_countable}/{n}")
    signals = [s.get("signal") for s in samples if s.get("signal") not in (None, "na", "null")]
    if signals:
        try:
            values = [float(v) for v in signals]
            parts.append(f"signal {min(values):.2f}..{max(values):.2f}")
        except ValueError:
            pass
    return "; ".join(parts) if parts else "all sampled frames countable"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=pathlib.Path)
    parser.add_argument("--clip", required=True)
    parser.add_argument("--platform", required=True)
    parser.add_argument("--result", required=True, type=pathlib.Path)
    parser.add_argument("--timeline", type=pathlib.Path)
    parser.add_argument("--json-out", type=pathlib.Path)
    args = parser.parse_args()

    clip = json.loads(args.manifest.read_text(encoding="utf-8"))["clips"][args.clip]
    truth = clip["human_ground_truth"]
    result = args.result.read_text(encoding="utf-8") if args.result.exists() else ""
    timeline = (args.timeline.read_text(encoding="utf-8", errors="replace")
                if args.timeline and args.timeline.exists() else "")

    started = STARTED.search(timeline + "\n" + result)
    exercise = started.group(1) if started else None
    samples = [dict(FIELD.findall(m.group(2))) for m in SAMPLE.finditer(timeline)]
    match = RESULT.search(result)

    harness_error = None
    if match is None:
        harness_error = "no CI_VIDEO_RESULT"
    elif exercise is not None and exercise != clip["exercise"]:
        harness_error = f"replayed {exercise}, expected {clip['exercise']}"

    counted = int(match.group(1)) if match else None
    if counted is None:
        right = missed = extra = "—"
    else:
        right, missed, extra = score(truth, counted)
    reason = harness_error or reasons(samples)
    row = (f"| {args.clip} | {args.platform} | {truth} | "
           f"{'—' if counted is None else counted} | {right} | {missed} | "
           f"{extra} | {reason} |")
    header = ("| clip | platform | real reps | app counted | right | missed | "
              "extra | reason |\n|---|---|---|---|---|---|---|---|")
    print(header)
    print(row)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write(f"### Clip smoke ({args.platform}, measure only)\n\n"
                     f"{header}\n{row}\n\n"
                     f"Exercise opened: `{exercise}`; "
                     f"{len(samples)} timeline samples; "
                     f"{clip['loops']} loops x {clip['reps_per_loop']} rep(s), "
                     f"{clip['counted_by']}.\n")
    if args.json_out:
        args.json_out.write_text(json.dumps({
            "clip": args.clip, "platform": args.platform,
            "exercise_opened": exercise, "human_ground_truth": truth,
            "app_counted": counted, "right": right, "missed": missed,
            "extra": extra, "reason": reason, "samples": len(samples),
        }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    if harness_error:
        print(f"FAIL (harness): {harness_error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
