# -*- coding: utf-8 -*-
"""So ban .aab cu va moi xem da co ban sua giao dien chua.

Chuoi Dart co dau tieng Viet duoc AOT luu dang UTF-16, khong phai UTF-8 — tim
bang UTF-8 khong thay la duong nhien, khong co nghia la thieu.
"""
import os
import zipfile

# Chuoi CHI xuat hien SAU cac ban sua. Viec bo khung chu nhat va an huong dan
# la thay doi LOGIC nen khong sinh chuoi moi — phai lay chuoi cua thay doi di
# kem trong cung dot commit lam moc.
TESTS = [
    ('sau a0c00d9  "Luu vao may"', 'Lưu vào máy'),
    ('sau a0c00d9  "Da luu:"', 'Đã lưu:'),
    ('sau a0c00d9  "Khong luu duoc file"', 'Không lưu được file ra bộ nhớ máy'),
    ('truoc do     "Gui video" (da bo)', 'Gửi video'),
]


def probe(path, label):
    if not os.path.exists(path):
        print('%s: khong ton tai' % label)
        return
    z = zipfile.ZipFile(path)
    data = b''
    for n in z.namelist():
        if n.endswith('libapp.so') and 'arm64-v8a' in n:
            data = z.read(n)
            break
    print()
    print('%s  (%.1f MB libapp)' % (label, len(data) / 1048576))
    for name, s in TESTS:
        found = (s.encode('utf-8') in data) or (s.encode('utf-16-le') in data)
        print('  %-48s %s' % (name, 'CO' if found else 'khong'))


import sys

TARGET = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    'rep_counter_app', 'build', 'app', 'outputs', 'bundle', 'storeRelease',
    'app-store-release.aab')
probe(TARGET, 'File sap nop')
