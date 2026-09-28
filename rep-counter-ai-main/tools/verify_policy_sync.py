# -*- coding: utf-8 -*-
"""Kiem tra tung cau tieng Anh trong app co xuat hien nguyen van tren web.

Neu mot chuoi khong khop, in ra de sua tay. Day la thu chan duoc loi "app noi
mot dang, trang chinh sach noi mot dang" ma Play rat de bat.
"""
import io
import re
import html

APP = r'c:\Users\THANH\Downloads\ta_don\rep_counter_app\lib\core\i18n\app_strings.dart'
WEB = {
    'priv': r'c:\Users\THANH\Downloads\ta_don\docs\privacy-policy.html',
    'terms': r'c:\Users\THANH\Downloads\ta_don\docs\terms.html',
}

src = io.open(APP, encoding='utf-8').read()
en = src[src.index('static const S en = S('):]
en = en[:en.index('\n  );')]

# Gom cac chuoi Dart nhieu dong ve mot dong.
pairs = re.findall(r"^    (\w+):\s*((?:'(?:[^'\\]|\\.)*'\s*)+),", en, re.M)


def unquote(blob):
    out = []
    for piece in re.findall(r"'((?:[^'\\]|\\.)*)'", blob):
        out.append(piece.replace("\\'", "'").replace('\\n', '\n'))
    return ''.join(out)


def normalise(t):
    t = html.unescape(re.sub(r'<[^>]+>', ' ', t))
    t = t.replace('\u2019', "'").replace('\u2014', '—')
    return re.sub(r'\s+', ' ', t).strip()


pages = {k: normalise(io.open(v, encoding='utf-8').read()) for k, v in WEB.items()}

# Chi kiem tra phan than van ban; tieu de tren web dung chu khac (vd "Camera and
# videos" vs "Camera and video") nen bo qua, khong phai sai lech noi dung.
BODIES = [k for k, _ in pairs
          if (k.startswith('priv') or k.startswith('terms')) and k.endswith('Body')]

# Hai doan nay lech CO CHU DICH: trang web ket thuc bang the <a> mailto, con
# trong app dia chi email nam o muc "Lien he" ngay ben duoi. Y nghia nhu nhau.
ALLOWED = {'privChangesBody', 'termsContactBody'}

bad = []
for key, blob in pairs:
    if key not in BODIES or key in ALLOWED:
        continue
    text = normalise(unquote(blob))
    page = pages['priv'] if key.startswith('priv') else pages['terms']
    if text not in page:
        bad.append((key, text))

print('da kiem tra %d doan (bo qua %d doan lech co chu dich)'
      % (len(BODIES) - len(ALLOWED), len(ALLOWED)))
if not bad:
    print('KHOP HET: moi cau tieng Anh trong app deu co nguyen van tren web')
else:
    print('LECH %d doan:' % len(bad))
    for key, text in bad:
        print('\n  [%s]\n  app: %s' % (key, text))
