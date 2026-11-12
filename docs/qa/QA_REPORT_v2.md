# RepCoach AI v2 — Báo cáo QA (phiên QA độc lập)

Ngày: **2026-11-10** · repo `ronganminh/rep-counter-ai-ios` @ `main` (`6c56582`) · app `rep-counter-ai-main/rep_counter_app` · pubspec `2.0.0+8` · Flutter **3.47.5** stable (cài trong cloud, trùng CI).

Tài liệu liên quan: `STORE_COMPLIANCE_v2.md` (chính sách store), `DEVICE_CHECKLIST_v2.md` (máy thật). Ảnh: `docs/qa/screenshots/` (28 ảnh, render từ widget thật trên host với font thật — không phải ảnh chụp từ thiết bị, xem §3).

## 1. Môi trường và giới hạn (đọc trước)

| Hạng mục | Kết quả |
|---|---|
| `flutter analyze --fatal-infos` | **PASS** — No issues found (cả `lib/`, `test/`, `integration_test/`) |
| `flutter test` (toàn bộ, kể cả journey mới) | **PASS** — 1090 passed, 9 skipped (8 skip có sẵn + 1 generator ảnh chỉ chạy khi `QA_SCREENSHOTS=1`), 0 failed, 2 phút 14 s |
| `flutter test test/qa_journeys` (36 journey mới, host) | **PASS** — 36/36, 22 s |
| `python3 tool/check_app_store_readiness.py` | **PASS**: App Store static release gates for 2.0.0 (8) |
| iOS Simulator | **KHÔNG CHẠY ĐƯỢC** — cloud là Linux, không có macOS/Xcode |
| Android emulator | **KHÔNG CHẠY ĐƯỢC** — máy cloud không có `/dev/kvm` (không phần cứng ảo hoá); emulator phần mềm không khả thi |
| Backend staging (Supabase) | **KHÔNG DÙNG** — không có `SUPABASE_ANON_KEY`/client IDs thật; mọi luồng tài khoản/sync/credits/XP/social/inbox chạy trên fake trong bộ nhớ (test có sẵn + journey mới) |
| Engine camera/pose | **KHÔNG CHẠM** — journey dùng `CameraPlatform` giả không có camera; không sửa `rep_counter`/`_onFrame`/`_consumePose`/`_handle`; không sửa code tính năng |

Hệ quả: các luồng cần OS prompt thật, camera thật, TTS/haptic, thông báo thật, app_links từ OS, Google/Apple sign-in native, Supabase staging, xoay màn hình thật, VoiceOver/TalkBack thật → **UNVERIFIED**, chuyển sang `DEVICE_CHECKLIST_v2.md`. Những gì báo cáo dưới đây là (a) chạy test/journey trên host với fake đã mô tả, (b) rà code tĩnh.

## 2. Bảng bug

Mức: **CHẶN** = chặn release/nộp store · **NGHIÊM TRỌNG** = phải sửa trước TestFlight/Play internal rộng · **NHỎ** = sửa khi tiện. Không bug nào được tự sửa (ràng buộc phiên QA); dòng có "Store" tham chiếu `STORE_COMPLIANCE_v2.md`.

| ID | Mức | Luồng | Bước tái hiện | Kỳ vọng vs thực tế | Ảnh | File/dòng nghi ngờ | Đề xuất sửa |
|---|---|---|---|---|---|---|---|
| QA-01 | **CHẶN (iOS)** · Store S-4 | Chia sẻ ảnh › Save image › từ chối quyền Photos | Kết quả › Share › Save image → prompt "Add to Photos" → Don't Allow | Kỳ vọng (L-D38): về màn trước, không nhắc đi Settings. Thực tế: snackbar "Photo access was denied. Allow adding photos in device Settings and retry." (VI: "Chưa có quyền thêm ảnh. Hãy cho phép trong Cài đặt của thiết bị rồi thử lại.") — đúng mẫu App Review đã từ chối 1.0.0 (6)/(7) | — (không render được trạng thái sau prompt trên host) | `lib/features/share/story_page.dart:80-84`; ARB `app_en.arb:1717`, `app_vi.arb:382` (`legacyStoryPagePhotoAccessWasDenied`) | Don't Allow → chỉ "Image not saved." hoặc không gì; lần sau bấm Save khi quyền tắt → `PermissionOffNotice` (prefix `photos-off`) Back / Open Settings. Thêm caller mới vào allowlist của `check_app_store_readiness.py` và cấm chuỗi "Photo access was denied"/"Allow adding photos"/"Hãy cho phép" |
| QA-02 | **CHẶN** (build có accounts) · Store S-1 | Pháp lý › Privacy policy (trong app + web) | Settings › Privacy policy; mở `repcoach-ai.duckdns.org/privacy-policy.html` | Kỳ vọng: mô tả dữ liệu v2 (tài khoản, Supabase, đồng bộ, XP, bạn bè, AI Coach, thông báo, xoá tài khoản). Thực tế: "The app has no user-account system", "keeps up to the latest 100 readable workout records" (sai từ L-D16), không nhắc Supabase | `17-privacy-page-en.png` | `lib/core/i18n/app_strings.dart:697-745, 940-990`; `rep-counter-ai-main/docs/privacy-policy.html` (trang live) | Viết lại EN+VI, cùng nội dung in-app/web; tăng `LegalConfig.effectiveDate*` |
| QA-03 | **NGHIÊM TRỌNG** (Play) · Store S-2 | Xoá tài khoản ngoài app | Mở `support.html` | Kỳ vọng: link/web xoá tài khoản (Play Account Deletion). Thực tế: "The current version does not provide user accounts" | — | `rep-counter-ai-main/docs/support.html` | Trang `delete-account.html` + nhập URL vào Play Console › Data deletion |
| QA-04 | **NGHIÊM TRỌNG** (store form) · Store S-3 | App Privacy / Data safety | Đọc `store_listing/DATA_SAFETY_EN.md`, `APP_STORE_CONNECT_SUBMISSION.md` | Kỳ vọng: khai Email, User ID, tên hiển thị, Fitness linked. Thực tế: chỉ Fitness/not linked; còn ghi "Google Gemini" | — | `store_listing/DATA_SAFETY_EN.md:16-20`, `PLAY_STORE_V2_UPDATE.md:124-131` | Làm lại form trước khi nộp build có accounts |
| QA-05 | NGHIÊM TRỌNG · Store S-5 | Đăng nhập (iOS) | Build iOS với `GOOGLE_*` nhưng `APPLE_SIGN_IN_ENABLED` ≠ true | Kỳ vọng: không thể (4.8). Thực tế: code hiện Google mà không hiện Apple; không gate | `24-sign-in-en.png` (trường hợp đúng: Apple trên Google) | `lib/features/auth/data/auth_bootstrap.dart:58-60` | Gate trong `check_app_store_readiness.py`/`staging_config_test`, hoặc ẩn Google khi Apple tắt trên iOS |
| QA-06 | NHỎ–TRUNG (Android) · Store S-7 | Quyền camera / thông báo — màn giải thích | An: Train › Start → màn giải thích → Back hệ thống | Kỳ vọng (Android guidance "Always provide the option to cancel an educational UI flow"): thoát được. Thực tế: Back bị chặn (`PopScope`); người dùng chỉ có Continue | `07-camera-explanation-en.png`, `22-reminder-explanation-en.png` | `lib/camera_page.dart:1641-1645`; `reminder_settings_page.dart:160` (`canPop: !intro`) | Cho Back thoát trên Android (giữ nguyên iOS); cập nhật gate |
| QA-07 | NHỎ (debug/profile) | Home › Kế hoạch (card) › mở bất kỳ màn nào › quay lại | Home › "No plan yet" card → PlanSetupPage → X (hoặc tạo plan → pop) | Kỳ vọng: không lỗi. Thực tế: Flutter assertion **"setState() callback argument returned a Future"** mỗi lần pop về Home (debug/profile; release bỏ assert nên không thấy). Làm hỏng mọi widget test đi qua card này (journey phải né) | — | `lib/features/plan/presentation/plan_home_card.dart:51` (`setState(() => _view = _safeLoad())` — arrow trả Future) | `setState(() { _view = _safeLoad(); });` |
| QA-08 | NHỎ (cần máy thật) | Xoay màn hình (Android) | Xoay ngang khi đang ở HUD / Train sheet | Kỳ vọng: khoá dọc như iOS (`UISupportedInterfaceOrientations` chỉ Portrait). Thực tế: Android không khoá (không `screenOrientation`, không `setPreferredOrientations`) → app xoay; HUD/placement thiết kế dọc | — | `android/app/src/main/AndroidManifest.xml:24-33`; `lib/main.dart` | `SystemChrome.setPreferredOrientations([portraitUp])` ở `main` hoặc `android:screenOrientation="portrait"`; kiểm tra trên máy (DEVICE §4) |
| QA-09 | NHỎ · Store 2.3.1 | Onboarding trang 1 | Cài mới | "Start with push-ups. Squats, sit-ups and more are coming." — hứa tính năng chưa có | `01-onboarding-1-en.png` | `onboarding_page.dart:88`; ARB `legacyOnboardingPageStartPushUpsSquats` | Bỏ vế "are coming" |
| QA-10 | NHỎ | Deep link `repcoach://membership` | Mở link | Kỳ vọng: thông báo "chưa có" hoặc bỏ qua rõ ràng. Thực tế: nhảy sang tab Profile không nói gì (billing tắt) — không dead-end nhưng khó hiểu | — | `lib/app/app_link.dart:162` | Thêm `LinkNotice` "Membership isn't available yet" hoặc bỏ qua link |
| QA-11 | NHỎ | Thông báo camera-off thiếu đường ghi tay · Store S-7b | Quyền camera tắt → Start | Thực tế: chỉ Back/Open Settings; "Track manually" chỉ có ở trạng thái "camera unavailable" | `09-camera-off-notice-en.png` vs `10-camera-unavailable-track-manually-en.png` | `camera_page.dart:1629-1639` | Quyết định Product: thêm nút thứ ba trung tính "Track manually" (Play khuyến nghị; Apple không cấm) |
| QA-12 | NHỎ (tài liệu) | Store listing v2 | Đọc `PLAY_STORE_V2_UPDATE.md` | What's New mô tả v2 cũ (posture gate, count-only), thiếu plan/reminders/manual/timer/clip | — | `store_listing/PLAY_STORE_V2_UPDATE.md:49-66` | Viết lại theo build nộp |
| QA-13 | NHỎ (gate CI) | `check_app_store_readiness.py` | — | Gate không quét chuỗi ARB dùng qua `context.l10n` → QA-01 lọt | — | `tool/check_app_store_readiness.py` `check_permission_screens` | Quét mọi key ARB mà code dùng có "denied/allow/từ chối/cho phép" cùng "Settings/Cài đặt" |
| QA-14 | NHỎ (test infra) | Widget test với SQLite FFI | Trong 1 `testWidgets`: pump app → close → `PlanRepository().activate` trong `runAsync` → pump lại | Deadlock đồng bộ (test timeout không bắn). Không phải bug app; ghi để người viết test sau biết | — | `test/flutter_test_config.dart` (`databaseFactoryFfiNoIsolate`) | Tách thành test riêng (đã làm trong `qa_screenshots_test.dart`) |

Không phát hiện: crash, bản ghi trùng/mất khi recovery, chuỗi placeholder `[SUPPORT_EMAIL]`…, chữ "Allow" trên màn pre-permission, tràn chữ ở scale 2.0 trên các màn đã render (onboarding, tab, Settings, Privacy, camera gate, notice, Profile VI).

## 3. Luồng đã test OK (host, fake native) — kèm ảnh

| # | Luồng | Cách test | Kết quả | Ảnh |
|---|---|---|---|---|
| J-01 | Onboarding → shell | `onboarding_shell_test` (4) | Cài mới mở EN; 3 trang; Skip/Start training lưu `onboarding_v1`; lần 2 không hiện; Back hệ thống ở Home không crash; Language → VI đổi nhãn tab + lưu, mở lại vẫn VI | 01–04 |
| J-02 | Quyền camera 5.1.1(iv) (từ Home › Train › Start) | `camera_permission_journey_test` (6) | Chưa hỏi: chỉ Continue, không Allow, Back không thoát, Continue hỏi đúng 1 lần. Don't Allow (status 4 và 0): về Home, không notice, không Settings, không snackbar, không lưu gì. Quyền tắt/restricted: notice 1 câu + Back/Open Settings; Open Settings gọi `openAppSettings` đúng 1 lần; Back/Back hệ thống về Home. Có quyền nhưng không có camera: "Could not open the camera" + Retry + **Track manually** → ManualLogPage → 3 rep → lưu → History "Manual". VI copy đúng | 06, 07, 08, 09, 10, 11, 14 |
| J-03 | Kill app giữa buổi → khôi phục | `recovery_journey_test` (3) | Draft 30 phút: màn khôi phục có Resume; Save partial → 1 bản ghi `partial`, draft xoá, History "Partial"; mở lại không hỏi lại/không lưu 2 lần. Discard (có dialog xác nhận) → trống. Draft > 12 h: không Resume, còn Save partial/Discard | 12, 13, 14 |
| J-04 | Deep link `repcoach://` trong shell | `deep_link_journey_test` (5) | friends/invites/races/challenges → toast "needs an account"; plan/session/missing → "no longer in your plan"; workouts/w9/feedback → "That workout was deleted"; unknown/membership không crash; inbox → Home; link đến khi Settings đang mở được giữ tới khi về shell; link khởi động xử lý 1 lần | — |
| J-05 | Settings, pháp lý, xoá lịch sử, AI consent | `settings_legal_journey_test` (4) | Privacy/Terms mở, có link web (`AppConfig`), Privacy nêu GroqCloud, Terms nêu "medical"; About có Help & support, email, website, version 2.0.0 (8); không placeholder; xoá lịch sử cần gõ DELETE (không phân biệt hoa thường), xoá sạch; Automatic AI: bật → dialog consent nêu GroqCloud, Not now giữ OFF | 15, 16, 17, 18, 19 |
| J-06 | Tài khoản (fake backend) | `accounts_ui_journey_test` (3) | Guest: Profile › Sign in → welcome có "Continue as guest" → Sign in: Apple trên Google, kích thước ≥, rồi email/forgot; không tab bar. Signed in: Delete account cần gõ DELETE; lỗi mạng → banner "couldn't start", vẫn đăng nhập, 0 lần xoá; thành công → "being deleted" → Close → Profile guest. VI chấp nhận "xóa" | 24, 25, 26 |
| J-07 | Kế hoạch + nhắc lịch | `plan_reminder_journey_test` (3) | Setup từ card: 4 bước, chưa lưu gì trước "Create my plan". Plan active: overview có hôm nay/recovery, tóm tắt tuần; Reminders: giải thích chỉ Continue, Back không thoát, chưa gọi prompt; Continue → từ chối → về overview, Settings không mở, không snackbar, không schedule; mở lại → notice; Open Settings 1 lần; Home card tóm tắt; Train sheet hiện buổi hôm nay + free workout | 20, 21, 22, 23 |
| J-08 | Chữ lớn 2.0 EN/VI | `large_text_journey_test` (3) | Onboarding 3 trang, 4 tab (trừ Train), Settings, Privacy, camera gate, notice: không RenderFlex overflow | 27, 28 |
| — | Test có sẵn (1054) | `flutter test` | Tất cả pass: engine/replay offline, HUD skin, results, draft/resume, manual, timer, plan/overload/reminder, a11y (tap target/labels/contrast, scale 1.0 & 2.0), l10n parity, auth/reset/delete, sync/credits/XP/social/inbox với fake server, contract tests, legal values | — |

Cách chạy lại: `flutter test test/qa_journeys` (host) · `flutter test integration_test -d <device>` (máy thật, prompt vẫn fake) · ảnh: `QA_SCREENSHOTS=1 flutter test test/qa_journeys/qa_screenshots_test.dart --update-goldens`.

## 4. Luồng CHƯA test được trong cloud (→ DEVICE_CHECKLIST)

| Luồng | Vì sao | Đã có gì thay thế |
|---|---|---|
| Tập + HUD + kết quả với camera/pose thật; đếm rep thật; calibrate; voice/haptic/âm | Không camera, không TTS, không macOS/KVM | Replay offline trong CI (`ios-ci`, `android-replay`) + unit test engine; journey chỉ tới gate |
| Prompt OS thật (camera/thông báo/Photos): Allow / Don't Allow / Only this time / restricted / tắt sau trong Settings | Không simulator/emulator | Fake permission_handler + test hiện có; hành vi "Back từ Settings với quyền đã bật → mở camera không hỏi lại" chỉ rà code (`camera_page.dart:528-530`) |
| Thông báo nhắc lịch thật (bắn đúng giờ, chạm mở link, sau reboot) | Plugin fake | `reminder_test` (planner, id ổn định, huỷ) |
| Deep link từ OS (`app_links`), universal links | Không OS | Journey đẩy link vào shell trực tiếp; L-D26: scheme đã khai, universal link chờ owner |
| Đăng nhập Google/Apple native, email link PKCE, reset mật khẩu qua email, Supabase staging, sync 2 máy, credits/XP/social/inbox với server thật, xoá tài khoản thật (Edge Function) | Không key/ID, không mạng tới staging | Fake trong bộ nhớ (`FakeAuthRepository`, `InMemory*Api`), contract tests, `staging_backend_test` (chủ dự án chạy) |
| Mất mạng giữa chừng trên thiết bị | Không thiết bị | `cloud_sync_test`, `credits_wiring_test`, `social_wiring_test`, `inbox_wiring_test` mô phỏng 401/404/5xx/no network |
| Kill app thật giữa buổi (draft ghi khi đang đếm) | Không engine | `workout_draft_test` + J-03 (draft seed sẵn) |
| Dark mode | App ép `ThemeMode.dark` (D-03) — không có light mode để so | Ảnh host đều dark |
| Reduce motion | Không OS; `ExerciseGuideCard` có nhánh reduce-motion | `exercise_guide_test` |
| VoiceOver/TalkBack thật | Không OS | `v2_screens_a11y_test` (nhãn/tap target/contrast) |
| Xoay màn hình, iPad | Không thiết bị; iOS khoá dọc; iPad = iPhone-only (TARGETED_DEVICE_FAMILY 1) | QA-08 ghi nhận Android không khoá |
| Lưu ảnh vào Photos / share sheet | Plugin native | Rà code: QA-01 |
| Clip hướng dẫn (video) phát thật | Không video plugin | `exercise_guide_test` (fake player) |

## 5. Những gì PR này thêm (không sửa code tính năng)

- `docs/qa/STORE_COMPLIANCE_v2.md`, `QA_REPORT_v2.md`, `DEVICE_CHECKLIST_v2.md`, `docs/qa/screenshots/*.png` (28 ảnh, 1.3 MB).
- `rep_counter_app/integration_test/` (8 journey, 36 test, harness `support/app_harness.dart`, README) + runner host `rep_counter_app/test/qa_journeys/*.dart` (1 dòng mỗi file) + `test/qa_journeys/qa_screenshots_test.dart` (chỉ chạy khi `QA_SCREENSHOTS=1`).
- `pubspec.yaml`: thêm dev-dependency `integration_test: sdk: flutter` (bắt buộc để chạy trên máy thật); `pubspec.lock` cập nhật tương ứng (`integration_test`, `flutter_driver`, `sync_http`, `webdriver`, `process`, `fuchsia_remote_debug_protocol` — đều từ SDK, không dependency mạng mới). Đây là thay đổi duy nhất ngoài `docs/qa` + test; nếu không chấp nhận, bỏ 2 file đó và giữ `test/qa_journeys` chạy trên host (cần đổi `ensureQaBinding` về `TestWidgetsFlutterBinding`).
- Không đổi test cũ nào.

## 6. Câu hỏi cho chủ dự án

1. Build TestFlight/Play internal sắp tới bật cờ nào? Nếu bật accounts → QA-02/03/04 là tiên quyết.
2. QA-06 (Android Back trên màn giải thích) và QA-11 (Track manually trên notice): có muốn tách hành vi theo nền tảng không?
3. QA-07: sửa 1 dòng trong `plan_home_card.dart` — cho phép đưa vào PR dev kế tiếp?
4. QA-08: khoá dọc trên Android (giống iOS) hay hỗ trợ ngang?
5. Age rating / UGC moderation (S-8, S-10) — Product + Legal.
