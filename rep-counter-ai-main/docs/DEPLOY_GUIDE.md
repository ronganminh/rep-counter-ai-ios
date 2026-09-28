# Đưa trang web pháp lý lên VPS

Thư mục `docs/` là **nguồn** của trang web. Sửa ở đây rồi đẩy lên VPS, đừng sửa
trực tiếp trên máy chủ — lần đẩy sau sẽ ghi đè mất.

## Thông tin

| Mục | Giá trị |
|---|---|
| Tên miền | `repcoach-ai.duckdns.org` |
| Máy chủ | 14.225.207.90 (nginx + Let's Encrypt) |
| Thư mục web | `/var/www/repcoach-ai` |
| Cấu hình nginx | `/etc/nginx/sites-available/repcoach-ai` |

Cùng một khối `server` phục vụ cả API (`/health`, `/v1/workout-feedback`) lẫn
trang tĩnh. Hai đường dẫn API dùng `location =` (khớp chính xác) nên luôn được
ưu tiên hơn `location /` của trang tĩnh — thêm file tĩnh không ảnh hưởng API.

## Đẩy bản mới lên

Từ thư mục gốc của repo:

```bash
scp -r docs/index.html docs/privacy-policy.html docs/terms.html \
       docs/support.html docs/styles.css docs/assets \
       nduythanh@14.225.207.90:/tmp/repcoach-web/
ssh nduythanh@14.225.207.90 \
    'sudo rsync -a --delete /tmp/repcoach-web/ /var/www/repcoach-ai/ && \
     sudo chown -R www-data:www-data /var/www/repcoach-ai'
```

Đừng đẩy `DEPLOY_GUIDE.md`, `PLAY_STORE_CHECKLIST.md` hay `.nojekyll` — chúng
là tài liệu nội bộ, không phải nội dung trang web.

Ảnh, CSS và font được nginx cho cache 7 ngày qua một khối `location ~*` riêng.
HTML thì vẫn `no-store` ở mức server, để Google và người dùng luôn đọc được bản
chính sách mới nhất.

`docs/assets/app-icon.png` là bản **512px, 32 KB** dành riêng cho web. Bản gốc
1024px nằm ở `rep_counter_app/assets/branding/app-icon-1024.png` và chỉ dùng để
`flutter_launcher_icons` sinh icon Android — đừng thay bản web bằng bản gốc, nó
nặng gấp 44 lần.

## Kiểm tra sau khi đẩy

```bash
# Phải trả về 200 VÀ đúng nội dung, không phải màn chặn bot nào.
curl -sI https://repcoach-ai.duckdns.org/privacy-policy.html | head -1
curl -s  https://repcoach-ai.duckdns.org/privacy-policy.html | grep -c '<h2>'

# API vẫn phải sống.
curl -s https://repcoach-ai.duckdns.org/health
```

`curl` **không chạy JavaScript**. Nếu nó thấy đúng nội dung thì trình thu thập
của Google cũng thấy. Đây chính là lý do rời khỏi host miễn phí InfinityFree:
host đó trả HTTP 200 nhưng thân trang là đoạn JS đố AES, trình duyệt vượt qua
được còn trình thu thập thì không, dễ khiến Play từ chối vì *"privacy policy
URL không truy cập được"*.

## Trang tải bản thử (`/test.html`)

`docs/test.html` cho người test tự tải APK. Trang này **cố ý không có trong
thanh điều hướng** và đặt `noindex` — nó không phải một phần của website chính
thức mà Google Play xem xét, chỉ ai có link mới vào được.

APK **không nằm trong repo** (`.gitignore` chặn `*.apk`). Đẩy thẳng từ thư mục
build lên máy chủ:

```bash
scp build/app/outputs/flutter-apk/app-*-release.apk     nduythanh@14.225.207.90:/tmp/
ssh nduythanh@14.225.207.90     'sudo cp /tmp/app-*-release.apk /var/www/repcoach-ai/apk/ &&      sudo chown www-data:www-data /var/www/repcoach-ai/apk/*'
```

Đổi bản mới thì nhớ sửa **tên file, cỡ file và mã SHA-256** trong biến `FILES`
ở cuối `test.html`, nếu không người tải sẽ kiểm tra ra sai.

Nginx phục vụ thư mục này qua khối `location /apk/` riêng: đặt đúng kiểu MIME
`application/vnd.android.package-archive` (mime.types của nginx không có
`.apk`), cho cache 1 giờ thay vì `no-store`, và tắt `autoindex` để không ai
liệt kê được thư mục.

**Trước khi phát hành lên Play, xoá thư mục `/apk/` và `test.html`.** Không nên
để bản sideload tồn tại song song với bản trên Store — người dùng cài bản cũ
rồi báo lỗi đã sửa từ lâu.

## Địa chỉ dùng cho Google Play Console

```
Website:          https://repcoach-ai.duckdns.org/
Privacy policy:   https://repcoach-ai.duckdns.org/privacy-policy.html
Terms of use:     https://repcoach-ai.duckdns.org/terms.html
Support:          https://repcoach-ai.duckdns.org/support.html
```

Bốn địa chỉ này phải khớp với `LegalConfig.privacyPolicyUrl` trong
[`rep_counter_app/lib/core/legal/legal_config.dart`](../rep_counter_app/lib/core/legal/legal_config.dart)
và với các file trong `store_listing/`.

## Nội dung trong app và trên web phải khớp

Play đối chiếu hai bản này. Trang web **chỉ có tiếng Anh**, và phải khớp từng
câu với `S.en` trong
[`app_strings.dart`](../rep_counter_app/lib/core/i18n/app_strings.dart).

Sau mỗi lần sửa văn bản pháp lý, chạy:

```bash
python tools/verify_policy_sync.py
```

Nó lấy từng đoạn thân văn bản tiếng Anh trong app rồi kiểm tra có xuất hiện
nguyên văn trên trang web không. Lệch chỗ nào nó in ra chỗ đó.

Bản tiếng Việt trong app không có trang web tương ứng — đó là chủ ý, không
phải thiếu sót.

## Gia hạn chứng chỉ

Chứng chỉ do certbot cấp và tự gia hạn. Kiểm tra:

```bash
ssh nduythanh@14.225.207.90 'sudo certbot certificates && systemctl status certbot.timer --no-pager'
```
