# RepCoach AI v2 — Checklist máy thật (TestFlight / Play internal)

Dành cho chủ dự án. Build staging theo `dart_defines.staging.example.json` (accounts, sync, credits, XP, social, inbox **bật**; billing, push **tắt**) trừ khi ghi khác. Mỗi dòng: tick ✅/❌, ghi máy + OS + build. Nguồn: 05_SUPABASE_SETUP §11 (D1–D18), STORE_COMPLIANCE_v2 (S-*), QA_REPORT_v2 (luồng chưa test được trong cloud).

Ký hiệu máy: **iP** = iPhone, **An** = Android, **cả** = cả hai. Mục có `★` là điều kiện nộp store.

## 0. Trước khi bắt đầu
- [ ] Ghi version/build hiển thị ở Settings › About khớp TestFlight/Play (`2.0.0 (8)`?) — cả
- [ ] Cài **mới hoàn toàn** (xoá app cũ) trên ít nhất 1 iPhone và 1 Android 13+ — cả
- [ ] Một máy Android 11/12 (không có quyền POST_NOTIFICATIONS runtime) nếu có — An

## 1. Quyền camera — App Store 5.1.1(iv) ★ (L-D24/L-D38; so với build 8 đã nộp)
- [ ] ★ Mở app lần đầu: **không** có prompt nào (camera/thông báo/ảnh) ở màn onboarding/Home — cả
- [ ] ★ Home › Train › Start: màn giải thích có **một** nút "Continue/Tiếp tục", không có X, không "Not now", không "Track manually"; chữ "Allow/Cho phép" không xuất hiện — cả
- [ ] ★ iP: vuốt back cạnh màn không thoát được màn giải thích (chỉ Continue) — iP
- [ ] An: nút Back hệ thống trên màn giải thích: ghi lại hành vi (hiện tại: không thoát) — An
- [ ] ★ Continue → prompt OS hiện ngay; bấm **Don't Allow / Không cho phép** → về màn trước (Home), **không** có màn "denied", không mở Settings, không snackbar — cả
- [ ] ★ Mở Start lần 2 (iP: quyền đã tắt): chỉ 1 câu "Camera access is off for RepCoach…" + 2 nút bằng nhau Back / Open Settings; không icon/tiêu đề/bước hướng dẫn/Retry — iP
- [ ] An 13+: lần 2 → giải thích lại → prompt → Deny lần 2 → về Home; lần 3 → thông báo trung tính (permanently denied) — An
- [ ] ★ Open Settings mở đúng trang app; bật camera; quay lại app → camera mở **không hỏi lại** — cả
- [ ] Back trên thông báo trung tính → về Home, không có gì khác — cả
- [ ] Allow trong prompt → camera mở, HUD hiện; tắt quyền trong Settings khi app đang nền → quay lại: thông báo trung tính (không crash) — cả
- [ ] iOS "restricted" (Screen Time chặn camera) nếu có thể: thông báo trung tính — iP

## 2. Quyền thông báo (nhắc lịch) ★
- [ ] Home › Kế hoạch › tạo plan › menu ⋮ › Workout reminders: màn giải thích chỉ có Continue, không back — cả
- [ ] ★ Continue → prompt OS → Don't Allow → về màn Plan; reminders vẫn OFF; không mở Settings — cả
- [ ] Mở lại Reminders: thông báo trung tính Back / Open Settings — cả
- [ ] Allow → bật nhắc; đặt giờ 2 phút tới (ngoài quiet hours) → thông báo đến đúng giờ; chạm → mở đúng buổi (deep link) — cả
- [ ] Hoàn thành buổi hôm nay → nhắc của buổi đó bị huỷ — cả
- [ ] Reboot máy → nhắc còn (RECEIVE_BOOT_COMPLETED) — An

## 3. Quyền Photos (lưu ảnh chia sẻ) ★ — QA-01, phải sửa trước khi nộp iOS
- [ ] Kết quả › Share › Save image → prompt "Add to Photos" → Don't Allow → **ghi lại** thông báo hiện ra (hiện tại là snackbar "Photo access was denied. Allow… in device Settings and retry" — vi phạm mẫu Apple đã từ chối) — iP
- [ ] Sau khi sửa: Don't Allow → không có lời nhắc đi Settings; lần sau bấm Save khi quyền tắt → thông báo trung tính — iP
- [ ] Share qua share sheet không cần quyền — cả

## 4. Tập luyện (engine thật)
- [ ] Push-up tự do: đặt máy, calibrate, 10+ rep thật: HUD đếm đúng, không giảm sau khi nghỉ; kết quả = HUD = History — cả
- [ ] Target reps + Timed challenge: kết thúc đúng, kết quả lưu — cả
- [ ] Pause/Resume; hold-to-finish; discard có xác nhận — cả
- [ ] Nền/khoá máy giữa buổi → quay lại tiếp tục; không double-save — cả
- [ ] **Kill app giữa buổi** → mở lại: màn khôi phục (Resume / Save partial / Discard); Resume giữ số rep; Save partial ghi 1 bản ghi "Partial" — cả
- [ ] Xoay máy: iP khoá dọc; An ghi lại hành vi khi xoay ngang trong HUD (QA-08) — cả
- [ ] Voice/haptic/âm set theo Settings; nhạc nền của người dùng không bị dừng bởi clip demo — cả
- [ ] Ghi tay (Manual log) từ plan session và từ "Track manually" khi camera lỗi → History ghi "Manual" — cả
- [ ] Guided timer: +10 s, pause, skip rest, done early; màn hình không tắt khi "Keep screen on" — cả
- [ ] Hướng dẫn động tác: clip pull-up/curl (diag/ENABLE_PULL_UP) lặp, tắt tiếng; Reduce Motion bật → poster + nút play, không autoplay — cả

## 5. Kế hoạch PL-1, overload, lịch sử
- [ ] Tạo plan 3 ngày; Home card tóm tắt; Train sheet hiện buổi hôm nay/recovery day — cả
- [ ] Move/Skip buổi; ngày đã có buổi bị từ chối; recovery day hỏi xác nhận — cả
- [ ] Overload: bật, hoàn thành 2 buổi đủ target → gợi ý +10 %; Accept chỉ đổi buổi tương lai — cả
- [ ] Lịch sử 7 ngày / 30 ngày / tất cả; xoá 1 buổi có Undo 5 s — cả
- [ ] Về Home sau khi đóng màn mở từ card Kế hoạch: không có lỗi đỏ trong **debug build** (QA-07) — cả

## 6. Tài khoản (D1–D11, staging)
- [ ] D1 Tạo tài khoản email (mật khẩu ≥ 10, tick Terms) → "Confirm your email" — cả
- [ ] D2 Mở link email → app mở → "Email confirmed" — cả
- [ ] D3 Sai mật khẩu → lỗi rõ; đúng → vào — cả
- [ ] D4 Quên mật khẩu → link → đặt mới → "Password updated" — cả
- [ ] D5 ★ Continue with Google (iP): vào; cancel sheet → "Sign-in cancelled" — iP
- [ ] D6 Continue with Google (An bản release/Play) — An
- [ ] D7 ★ Continue with Apple (+ Hide My Email); cancel không đổi gì; nút Apple **không nhỏ hơn và nằm trên** Google (4.8) — iP
- [ ] D8 Thu hồi session trong dashboard → banner "session expired"; tập vẫn được — cả
- [ ] D9/D18 ★ Profile › Delete account › gõ DELETE/XÓA → màn "being deleted"; dashboard: user + rows (workouts, ledger, xp, inbox, friendships, invites) biến mất; `reports` còn với reporter null — cả
- [ ] ★ Xoá tài khoản khi **offline** → "We couldn't start the deletion", vẫn đăng nhập — cả
- [ ] D10 Airplane mode: tập/lịch sử OK; sign-in "Can't connect" — cả
- [ ] D11 Build **không** `ENABLE_ACCOUNTS`: không có UI tài khoản; Profile "On this phone only" — cả

## 7. Đồng bộ / credits / XP / bạn bè / inbox (D12–D17)
- [ ] D12 2 workout + 1 offline + force-quit → không mất; badge "Offline · 1 waiting" → "Synced" — cả
- [ ] D13 Thu hồi session khi đang tập → banner; lịch sử nguyên — cả
- [ ] D14a–f Hai máy: pull, tombstone, merge guest→account (chỉ bản mới), xung đột "differs", xoá theo phạm vi (phone/account/both; offline → không xoá gì), plan trên 2 máy — 2 máy
- [ ] D15a–f Credits: 10 Free; hỏi Coach → 9; offline → "didn't send" + Retry, không trừ 2 lần; hết credits → thông báo, **không paywall**; feedback sau buổi tập vẫn miễn phí — cả
- [ ] Coach consent hiện **trước** lần gửi đầu tiên; nêu GroqCloud — cả
- [ ] D16a–e XP: +30 camera 20 rep; manual +15; xoá buổi không trừ XP; offline giữ level; guest không có — cả
- [ ] D17a–j Bạn bè: display name; invite link/code; leaderboard chỉ rep camera; Report (+block) → "Report sent", người kia không được báo; code dùng 2 lần/hết hạn/của mình; signed out → gate; offline → "Couldn't load" + Retry; inbox 2 item, đọc, không mở link khi đang tập — 2 máy

## 8. Cài đặt, giới thiệu, pháp lý ★
- [ ] Settings › Privacy policy: nội dung **đã cập nhật v2** (tài khoản, Supabase, đồng bộ, bạn bè, AI Coach, xoá tài khoản; không còn "100 records") và trùng với bản web — cả (QA-02)
- [ ] Link web Privacy/Terms/Support/Website mở được từ app; trang web có mục **xoá tài khoản** (QA-03) — cả
- [ ] Help & support, Send feedback (mail app), Rate app (iP ẩn khi chưa có APP_STORE_ID) — cả
- [ ] Demo videos credit (CC0) mở link; Health notice; version đúng — cả
- [ ] Xoá lịch sử cục bộ: gõ DELETE (EN) / XÓA (VI), không phân biệt hoa thường — cả
- [ ] Automatic AI: bật → dialog consent → Not now giữ OFF; Agree → ON; tắt không cần dialog — cả
- [ ] Export CSV/JSON tạo file và share — cả

## 9. Deep link `repcoach://` (owner đã đăng ký scheme?)
- [ ] An: `adb shell am start -a android.intent.action.VIEW -d "repcoach://inbox"` khi app đang chạy / đã tắt — An
- [ ] iP: mở `repcoach://plan/session/<id>` từ Notes → mở buổi; link cũ → thông báo "no longer in your plan" — iP
- [ ] Link đến khi đang tập → **không** mở đè HUD; mở sau khi về shell — cả
- [ ] `repcoach://friends/requests` khi chưa đăng nhập → gate tài khoản; `repcoach://membership` → Profile (ghi nhận: không có thông báo gì, QA-15) — cả

## 10. Ngôn ngữ, chữ lớn, trợ năng, giao diện
- [ ] Cài mới mở **tiếng Anh**; Settings › Language → VI, mở lại app vẫn VI — cả
- [ ] Quét EN/VI: chuỗi chưa dịch (tìm chữ Việt khi đang EN và ngược lại) ở: onboarding, Home, Train sheet, camera gate, HUD, kết quả, History, Plan, Reminders, Profile, Auth, Settings, Legal, Coach, Friends, Inbox — cả
- [ ] Chữ lớn nhất (iOS Accessibility XXL / Android Font size max): các màn trên không tràn/cắt chữ; nút vẫn bấm được — cả
- [ ] VoiceOver/TalkBack: 5 tab có nhãn; Train button nói "Train/Tập"; Continue trên camera gate đọc được; Switch Settings đọc tên; HUD đọc số rep — cả
- [ ] Reduce Motion: clip demo không autoplay; animation tab bar — cả
- [ ] Dark mode là chủ đề duy nhất (ThemeMode.dark); kiểm tra màn hệ thống sáng không lộ nền trắng (dialog, date/time picker, share sheet) — cả
- [ ] iPad: app iPhone-only chạy ở chế độ tương thích; mở được, không crash (không yêu cầu layout iPad) — iPad nếu có
- [ ] An: Back hệ thống ở Home (thoát app), trong sheet (đóng sheet), trong HUD (hỏi discard), trên màn giải thích quyền (ghi lại) — An
- [ ] An: cử chỉ back dự đoán (Android 14+) không làm hỏng điều hướng — An

## 11. Mất mạng / nền / kill
- [ ] Tắt mạng giữa lúc: hỏi AI feedback (fallback cục bộ), sync (pending), Coach (Retry), Friends (Retry), Inbox (giữ list) — cả
- [ ] Kill app ở: HUD (→ recovery), Results chưa lưu (→ recovery/đã lưu?), đang merge (→ không mất), đang xoá tài khoản (→ còn đăng nhập hoặc đã xoá, không nửa vời) — cả

## 12. Store metadata ★ (làm trước khi Submit)
- [ ] App Privacy (ASC) & Data safety (Play) khai Email, User ID, Fitness (linked), tên hiển thị; GroqCloud/Supabase là service provider; không tracking — (QA-04)
- [ ] Play Console › Data deletion URL nhập trang xoá tài khoản — (QA-03)
- [ ] Review Notes: tài khoản demo staging + mô tả cờ bật/tắt + cách thử camera; What's New đúng tính năng — (S-6)
- [ ] Health apps declaration (Play) xác nhận lại; disclaimer "not a medical device" trong mô tả EN/VI
- [ ] Screenshot iOS từ build v2 (5 tab); Play screenshot/feature graphic mới
- [ ] Xcode › Generate Privacy Report cho archive: không thiếu manifest SDK / required-reason
- [ ] `python3 tool/check_app_store_readiness.py` PASS trên commit nộp
