"""Proxy Gemini tối giản: giữ API key ngoài APK, không nhận video/ảnh."""
from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def load_env() -> None:
    path = Path(__file__).with_name(".env")
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


load_env()


class Handler(BaseHTTPRequestHandler):
    def reply(self, status: int, data: dict) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path != "/health":
            self.reply(404, {"error": "not_found"})
            return
        self.reply(200, {"ok": True, "service": "repcoach-ai"})

    def do_POST(self) -> None:
        if self.path != "/v1/workout-feedback":
            self.reply(404, {"error": "not_found"})
            return
        key = os.getenv("GEMINI_API_KEY", "").strip()
        if not key:
            self.reply(503, {"error": "GEMINI_API_KEY is missing"})
            return
        try:
            declared_length = int(self.headers.get("content-length", "0"))
            if declared_length <= 0 or declared_length > 16_384:
                self.reply(413, {"error": "invalid_request_size"})
                return
            length = declared_length
            workout = json.loads(self.rfile.read(length))
            # Danh sach trang: chi nhung khoa nay duoc di vao prompt. Client
            # khong the tiem them truong hay chi thi (§9.3).
            # Bo qua khoa vang mat thay vi gan None, de prompt khong chua
            # "avg_amplitude": null va model khoi doan mo.
            keys = (
                "schema_version", "exercise", "duration_seconds", "reps",
                "sets", "target_reps", "goal_reached", "placement_score",
                "pose_frames", "pose_lost_frames",
                # So lieu chat luong (co khi app da nang cap domain buoi tap)
                "flagged_reps", "avg_rep_sec", "avg_amplitude",
                "amplitude_drop_percent", "left_right_diff_percent",
                "quality_score", "has_enough_data",
            )
            allowed = {k: workout[k] for k in keys if k in workout}
            locale = workout.get("locale", "vi")
            if locale not in ("vi", "en"):
                locale = "vi"
            # Viet HAN chi dan bang chinh ngon ngu can tra loi. Neu chi dan bang
            # tieng Viet roi bao "tra loi bang English" thi model van co xu huong
            # bam theo ngon ngu cua chi dan -- da thu va no tra ve tieng Viet.
            PROMPTS = {
                "vi": (
                    "Bạn là HLV thể hình thân thiện. Nhận xét buổi hít đất bằng TIẾNG VIỆT, "
                    "2-4 câu, ngắn gọn và có một lời khuyên an toàn, khả thi cho buổi sau. "
                    "Không chẩn đoán y khoa, không khẳng định kỹ thuật hoàn hảo chỉ từ thống kê. "
                    "Chỉ dùng số liệu được cung cấp, không suy đoán lại số rep hay điểm số. "
                    "Nếu has_enough_data là false hoặc thiếu số liệu chất lượng, nói rõ chưa đủ "
                    "dữ liệu để đánh giá kỹ thuật thay vì đoán. "
                    "Nếu pose_lost_frames chiếm tỉ lệ lớn so với pose_frames, ưu tiên khuyên "
                    "chỉnh góc đặt camera thay vì phê bình kỹ thuật.\n"
                ),
                "en": (
                    "You are a friendly strength coach. Comment on this push-up session "
                    "in ENGLISH ONLY, 2-4 short sentences, ending with one safe, actionable "
                    "tip for next time. Do not diagnose or give medical advice, and do not "
                    "claim the form is perfect based on statistics alone. "
                    "Use only the numbers provided; never recompute or guess rep counts or "
                    "scores. If has_enough_data is false or quality numbers are missing, say "
                    "plainly that there is not enough data to judge technique. If "
                    "pose_lost_frames is a large share of pose_frames, prioritise advice about "
                    "camera placement over criticising technique.\n"
                ),
            }
            prompt = PROMPTS[locale] + json.dumps(allowed, ensure_ascii=False)
            model = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite")
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
            payload = {"contents": [{"parts": [{"text": prompt}]}], "generationConfig": {"temperature": 0.4, "maxOutputTokens": 220}}
            req = Request(url, data=json.dumps(payload).encode(), method="POST",
                          headers={"content-type": "application/json", "x-goog-api-key": key})
            with urlopen(req, timeout=20) as response:
                result = json.load(response)
            feedback = result["candidates"][0]["content"]["parts"][0]["text"].strip()
            self.reply(200, {"feedback": feedback})
        except (ValueError, KeyError) as error:
            self.reply(400, {"error": str(error)})
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")[:500]
            self.reply(502, {"error": "gemini_error", "detail": detail})
        except Exception as error:
            self.reply(502, {"error": type(error).__name__})

    def log_message(self, fmt: str, *args: object) -> None:
        print(f"[backend] {fmt % args}")


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8787"))
    host = os.getenv("BIND_HOST", "127.0.0.1")
    print(f"Workout AI backend: http://{host}:{port}")
    ThreadingHTTPServer((host, port), Handler).serve_forever()
