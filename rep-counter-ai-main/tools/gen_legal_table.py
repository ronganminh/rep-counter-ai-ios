# -*- coding: utf-8 -*-
"""Sinh lai rep_counter_app/docs/LEGAL_VI_EN.md tu app_strings.dart.

Bang doi chieu VI/EN phai lay thang tu nguon, khong chep tay. Chep tay thi
sau vai lan sua van ban la bang doi chieu noi mot dang, app noi mot dang —
dung thu ma nguoi duyet doc de tin.

Chay:  python tools/gen_legal_table.py
"""
import io
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, 'rep_counter_app', 'lib', 'core', 'i18n', 'app_strings.dart')
OUT = os.path.join(ROOT, 'rep_counter_app', 'docs', 'LEGAL_VI_EN.md')

# Thu tu hien tren man hinh, kem nhan de nguoi doc biet dang xem muc nao.
PRIVACY = [
    ('privacyPolicy', 'tiêu đề trang'),
    ('legalEffective', 'nhãn ngày hiệu lực'),
    ('legalDate', 'ngày hiệu lực'),
    ('privacyIntroBody', 'mở đầu (đứng sau tên app)'),
    ('privCameraTitle', ''), ('privCameraBody', ''),
    ('privWorkoutTitle', ''), ('privWorkoutBody', ''),
    ('privAiTitle', ''), ('privAiBody', ''),
    ('privRetentionTitle', ''), ('privRetentionBody', ''),
    ('privSecurityTitle', ''), ('privSecurityBody', ''),
    ('privChildrenTitle', ''), ('privChildrenBody', ''),
    ('privChoicesTitle', ''), ('privChoicesBody', ''),
    ('privChangesTitle', ''), ('privChangesBody', ''),
    ('privContactTitle', 'phía dưới là tên nhà phát triển và email'),
]

TERMS = [
    ('termsOfUse', 'tiêu đề trang'),
    ('legalEffective', 'nhãn ngày hiệu lực'),
    ('legalDate', 'ngày hiệu lực'),
    ('termsIntroPrefix', 'mở đầu, ghép: tiền tố + tên app + hậu tố'),
    ('termsIntroSuffix', ''),
    ('termsPurposeTitle', ''), ('termsPurposeBody', ''),
    ('termsNotMedicalTitle', ''), ('termsNotMedicalBody', ''),
    ('termsSafetyTitle', ''), ('termsSafetyBody', ''),
    ('termsLiabilityTitle', ''), ('termsLiabilityBody', ''),
    ('termsUseTitle', ''), ('termsUseBody', ''),
    ('termsChangesTitle', ''), ('termsChangesBody', ''),
    ('termsContactTitle', ''),
    ('termsContactBody', 'phía dưới là email'),
]


def block(src, name):
    start = src.index('static const S %s = S(' % name)
    return src[start:src.index('\n  );', start)]


def strings(chunk):
    out = {}
    for key, blob in re.findall(r"^    (\w+):\s*((?:'(?:[^'\\]|\\.)*'\s*)+|[\w.]+),",
                                chunk, re.M):
        if blob.startswith("'"):
            value = ''.join(
                piece.replace("\\'", "'").replace('\\n', ' ')
                for piece in re.findall(r"'((?:[^'\\]|\\.)*)'", blob))
        else:
            value = '(%s)' % blob  # vd LegalConfig.effectiveDateEn
        out[key] = value
    return out


def table(vi, en, rows):
    lines = ['| Khoá | Tiếng Việt | English |', '|---|---|---|']
    for key, note in rows:
        label = '`%s`' % key + (' — *%s*' % note if note else '')
        lines.append('| %s | %s | %s |'
                     % (label, vi[key].replace('|', r'\|'),
                        en[key].replace('|', r'\|')))
    return '\n'.join(lines)


src = io.open(APP, encoding='utf-8').read()
vi = strings(block(src, 'vi'))
en = strings(block(src, 'en'))

# Hai hang so ngay thang lay thang tu LegalConfig.
cfg = io.open(os.path.join(ROOT, 'rep_counter_app', 'lib', 'core', 'legal',
                           'legal_config.dart'), encoding='utf-8').read()
for key, const in (('vi', 'effectiveDate'), ('en', 'effectiveDateEn')):
    value = re.search(r"%s = '([^']*)'" % const, cfg).group(1)
    (vi if key == 'vi' else en)['legalDate'] = value

doc = """# Đối chiếu văn bản pháp lý VI ↔ EN

> **File này được sinh tự động.** Đừng sửa tay — sửa
> [`lib/core/i18n/app_strings.dart`](../lib/core/i18n/app_strings.dart) rồi chạy
> `python tools/gen_legal_table.py`.

Nguồn duy nhất của các chuỗi này là `app_strings.dart` (`S.vi` và `S.en`);
[`lib/features/legal/legal_page.dart`](../lib/features/legal/legal_page.dart)
chỉ ghép chúng lại.

Bản tiếng Anh trong app phải khớp **từng câu** với trang web tại
`https://repcoach-ai.duckdns.org/`. Kiểm tra bằng
`python tools/verify_policy_sync.py`. Trang web chỉ có tiếng Anh — đó là chủ ý.

## Cách nhờ AI khác kiểm tra

Bản dịch cố ý bám sát từng ý của bản tiếng Việt, không viết lại cho mượt, để so
từng dòng cho dễ. Khi nhờ ChatGPT/Gemini duyệt, hỏi đúng ba câu:

1. Bản tiếng Anh có nói **thừa** điều gì mà bản tiếng Việt không nói không?
   (Nguy hiểm nhất: hứa hẹn về bảo mật/quyền riêng tư mạnh hơn thực tế.)
2. Có nói **thiếu** ý nào so với bản tiếng Việt không?
3. Câu nào nghe như **cam kết pháp lý** chặt hơn ý định ban đầu?

Đừng hỏi "dịch có hay không" — văn bản pháp lý cần đúng, không cần hay.

---

## Chính sách quyền riêng tư / Privacy policy

%s

## Điều khoản sử dụng / Terms of use

%s

---

## Những chỗ cố ý dịch không sát chữ

1. **Ngày hiệu lực.** Bản tiếng Việt là `%s` (DD/MM/YYYY); người đọc tiếng Anh
   sẽ hiểu thành ngày 9 tháng 5. Bản tiếng Anh dùng hằng số riêng
   `LegalConfig.effectiveDateEn` = `%s`. **Đổi ngày phải đổi cả hai hằng số.**

2. **"máy chủ do nhà phát triển vận hành"** → *"the server operated by the
   developer"*, không phải *"the developer's server"*. Nghĩa như nhau; tránh
   dấu nháy đơn phải escape trong chuỗi Dart.

3. **`privChangesBody` và `termsContactBody`** kết thúc bằng "địa chỉ dưới
   đây" / "the address below", còn trang web kết thúc bằng thẻ `<a>` mailto.
   `verify_policy_sync.py` bỏ qua hai đoạn này có chủ đích.
""" % (table(vi, en, PRIVACY), table(vi, en, TERMS),
       vi['legalDate'], en['legalDate'])

io.open(OUT, 'w', encoding='utf-8', newline='\n').write(doc)
print('da sinh %s (%d dong)' % (os.path.relpath(OUT, ROOT), doc.count('\n') + 1))
