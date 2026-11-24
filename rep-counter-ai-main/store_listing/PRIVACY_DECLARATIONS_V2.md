# v2 — Khai App Privacy (Apple) và Data safety (Google Play)

Checklist để chủ dự án điền trên App Store Connect và Play Console cho **build v2 có tài khoản** (staging: `ENABLE_ACCOUNTS / CLOUD_SYNC / AI_CREDITS / XP / SOCIAL / INBOX = true`, `BILLING / PUSH = false`). Store compliance S-3 (`docs/qa/STORE_COMPLIANCE_v2.md`). Nhãn trên console để nguyên tiếng Anh, giải thích bằng tiếng Việt.

Nguồn sự thật (đã đối chiếu code 2026-11-24): `supabase/migrations/*` (bảng), `supabase/functions/ai-request` (GroqCloud, không lưu hội thoại), `supabase/functions/delete-account` (bảng bị xóa), `lib/features/auth` (email/Apple/Google, token trong Keychain/Keystore), `backend/static/privacy-policy.html` (bản policy v2, hiệu lực 24/11/2026).

Nguyên tắc chung:
- **Không tracking**, không quảng cáo, không analytics, không crash SDK.
- Supabase, GroqCloud và máy chủ RepCoach là **bên xử lý thay mặt** (service provider), nên **không tính là "shared"** trên Play và không phải "third-party partner dùng cho mục đích riêng" trên Apple.
- Ảnh/video camera và landmark **không rời thiết bị**, nên không khai.
- Push token: bảng `push_tokens` có sẵn nhưng `ENABLE_PUSH=false`, nên build này **không thu thập**. Khi bật push phải khai lại.
- Thanh toán: `ENABLE_BILLING=false`, nên **không** khai Purchases. Khi bật P-1 phải khai lại.

---

## A. Apple — App Store Connect › App Privacy

Đường đi: App Store Connect › app › **App Privacy** › Data Collection › **Yes, we collect data from this app**.

### A.1 Tracking
- [ ] "Do you or your third-party partners use data for tracking?" → **No**.

### A.2 Data types (tick đúng các ô sau, bỏ trống mọi ô khác)

| ☐ | Category › Data type | Vì sao | Linked to user? | Used for tracking? | Purposes |
|---|---|---|---|---|---|
| [ ] | **Contact Info › Email Address** | Đăng ký/đăng nhập (Supabase Auth); Apple/Google chia sẻ email | **Yes** | No | App Functionality |
| [ ] | **Contact Info › Name** | Tên hiển thị trong Bạn bè; tên do Apple/Google chia sẻ khi đăng nhập | **Yes** | No | App Functionality |
| [ ] | **Health & Fitness › Fitness** | Buổi tập đồng bộ (rep, set, thời lượng, chi tiết rep, chất lượng); tóm tắt gửi nhận xét AI; số liệu tổng hợp cho AI Coach | **Yes** | No | App Functionality |
| [ ] | **User Content › Other User Content** | Tin nhắn AI Coach gửi tới ai-request/GroqCloud; lý do báo cáo (reports) | **Yes** | No | App Functionality |
| [ ] | **Identifiers › User ID** | ID tài khoản Supabase | **Yes** | No | App Functionality |
| [ ] | **Usage Data › Product Interaction** | Sổ tín dụng AI, sự kiện XP, thành tích, trạng thái bạn bè/lời mời | **Yes** | No | App Functionality |

Không tick: Health (HealthKit), Location, Sensitive Info, Contacts, Photos or Videos (ảnh story chỉ lưu vào Photos của người dùng, không gửi đi), Audio, Browsing/Search History, Purchases, Financial Info, Diagnostics, Device ID, Advertising Data, Other Data.

Ghi chú khi điền:
- [ ] Fitness: chọn **Linked = Yes** vì buổi tập đồng bộ gắn `user_id`. Nhận xét AI cho khách không gắn danh tính, nhưng Apple chỉ cho một câu trả lời cho mỗi loại, nên chọn mức chặt hơn.
- [ ] Other User Content: tin nhắn AI Coach không lưu trên máy chủ, nhưng GroqCloud có thể giữ tối đa 30 ngày để kiểm tra lạm dụng, và lý do báo cáo được lưu. Vì vậy khai là collected.
- [ ] Privacy Policy URL (App Information): `https://repcoach-ai.duckdns.org/privacy-policy.html`. Chỉ lưu **sau khi** đã đưa bản v2 lên web.

### A.3 Đồng bộ manifest (cần quyết, không chặn console)
- [ ] `ios/Runner/PrivacyInfo.xcprivacy` hiện chỉ khai `Fitness` (linked = false). Apple dùng manifest cho Privacy Report của archive. Nên cập nhật cho khớp bảng A.2 trước khi nộp App Review build có tài khoản. Việc này chưa làm trong PR này, chờ chủ dự án duyệt.
- [ ] Chạy Xcode › Product › Archive › **Generate Privacy Report** trên archive release; đối chiếu các SDK (google_sign_in_ios, sign_in_with_apple, supabase, sqflite, share_plus, url_launcher_ios, video_player, package_info_plus, flutter_local_notifications, ML Kit).

---

## B. Google Play — Play Console › App content › Data safety

Đường đi: Play Console › app › **Policy › App content › Data safety** › Manage.

### B.1 Data collection and security
- [ ] "Does your app collect or share any of the required user data types?" → **Yes**
- [ ] "Is all of the user data collected by your app encrypted in transit?" → **Yes** (HTTPS: Supabase, máy chủ RepCoach)
- [ ] "Which of the following methods of account creation does your app support?" → **Username and password** + **OAuth** (Sign in with Google; Sign in with Apple không có trên Android)
- [ ] **Delete account URL** → `https://repcoach-ai.duckdns.org/delete-account.html`
- [ ] "Do you provide a way for users to request that some or all of their data is deleted, without requiring them to delete their account?" → **Yes** (Cài đặt › Xóa lịch sử tập: trên máy / trong tài khoản / cả hai)
- [ ] Data deletion URL (nếu form hỏi riêng) → dùng chung `https://repcoach-ai.duckdns.org/delete-account.html`

### B.2 Data types (tick đúng các mục sau)

Với **mỗi** mục: Shared = **No** (chỉ service provider). Processed ephemerally = **No**, trừ khi ghi khác. Required or optional = **Optional** (người dùng có thể dùng app như khách).

| ☐ | Category › Data type | Collected | Ephemeral | Optional | Purposes |
|---|---|---|---|---|---|
| [ ] | **Personal info › Email address** | Yes | No | Optional | App functionality, Account management |
| [ ] | **Personal info › Name** | Yes | No | Optional | App functionality, Account management |
| [ ] | **Personal info › User IDs** | Yes | No | Optional | App functionality, Account management |
| [ ] | **Health and fitness › Fitness info** | Yes | No | Optional | App functionality, Personalization |
| [ ] | **Messages › Other in-app messages** | Yes | No | Optional | App functionality, Fraud prevention, security, and compliance |
| [ ] | **App activity › App interactions** | Yes | No | Optional | App functionality |

Ghi chú:
- [ ] Other in-app messages gồm tin nhắn AI Coach (gửi tới GroqCloud, không lưu trên server RepCoach) và lý do báo cáo (lưu, ẩn danh khi xóa tài khoản). Không chọn "ephemeral" vì GroqCloud có thể giữ tới 30 ngày và báo cáo được lưu.
- [ ] App interactions gồm sự kiện XP, thành tích, sổ tín dụng AI, trạng thái bạn bè/lời mời.
- [ ] **Không** tick: Location, Financial info, Health info (khác Fitness), Photos and videos, Audio, Files and docs, Calendar, Contacts, Web browsing, App info and performance (không crash log/diagnostics), Device or other IDs (push tắt).

### B.3 Các mục khác trong App content (rà lại vì có tài khoản và AI chat)
- [ ] **Privacy policy** → `https://repcoach-ai.duckdns.org/privacy-policy.html` (sau khi đưa bản v2 lên web).
- [ ] **App access** → "All or some functionality is restricted": cấp tài khoản demo email/password trên staging, kèm ghi chú: Google sign-in tùy chọn, khách vẫn tập được.
- [ ] **Health apps declaration** → xác nhận lại (thêm kế hoạch tập, AI Coach); giữ disclaimer "not a medical device".
- [ ] **Target audience** → 13+ (khớp câu "not directed to children under 13" trong policy).
- [ ] **Content rating** (IARC) → làm lại bảng câu hỏi: có **user interaction** (bạn bè, tên hiển thị, lời mời) và **AI chat**; không chia sẻ vị trí; không mua trong app.

---

## C. Trước khi bấm Submit
- [ ] Bản `privacy-policy.html`, `support.html` và `delete-account.html` mới đã lên `repcoach-ai.duckdns.org` và trả 200 (route mới `/delete-account.html` trong `backend/server.py` và nginx `location = /delete-account.html`).
- [ ] App Privacy (A) và Data safety (B) khớp với policy (cùng danh sách dữ liệu, cùng URL xóa).
- [ ] Hộp thư `ronganminh221@gmail.com` sẵn sàng nhận yêu cầu xóa. Xử lý: Supabase dashboard › Authentication › Users › tìm email › **Delete user**. Mọi bảng dữ liệu tham chiếu `auth.users` với `ON DELETE CASCADE` nên được dọn theo; `reports` (và `invites.used_by`) chuyển ID thành null. Cách này **không** thu hồi token Sign in with Apple; với tài khoản Apple, người dùng có thể gỡ RepCoach trong Apple ID › Sign in with Apple. Trả lời trong 30 ngày (cam kết trên trang web).
