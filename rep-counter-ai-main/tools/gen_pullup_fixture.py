"""Sinh fixture kéo xà cho test Dart từ video thật trong `pull_up/`.

Chạy MediaPipe Pose trên từng video, lấy mẫu 7.5 fps (gần tốc độ khung thật
của app trên máy tầm trung), rồi ghi ra `rep_counter_app/test/fixtures/`:

  - góc khuỷu trái/phải (null khi một trong ba điểm có visibility < 0.4),
  - cổng "tay ngang vai": cổ tay không thấp hơn vai quá 0.3 bề rộng vai,
  - thời điểm rep mà bộ đếm tham chiếu (bản Python dưới đây) tính được.

Bản tham chiếu phải chạy ĐÚNG như `camera_page.dart` với profile `pullUp`:
trung bình hai tay -> RollingMean(2) -> cổng từng khung -> RepCounter với
`startFromTop`. Test Dart so từng thời điểm rep với số ở đây.

Đếm tay (ground truth) trên video: IMG_8708 = 47 rep (10 set), video quay
lưng = 30 rep (15 set x 2). Xem docs/PULL_UP.md.

    python tools/gen_pullup_fixture.py
"""
from __future__ import annotations

import json
from collections import deque
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "rep_counter_app" / "test" / "fixtures"
VIDEOS = [
    # (file, fixture name, cỡ khung đưa vào pose, ground truth)
    ("IMG_8708.MOV", "pull_up_front", (540, 960), 47),
    ("Messenger_creation_394F54C2-CC7C-4726-AC52-3958F10278B5.mp4",
     "pull_up_back_closeup", None, 30),
]
STEP = 4          # 30 fps / 4 = 7.5 fps
ML = 0.4          # = pullUp.minLikelihood
GATE = -0.3       # = _pullUpGateMargin trong exercise.dart
HI, LO, AMP, MIN_PERIOD, WIN = 140.0, 90.0, 40.0, 0.8, 2


def extract(path: Path, size):
    cap = cv2.VideoCapture(str(path))
    pose = mp.solutions.pose.Pose(model_complexity=1)
    rows, i = [], 0
    while cap.grab():
        if i % STEP == 0:
            _, im = cap.retrieve()
            t = cap.get(cv2.CAP_PROP_POS_MSEC) / 1000
            if size:
                im = cv2.resize(im, size)
            h, w = im.shape[:2]
            r = pose.process(cv2.cvtColor(im, cv2.COLOR_BGR2RGB))
            lm = (
                [(l.x * w, l.y * h, l.visibility) for l in r.pose_landmarks.landmark]
                if r.pose_landmarks else None
            )
            rows.append((t, lm))
        i += 1
    return rows


def features(rows):
    t_ms, left, right, gate = [], [], [], []

    def pt(lm, k):
        x, y, v = lm[k]
        return None if v < ML else (x, y)

    def angle(a, b, c):
        if a is None or b is None or c is None:
            return None
        v1 = np.subtract(a, b); v2 = np.subtract(c, b)
        n = np.linalg.norm(v1) * np.linalg.norm(v2)
        if n < 1e-6:
            return None
        return round(float(np.degrees(np.arccos(np.clip(np.dot(v1, v2) / n, -1, 1)))), 2)

    for t, lm in rows:
        t_ms.append(int(round(t * 1000)))
        if lm is None:
            left.append(None); right.append(None); gate.append(False)
            continue
        ls, rs = pt(lm, 11), pt(lm, 12)
        lw, rw = pt(lm, 15), pt(lm, 16)
        left.append(angle(ls, pt(lm, 13), lw))
        right.append(angle(rs, pt(lm, 14), rw))
        ok = False
        if ls and rs:
            sw = float(np.hypot(ls[0] - rs[0], ls[1] - rs[1]))
            wys = [w[1] for w in (lw, rw) if w]
            if sw > 1e-3 and wys:
                sy = (ls[1] + rs[1]) / 2
                ok = (sy - sum(wys) / len(wys)) / sw > GATE
        gate.append(bool(ok))
    return dict(t_ms=t_ms, left=left, right=right, gate=gate)


def reference(d):
    buf, phase, trough, last, reps = deque(), None, 0.0, None, []
    for t, l, r, g in zip(d["t_ms"], d["left"], d["right"], d["gate"]):
        vals = [q for q in (l, r) if q is not None]
        # Như camera_page: rời cổng -> huỷ chu kỳ VÀ xoá bộ làm mượt; chỉ mất
        # tín hiệu tay -> huỷ chu kỳ nhưng bộ làm mượt giữ nguyên.
        if not g:
            phase = None; buf.clear(); continue
        if not vals:
            phase = None; continue
        buf.append(sum(vals) / len(vals))
        if len(buf) > WIN:
            buf.popleft()
        s = sum(buf) / len(buf)
        if phase is None:
            if s > HI:
                phase = "up"
            trough = s
            continue
        if phase == "down":
            trough = min(trough, s)
            if s > HI:
                phase = "up"
                if s - trough >= AMP and (last is None or (t - last) / 1000 >= MIN_PERIOD):
                    last = t; reps.append(t)
        elif s < LO:
            phase = "down"; trough = s
    return reps


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for file, name, size, truth in VIDEOS:
        d = features(extract(ROOT / "pull_up" / file, size))
        d["expected_rep_ms"] = reference(d)
        meta = dict(source=file, fps=30 / STEP, hi=HI, lo=LO, min_amplitude=AMP,
                    min_period_ms=int(MIN_PERIOD * 1000), smooth_window=WIN,
                    ground_truth_reps=truth)
        (OUT / f"{name}.json").write_text(
            json.dumps({**meta, **d}, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8")
        print(f"{name}: {len(d['expected_rep_ms'])} rep (đếm tay {truth})")


if __name__ == "__main__":
    main()
