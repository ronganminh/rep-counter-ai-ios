"""Export a short MediaPipe landmark stream for Flutter's debug replay mode."""

import json
from pathlib import Path

import cv2
import mediapipe as mp


SOURCE = Path("push_up/100pushup.mp4")
OUTPUT = Path("rep_counter_app/assets/debug/pushup_replay.json")
# Best verified window: 5 visible reps at 160.3-165.4 s with 100% pose
# detection. Include a short lead-in/out so the real-time FSM has context.
START_S, END_S, STRIDE = 159.5, 165.35, 2
KEEP = (0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28)


cap = cv2.VideoCapture(str(SOURCE))
if not cap.isOpened():
    raise RuntimeError(f"Cannot open {SOURCE}")
fps = cap.get(cv2.CAP_PROP_FPS)
width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
cap.set(cv2.CAP_PROP_POS_MSEC, START_S * 1000)
pose = mp.solutions.pose.Pose(
    static_image_mode=False,
    model_complexity=1,
    smooth_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5,
)

frames = []
index = 0
while True:
    ok, image = cap.read()
    if not ok:
        break
    time_s = cap.get(cv2.CAP_PROP_POS_MSEC) / 1000
    if time_s > END_S:
        break
    index += 1
    if index % STRIDE:
        continue
    result = pose.process(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
    points = {}
    if result.pose_landmarks:
        for landmark_index in KEEP:
            landmark = result.pose_landmarks.landmark[landmark_index]
            points[str(landmark_index)] = [
                round(landmark.x, 6),
                round(landmark.y, 6),
                round(landmark.z, 6),
                round(landmark.visibility, 5),
            ]
    frames.append({"t_ms": round((time_s - START_S) * 1000), "points": points})

pose.close()
cap.release()
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text(json.dumps({
    "video_asset": "assets/debug/100pushup.mp4",
    "source_start_ms": round(START_S * 1000),
    "duration_ms": round((END_S - START_S) * 1000),
    "width": width,
    "height": height,
    "sample_fps": fps / STRIDE,
    "expected_reps": 5,
    "frames": frames,
}, separators=(",", ":")), encoding="utf-8")
print(f"Exported {len(frames)} frames to {OUTPUT}")
