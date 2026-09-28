"""Replay labelled push-up clips through MediaPipe and derive a data guide.

This is an offline validation harness, not production app code. It intentionally
uses the same 33-landmark family as ML Kit Pose on Android.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np


JOINTS = {
    "nose": 0,
    "left_shoulder": 11,
    "right_shoulder": 12,
    "left_elbow": 13,
    "right_elbow": 14,
    "left_wrist": 15,
    "right_wrist": 16,
    "left_hip": 23,
    "right_hip": 24,
    "left_knee": 25,
    "right_knee": 26,
    "left_ankle": 27,
    "right_ankle": 28,
}
ARMS = ((11, 13, 15), (12, 14, 16))
REQUIRED = (11, 12, 13, 14, 15, 16, 23, 24)
LABELLED_WINDOWS = ((16.6, 20.05, 3), (160.3, 165.4, 5))


def angle(a: np.ndarray, b: np.ndarray, c: np.ndarray) -> float:
    u, v = a - b, c - b
    den = np.linalg.norm(u) * np.linalg.norm(v)
    if den < 1e-6:
        return math.nan
    return math.degrees(math.acos(np.clip(np.dot(u, v) / den, -1, 1)))


def fixed_counter(
    times: list[float], values: list[float], hi: float = 140,
    lo: float = 100, min_amp: float = 40,
) -> list[float]:
    phase, trough, last = None, math.inf, -math.inf
    reps: list[float] = []
    for t, value in zip(times, values):
        if not math.isfinite(value):
            phase = None
            continue
        if phase is None:
            phase = "up" if value > hi else "down"
            trough = value
        elif phase == "down":
            trough = min(trough, value)
            if value > hi:
                if value - trough >= min_amp and t - last >= 0.7:
                    reps.append(t)
                    last = t
                phase = "up"
        elif value < lo:
            phase, trough = "down", value
    return reps


def analyze(video: Path, out: Path) -> dict:
    cap = cv2.VideoCapture(str(video))
    if not cap.isOpened():
        raise RuntimeError(f"Cannot open {video}")
    fps = cap.get(cv2.CAP_PROP_FPS)
    pose = mp.solutions.pose.Pose(
        static_image_mode=False,
        model_complexity=1,
        smooth_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    )

    results = []
    guide_frames = []
    for start, end, expected in LABELLED_WINDOWS:
        # Warm the tracker/FSM before the labelled interval; starting exactly
        # on a repetition loses the preceding down phase unlike a live camera.
        cap.set(cv2.CAP_PROP_POS_MSEC, max(0, start - 5.0) * 1000)
        times, signals = [], []
        detected = total = 0
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            t = cap.get(cv2.CAP_PROP_POS_MSEC) / 1000
            if t > end:
                break
            total += 1
            if total % 2 == 0:
                continue
            result = pose.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
            times.append(t)
            if not result.pose_landmarks:
                signals.append(math.nan)
                continue
            lm = result.pose_landmarks.landmark
            detected += 1
            arm_angles = []
            for a, b, c in ARMS:
                if min(lm[a].visibility, lm[b].visibility, lm[c].visibility) >= 0.4:
                    arm_angles.append(angle(
                        np.array((lm[a].x, lm[a].y)),
                        np.array((lm[b].x, lm[b].y)),
                        np.array((lm[c].x, lm[c].y)),
                    ))
            signal = float(np.nanmean(arm_angles)) if arm_angles else math.nan
            signals.append(signal)
            if start <= t <= end and signal >= 140 and all(lm[i].visibility >= 0.4 for i in REQUIRED):
                guide_frames.append([[lm[i].x, lm[i].y, lm[i].visibility] for i in range(33)])

        counted = [t for t in fixed_counter(times, signals) if start <= t <= end]
        counted_data = [
            t for t in fixed_counter(times, signals, 130, 85, 35)
            if start <= t <= end
        ]
        finite = np.asarray(signals, dtype=float)
        finite = finite[np.isfinite(finite)]
        results.append({
            "start_s": start,
            "end_s": end,
            "expected_reps": expected,
            "fixed_threshold_reps": len(counted),
            "data_threshold_reps": len(counted_data),
            "rep_times_s": [round(x, 3) for x in counted],
            "pose_detection_rate": round(detected / max(1, len(times)), 4),
            "finite_signal_rate": round(float(np.isfinite(signals).mean()), 4),
            "angle_p10": round(float(np.percentile(finite, 10)), 2),
            "angle_p90": round(float(np.percentile(finite, 90)), 2),
        })

    pose.close()
    cap.release()
    if not guide_frames:
        raise RuntimeError("No suitable support frames found")

    median = np.nanmedian(np.asarray(guide_frames), axis=0)
    guide = {
        name: {"x": round(float(median[index, 0]), 5), "y": round(float(median[index, 1]), 5)}
        for name, index in JOINTS.items()
    }
    report = {
        "source": str(video),
        "fps": fps,
        "guide_support_frames": len(guide_frames),
        "windows": results,
        "median_guide_normalized": guide,
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--video", type=Path, default=Path("push_up/100pushup.mp4"))
    parser.add_argument("--out", type=Path, default=Path("analysis/pushup_replay_report.json"))
    args = parser.parse_args()
    report = analyze(args.video, args.out)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
