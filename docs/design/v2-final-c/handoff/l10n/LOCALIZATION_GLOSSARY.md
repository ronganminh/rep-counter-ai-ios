# LOCALIZATION_GLOSSARY

RepCoach AI · EN ↔ VI · Final C · 2026-10-22

> Status: **PROPOSED** — needs native Vietnamese product review. Vietnamese terms follow the shipping app (`lib/core/i18n/app_strings.dart`, `S.vi`) wherever it already uses the term, so existing users see no change. Machine-readable copy: `localization_glossary.json`.

| English | Tiếng Việt | Notes |
|---|---|---|
| Rep / reps | rep | Keep 'rep' (shipping app: 'Đếm rep', 'tập 3-5 rep'). Never 'lần' in counters. No plural form in VI. |
| Set | set | Shipping app uses 'set' ('Mục tiêu, set …'). 'Set 2' → 'Set 2'. |
| Workout | buổi tập |  |
| Exercise | bài tập |  |
| Hold (time held, plank) | giữ / thời gian giữ |  |
| Rest | nghỉ |  |
| Goal | mục tiêu |  |
| Streak | streak | Shipping app: 'Streak 7 ngày'. '10-day streak' → 'Streak 10 ngày'. |
| Progress (tab) | Tiến bộ | Shipping app 'Tiến bộ'. Replaces 'Tiến độ' used in the Final B prototype. |
| Personal record | kỷ lục cá nhân |  |
| AI Coach | AI Coach | Product name, not translated. |
| Voice Coach | Voice Coach | Product name, not translated. |
| RepCoach Pro / Pro | RepCoach Pro / Pro | Product name. |
| Feedback | nhận xét |  |
| Challenge | thử thách |  |
| Achievement | huy hiệu | Shipping app 'HUY HIỆU MỚI'. Replaces 'Thành tích' in the prototype. |
| Credits (AI requests) | lượt AI | '7 of 10 left' → 'Còn 7/10 lượt'. ICU: {n} lượt. |
| Subscription | gói đăng ký |  |
| Restore purchases | Khôi phục giao dịch |  |
| Guest | khách |  |
| Sync / synced | đồng bộ / đã đồng bộ |  |
| Camera verified / camera-counted | đếm bằng camera |  |
| Manual entry | nhập thủ công |  |
| Calibration | hiệu chỉnh |  |
| Pause / Resume / Finish | Tạm dừng / Tiếp tục / Kết thúc |  |
| Delete | Xóa | Spelling 'Xóa' (shipping app), not 'Xoá'. |
| History | Lịch sử |  |
| Settings | Cài đặt |  |
| Profile | Hồ sơ |  |
| Home / Exercises / Train / Progress / Profile (tabs) | Trang chủ / Bài tập / Tập / Tiến bộ / Hồ sơ |  |
| Account | tài khoản |  |
| Sign in / Sign out / Create account | Đăng nhập / Đăng xuất / Tạo tài khoản |  |
| Notifications / reminder | Thông báo / lời nhắc |  |
| Level / XP | Cấp / XP |  |
| Leaderboard | bảng xếp hạng |  |
| Friends / friend request | bạn bè / lời mời kết bạn |  |
| Form score | điểm form | Shipping app. |
| Plan / training plan | kế hoạch / kế hoạch tập |  |
| Recovery day | ngày phục hồi |  |
| Offline | ngoại tuyến / không có mạng |  |

## Clarifications added in Final C

- **Rep unit vs. counted push-ups:** the rep *unit* is always "rep" (`35 rep`, `0 rep`). Counting a specific exercise in prose may use "lần" ("35 lần hít đất"). "lần" also translates "time/once" ("một lần", "2 lần/tuần").
- **Progress:** tab and screen title = "Tiến bộ"; "tiến độ" only for progress *towards a goal* ("Tiến độ thử thách").
- **Push-up** = "hít đất"; knee push-up "hít đất chống gối"; plank, squat, lunge, burpee stay English.
- **Product names stay English:** AI Coach, Voice Coach, RepCoach, RepCoach Pro, Pro, October 500, plan names (Strength foundations) and workout names (Push & core builder, Full body A/B, Lower/Upper body A/B).
- **Confirm word:** EN `DELETE`; VI accepts `XÓA` (PROPOSED D-23).

## Formats

- **time:** 24-hour in VI: 6:41 PM → 18:41; EN keeps 12-hour. Use intl DateFormat.jm / Hm per locale, never hard-code.
- **date:** VI 'T3, 20/10' or '20 thg 10, 2026' (intl vi); EN 'Tue, Oct 20'. Use DateFormat with locale.
- **numbers:** intl NumberFormat; VI thousands separator '.', decimal ','. Durations 2:55 h:mm unchanged.
- **currency:** Never translate or hard-code prices. Use ProductDetails.price / StoreProduct.priceString from StoreKit / Play Billing.
- **plurals:** ICU in ARB: {count, plural, =1{1 rep} other{{count} reps}} for EN; VI uses other{} only.

## Verification performed (Final C)

- Diacritics: all 4,286 VI values are UTF-8 NFC; Barlow Condensed (600/800) and Inter (500/700) render Vietnamese including stacked marks (screenshot `evidence/fontcheck.png`); repo bundled `Inter.ttf` and `BarlowCondensed-ExtraBold.ttf` contain all tested VI glyphs.
- Text expansion: 7 integrated journeys and 12 negative paths run (VI journeys in Vietnamese) at 393×852 and at 375×667 with 0 overflow/clipping findings; all 22 journeys also pass at 375×667 and 430×932 in English.
- Dynamic text: ICU placeholders in 151 canonical keys; plurals EN `=1/other`, VI `other` only.
- Currency: never translated — `{price}` comes from the store SDK.
- Long buttons: VI labels such as "Tiếp tục với tư cách khách", "Đăng nhập tài khoản của tôi" fit full-width buttons at 393 and 375 widths in the prototype.
