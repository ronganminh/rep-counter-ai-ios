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
    timed = [s for s in samples if s.get("at_ms", "").isdigit()]
    if timed and timed[0].get("phase") == "positioning":
        # First time the workout leaves positioning; a long recording goes
        # back to positioning between sets, the per-set table covers that.
        left = next((int(s["at_ms"]) for s in timed
                     if s.get("phase") != "positioning"), None)
        parts.append("positioning the whole clip" if left is None
                     else f"positioning until ~{left / 1000:.0f} s")
    no_pose = sum(1 for s in samples if s.get("pose") == "false")
    if no_pose:
        parts.append(f"pose lost {no_pose}/{n}")
    placements = collections.Counter(
        s.get("placement") for s in samples
        if s.get("pose") == "true" and s.get("placement") not in (None, "ok", "ready"))
    if placements:
        top = ", ".join(f"{k} {v}/{n}" for k, v in placements.most_common(2))
        parts.append(f"placement {top}")
    details = collections.Counter(
        s.get("detail") for s in samples
        if s.get("placement") not in (None, "ready") and s.get("detail"))
    if details:
        parts.append("detail " + details.most_common(1)[0][0].replace("_", " "))
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


def _tally(samples: list[dict[str, str]], key: str) -> collections.Counter:
    """Sum the CI `out=`/`miss=` landmark tallies (frames) over samples."""
    total: collections.Counter = collections.Counter()
    for s in samples:
        for part in s.get(key, "none").split(","):
            name, _, n = part.partition(":")
            if n.isdigit():
                total[name] += int(n)
    return total


def _reps(s: dict[str, str]) -> int | None:
    return int(s["reps"]) if s.get("reps", "").isdigit() else None


def per_set(clip: dict, samples: list[dict[str, str]]) -> list[dict]:
    """Break a long recording down by the eye-annotated sets.

    Status lines come every 5 s, so per-set counts are read at the sample
    before the lifter walks in and the first sample 5 s after the set ends
    (to let a late count land); positioning times are +-5 s.
    """
    timed = [(int(s["at_ms"]), s) for s in samples if _reps(s) is not None]
    if not timed:
        return []

    def reps_at_or_before(ms: int) -> int:
        before = [_reps(s) for t, s in timed if t <= ms]
        return before[-1] if before else 0

    rows = []
    for st in clip["sets"]:
        start, end = st["walk_in_ms"], st["end_ms"] + 5000
        in_set = [(t, s) for t, s in timed if st["ready_ms"] <= t <= st["end_ms"]]
        countable = [t for t, s in in_set if s.get("countable") == "true"]
        first_count = next((t for t, s in timed
                            if start < t <= end and _reps(s) > reps_at_or_before(start)),
                           None)
        app = reps_at_or_before(end) - reps_at_or_before(start)
        right, missed, extra = score(st["reps"], app)
        placements = collections.Counter(
            s.get("placement") for t, s in in_set if s.get("countable") != "true")
        details = collections.Counter(
            s.get("detail", "").replace("_", " ") for t, s in in_set
            if s.get("countable") != "true" and s.get("detail"))
        phases = []
        for t, s in in_set:
            if not phases or phases[-1] != s.get("phase"):
                phases.append(s.get("phase"))
        rows.append({
            "set": st["set"], "real": st["reps"], "app": app,
            "right": right, "missed": missed, "extra": extra,
            "ready_s": st["ready_ms"] / 1000,
            "first_rep_s": st["first_rep_ms"] / 1000,
            "first_countable_s": countable[0] / 1000 if countable else None,
            "first_count_by_s": first_count / 1000 if first_count else None,
            "eye_reps_before_first_count": (
                sum(1 for t in st["image_left_ms"] + st["image_right_ms"]
                    if first_count is not None and t < first_count - 5000)
                if first_count else st["reps"]),
            "stuck": not countable,
            "countable_share": f"{len(countable)}/{len(in_set)}",
            "phases": phases,
            "not_countable": dict(placements.most_common(3)),
            "detail": details.most_common(1)[0][0] if details else None,
            "outside_frames": dict(_tally([s for t, s in in_set], "out").most_common(4)),
            "missing_frames": dict(_tally([s for t, s in in_set], "miss").most_common(4)),
        })
    return rows


def rest_extras(clip: dict, samples: list[dict[str, str]]) -> list[tuple[float, float, int]]:
    """Reps the app added inside eye-annotated rest windows (after the
    5-s grace that per_set gives a set)."""
    timed = [(int(s["at_ms"]), _reps(s)) for s in samples if _reps(s) is not None]
    out = []
    for a, b in clip.get("rest_ms", []):
        inside = [r for t, r in timed if a + 5000 <= t <= b]
        if len(inside) >= 2 and inside[-1] > inside[0]:
            out.append((a / 1000, b / 1000, inside[-1] - inside[0]))
    return out


def per_set_markdown(sets: list[dict], rests: list) -> str:
    def sec(v):
        return "—" if v is None else f"{v:.0f} s"

    def top(d):
        return ", ".join(f"{k} {v}" for k, v in d.items()) or "—"

    lines = ["| set | real | app | right | missed | extra | ready → first countable "
             "sample | first count by | stuck | countable samples | not countable | "
             "outside guide (frames) | missing (frames) |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in sets:
        lines.append(
            f"| {r['set']} | {r['real']} | {r['app']} | {r['right']} | {r['missed']} | "
            f"{r['extra']} | {sec(r['ready_s'])} → {sec(r['first_countable_s'])} | "
            f"{sec(r['first_count_by_s'])} (first rep {sec(r['first_rep_s'])}) | "
            f"{'yes' if r['stuck'] else 'no'} | {r['countable_share']} | "
            f"{top(r['not_countable'])}{'; ' + r['detail'] if r['detail'] else ''} | "
            f"{top(r['outside_frames'])} | {top(r['missing_frames'])} |")
    if rests:
        lines.append("")
        lines.append("Reps added during rest: " + "; ".join(
            f"{a:.0f}-{b:.0f} s +{n}" for a, b, n in rests))
    else:
        lines.append("")
        lines.append("Reps added during rest: none")
    return "\n".join(lines)


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
    samples = [{"at_ms": m.group(1), **dict(FIELD.findall(m.group(2)))}
               for m in SAMPLE.finditer(timeline)]
    match = RESULT.search(result)

    harness_error = None
    if match is None:
        harness_error = "no CI_VIDEO_RESULT"
    elif exercise is not None and exercise != clip["exercise"]:
        harness_error = f"replayed {exercise}, expected {clip['exercise']}"

    counted = int(match.group(1)) if match else None
    sets = per_set(clip, samples) if clip.get("sets") else []
    rests = rest_extras(clip, samples) if clip.get("rest_ms") else []
    if counted is None:
        right = missed = extra = "—"
    elif sets:
        # A long recording: a count during rest is not a right rep, so add
        # the sets up instead of comparing totals.
        right = sum(r["right"] for r in sets)
        missed = truth - right
        extra = counted - right
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
                     + (f"{clip['loops']} loops x {clip['reps_per_loop']} rep(s), "
                        if clip.get("kind") == "sample" else
                        f"{len(clip.get('sets', []))} sets, ")
                     + f"counted by {clip['counted_by']}"
                     + ("" if clip.get("human_reviewed", True)
                        else " (not yet checked by a person)") + ".\n")
    if sets:
        set_md = per_set_markdown(sets, rests)
        print(set_md)
        if summary:
            with open(summary, "a", encoding="utf-8") as fh:
                fh.write("\n" + set_md + "\n")
    if args.json_out:
        args.json_out.write_text(json.dumps({
            "clip": args.clip, "platform": args.platform,
            "exercise_opened": exercise, "human_ground_truth": truth,
            "app_counted": counted, "right": right, "missed": missed,
            "extra": extra, "reason": reason, "samples": len(samples),
            "sets": sets, "rest_extras": rests,
        }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    if harness_error:
        print(f"FAIL (harness): {harness_error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
