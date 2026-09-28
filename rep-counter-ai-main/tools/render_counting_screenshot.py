# -*- coding: utf-8 -*-
"""Dung anh gioi thieu "dang dem rep" cho Google Play.

Nguoi that trong video la nguoi nhan dien duoc, quay trong phong tap toi va co
nguoi la phia sau — khong dung thang duoc cho anh cong khai. Nen:

  - TU THE va KHUNG XUONG lay tu MediaPipe chay tren khung hinh THAT, khong ve
    tay. Cai app hien ra dung la cai nay.
  - HINH NGUOI thay bang bong tach tu mat na phan doan cua MediaPipe, khong lo
    mat, khong lo phong tap.
  - GIAO DIEN ve lai dung mau va dung bo cuc lay tu ma nguon (AppTheme,
    placement.dart, camera_page.dart) va do lai theo anh chup that.

Day la anh dung cho cua hang, khong phai anh chup man hinh tho. Moi thu no the
hien deu la thu app lam duoc that.
"""
import math
import os
import cv2
import numpy as np
import mediapipe as mp
from PIL import Image, ImageDraw, ImageFont

VIDEO = r'c:\Users\THANH\Downloads\ta_don\push_up\video_20260811_203209.mp4'
FRAME = 975
import sys

OUT_DIR = r'c:\Users\THANH\Downloads\ta_don\store_listing\assets\screenshots'
LANGS = {
    'vi': dict(file='00-counting-vi.png', title='Hít đất',
               btn=['HIỆU CHỈNH', 'KẾT THÚC'],
               stats=['REP', 'SET NÀY', 'SET', 'TRẠNG THÁI'], state='TẬP',
               status='Sẵn sàng — bắt đầu đếm'),
    'en': dict(file='00-counting-en.png', title='Push-up',
               btn=['CALIBRATE', 'FINISH'],
               stats=['REPS', 'THIS SET', 'SETS', 'STATUS'], state='WORKING',
               status='Ready — counting'),
}
LANG = LANGS[sys.argv[1] if len(sys.argv) > 1 else 'vi']
OUT = os.path.join(OUT_DIR, LANG['file'])

W, H = 1080, 2460
DP = 2.625                      # mat do 420 tren LG V60
def dp(v): return int(round(v * DP))

# Mau lay thang tu ma nguon
INK        = (0x07, 0x13, 0x0D)     # AppTheme.ink
PANEL      = (0x10, 0x22, 0x19)
GREEN      = (0x61, 0xE7, 0x86)     # AppTheme.green
READY      = (0x22, 0xC5, 0x5E)     # PlacementStatus.ready
WHITE      = (0xFF, 0xFF, 0xFF)

FONT_DIR = os.path.expanduser(
    '~/development/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto')
ICONS = os.path.expanduser(
    '~/development/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf')

def font(name, size):
    return ImageFont.truetype(os.path.join(FONT_DIR, name), size)

def icon(size):
    return ImageFont.truetype(ICONS, size)

ARROW_BACK = chr(0xe092)
TUNE = chr(0xe683)
FLAG_CIRCLE = chr(0xf05fd)
FLAG = chr(0xf768)


# ---------------------------------------------------------------- pose that
# Chay o che do VIDEO chu khong phai anh tinh: static_image_mode bat tung khung
# roi rac, va dung tu the chong tay nay no khong bat duoc. Cho no bam dau qua
# vai chuc khung truoc do roi moi lay khung can.
cap = cv2.VideoCapture(VIDEO)
cap.set(cv2.CAP_PROP_POS_FRAMES, max(0, FRAME - 40))
pose = mp.solutions.pose.Pose(static_image_mode=False, model_complexity=2,
                              enable_segmentation=True)
res, bgr = None, None
for _ in range(41):
    ok, frame = cap.read()
    if not ok:
        break
    out = pose.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
    res, bgr = out, frame
cap.release()
pose.close()
if bgr is None:
    raise SystemExit('khong doc duoc khung hinh')
if not res.pose_landmarks or res.segmentation_mask is None:
    raise SystemExit('khong lay duoc pose hoac mat na')

vh, vw = bgr.shape[:2]
mask = res.segmentation_mask                      # 0..1

# Khung hinh 1080x1920, canvas 1080x2460 -> dat nguoi vao giua theo chieu doc
scale = W / vw
new_h = int(round(vh * scale))
mask_img = cv2.resize(mask, (W, new_h), interpolation=cv2.INTER_LINEAR)
# Day len mot chut: canh giua de lai mot dai trong lon giua thanh nut va dau.
top = (H - new_h) // 2 - 150

full = np.zeros((H, W), dtype=np.float32)
full[top:top + new_h] = mask_img
# Lam mem vien cho bot rang cua
full = cv2.GaussianBlur(full, (0, 0), 3)

def to_canvas(lm):
    """Toa do landmark chuan hoa -> pixel tren canvas."""
    return (lm.x * W, top + lm.y * new_h)


# ---------------------------------------------------------------- nen
img = Image.new('RGB', (W, H), INK)
d = ImageDraw.Draw(img, 'RGBA')

# Quang sang xanh phia sau nguoi cho co chieu sau
glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse([-W // 3, top + int(new_h * 0.10), W + W // 3, top + int(new_h * 0.95)],
           fill=(0x15, 0x3C, 0x24, 255))
glow = glow.filter(__import__('PIL.ImageFilter', fromlist=['x']).GaussianBlur(140))
img = Image.alpha_composite(img.convert('RGBA'), glow).convert('RGB')

# ---------------------------------------------------------------- bong nguoi
alpha = np.clip(full * 1.35, 0, 1)
body = np.zeros((H, W, 3), dtype=np.float32)
body[:] = np.array([0x30, 0x4E, 0x3C], dtype=np.float32)     # xam xanh nhat
base = np.asarray(img, dtype=np.float32)
blend = base * (1 - alpha[..., None]) + body * alpha[..., None]

# Vien sang: lay DUONG BAO cua mat na da nguong hoa, khong dung Canny.
# Canny chay tren mat na da lam mo sinh ra day net nguech ngoac ben trong hinh
# nguoi chu khong phai mot duong vien.
binary = (full > 0.5).astype(np.uint8)
contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
ring = np.zeros((H, W), dtype=np.uint8)
for c in contours:
    if cv2.contourArea(c) < 4000:
        continue
    cv2.drawContours(ring, [cv2.approxPolyDP(c, 2, True)], -1, 255, thickness=6)
edge = cv2.GaussianBlur(ring.astype(np.float32) / 255.0, (0, 0), 3)
edge = np.clip(edge * 1.6, 0, 1)
rim = np.array(GREEN, dtype=np.float32)
blend = blend * (1 - edge[..., None] * 0.9) + rim * edge[..., None] * 0.9

img = Image.fromarray(np.clip(blend, 0, 255).astype(np.uint8))
d = ImageDraw.Draw(img, 'RGBA')

# ---------------------------------------------------------------- khung xuong
L = mp.solutions.pose.PoseLandmark
SKELETON = [
    (L.LEFT_SHOULDER, L.RIGHT_SHOULDER), (L.LEFT_SHOULDER, L.LEFT_ELBOW),
    (L.LEFT_ELBOW, L.LEFT_WRIST), (L.RIGHT_SHOULDER, L.RIGHT_ELBOW),
    (L.RIGHT_ELBOW, L.RIGHT_WRIST), (L.LEFT_SHOULDER, L.LEFT_HIP),
    (L.RIGHT_SHOULDER, L.RIGHT_HIP), (L.LEFT_HIP, L.RIGHT_HIP),
    (L.LEFT_HIP, L.LEFT_KNEE), (L.LEFT_KNEE, L.LEFT_ANKLE),
    (L.RIGHT_HIP, L.RIGHT_KNEE), (L.RIGHT_KNEE, L.RIGHT_ANKLE),
]
m = res.pose_landmarks.landmark
for a, b in SKELETON:
    la, lb = m[a.value], m[b.value]
    if la.visibility < 0.4 or lb.visibility < 0.4:
        continue
    d.line([to_canvas(la), to_canvas(lb)], fill=WHITE + (235,), width=dp(4))

JOINTS = [L.LEFT_SHOULDER, L.RIGHT_SHOULDER, L.LEFT_ELBOW, L.RIGHT_ELBOW,
          L.LEFT_WRIST, L.RIGHT_WRIST, L.LEFT_HIP, L.RIGHT_HIP]
r = dp(6)
for t in JOINTS:
    lm = m[t.value]
    if lm.visibility < 0.4:
        continue
    x, y = to_canvas(lm)
    d.ellipse([x - r, y - r, x + r, y + r], fill=READY + (255,))

# ---------------------------------------------------------------- giao dien
pad = dp(16)
top_y = dp(38)          # duoi thanh trang thai

f_title = font('Roboto-Bold.ttf', dp(18))
f_label = font('Roboto-Bold.ttf', dp(9))
f_stat_l = font('Roboto-Regular.ttf', dp(10))
f_num_big = font('Roboto-Black.ttf', dp(34))
f_num = font('Roboto-Black.ttf', dp(26))
f_state = font('Roboto-Black.ttf', dp(20))
f_status = font('Roboto-Bold.ttf', dp(16))
f_goal = font('Roboto-Bold.ttf', dp(14))

# Nut quay lai + tieu de
d.text((pad + dp(12), top_y + dp(10)), ARROW_BACK, font=icon(dp(24)), fill=WHITE)
d.text((pad + dp(48), top_y + dp(8)), LANG['title'], font=f_title, fill=WHITE)

# Thanh nut: ban store CHI co hai nut (GHI VIDEO chi co o ban diag)
items = list(zip([TUNE, FLAG_CIRCLE], LANG['btn']))
cell_w = dp(96)
pill_w = cell_w * len(items)
pill_h = dp(58)
pill_x = W - pad - pill_w
pill_y = top_y + dp(52)
d.rounded_rectangle([pill_x, pill_y, pill_x + pill_w, pill_y + pill_h],
                    radius=dp(16), fill=(0, 0, 0, 140))
fi = icon(dp(24))
for i, (gl, text) in enumerate(items):
    cx = pill_x + cell_w * i + cell_w // 2
    d.text((cx, pill_y + dp(6)), gl, font=fi, fill=WHITE, anchor='ma')
    d.text((cx, pill_y + dp(34)), text, font=f_label, fill=WHITE, anchor='ma')

# Thanh tien do muc tieu
gp_h = dp(44)
gp_y = H - dp(210) - gp_h
d.rounded_rectangle([pad, gp_y, W - pad, gp_y + gp_h], radius=dp(14),
                    fill=(0, 0, 0, 148))
d.text((pad + dp(14), gp_y + gp_h // 2), FLAG, font=icon(dp(20)),
       fill=(0x69, 0xF0, 0xAE), anchor='lm')
bar_x0, bar_x1 = pad + dp(44), W - pad - dp(70)
bar_y = gp_y + gp_h // 2
bh = dp(9)
d.rounded_rectangle([bar_x0, bar_y - bh // 2, bar_x1, bar_y + bh // 2],
                    radius=bh // 2, fill=(0x2A, 0x4A, 0x39, 255))
REPS, TARGET = 12, 20
d.rounded_rectangle([bar_x0, bar_y - bh // 2,
                     bar_x0 + int((bar_x1 - bar_x0) * REPS / TARGET), bar_y + bh // 2],
                    radius=bh // 2, fill=GREEN + (255,))
d.text((W - pad - dp(14), bar_y), '%d/%d' % (REPS, TARGET), font=f_goal,
       fill=WHITE, anchor='rm')

# The so lieu
stats = list(zip(LANG['stats'], [str(REPS), '12', '1', LANG['state']],
                 [f_num_big, f_num, f_num, f_state]))
sc_h = dp(84)
sc_y = gp_y + gp_h + dp(10)
widths = [max(d.textlength(lb, font=f_stat_l), d.textlength(v, font=f)) for lb, v, f in stats]
sc_w = int(sum(widths) + dp(22) * (len(stats) - 1) + dp(36))
d.rounded_rectangle([pad, sc_y, pad + sc_w, sc_y + sc_h], radius=dp(16),
                    fill=(0, 0, 0, 140), outline=READY + (255,), width=dp(2))
x = pad + dp(18)
for (lb, v, f), w in zip(stats, widths):
    d.text((x, sc_y + dp(12)), lb, font=f_stat_l, fill=(0xFF, 0xFF, 0xFF, 150))
    d.text((x, sc_y + dp(30)), v, font=f, fill=WHITE)
    x += w + dp(22)

# Chu trang thai
d.text((pad, sc_y + sc_h + dp(14)), LANG['status'], font=f_status, fill=READY)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT)
print('da dung:', OUT, img.size)
