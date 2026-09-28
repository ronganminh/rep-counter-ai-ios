# RepCoach AI — Design Handoff (Flutter)

Tài liệu này mô tả đầy đủ giao diện và hành vi của app **RepCoach AI** để một kỹ sư (hoặc AI coding agent) không xem được file thiết kế vẫn code lại chính xác bằng Flutter.

- Nền tảng: iOS + Android, portrait-only, khung thiết kế chuẩn **iPhone 15 · 393 × 852 pt**.
- Ngôn ngữ UI: tiếng Việt (toàn bộ chuỗi trong tài liệu là bản chính thức, giữ nguyên dấu và dấu câu).
- File thiết kế nguồn (tham khảo): `RepCoach AI Design System`, `Onboarding`, `Home`, `Camera`, `HUD`, `Results`, `History - Settings`, `App Icon`, `Flow`.

---

## Mục lục

1. [Tổng quan sản phẩm & nguyên tắc UX](#1-tổng-quan-sản-phẩm--nguyên-tắc-ux)
2. [Design tokens](#2-design-tokens)
3. [Code Dart: tokens + ThemeData](#3-code-dart-tokens--themedata)
4. [Component spec](#4-component-spec)
5. [Màn hình theo thứ tự flow](#5-màn-hình-theo-thứ-tự-flow)
6. [Điều hướng (routes)](#6-điều-hướng-routes)
7. [State machine `WorkoutPhase`](#7-state-machine-workoutphase)
8. [Mô hình dữ liệu & payload AI](#8-mô-hình-dữ-liệu--payload-ai)
9. [Asset cần export](#9-asset-cần-export)
10. [Checklist accessibility](#10-checklist-accessibility)
11. [Package Flutter đề xuất](#11-package-flutter-đề-xuất)

---

## 1. Tổng quan sản phẩm & nguyên tắc UX

### 1.1 Sản phẩm

RepCoach AI đếm rep bằng camera trước và AI nhận diện tư thế chạy **hoàn toàn trên thiết bị**. Không cần tài khoản. Tập xong, app tự gửi **số liệu tổng hợp** (không phải video) lên AI để nhận xét ngay ở màn Kết quả.

- Định vị cảm xúc: một dụng cụ đo thể thao cao cấp. Tập trung, mạnh mẽ, đáng tin. **Không** trẻ con, **không** gamification lòe loẹt (không huy hiệu, không điểm kinh nghiệm, không pháo hoa toàn màn hình).
- Đa bài tập: **Hít đất** là bài duy nhất có sẵn ở v1. Squat, Gập bụng, Curl tạ, Jumping jack, Chùng chân hiển thị với trạng thái “Sắp ra mắt”. Mọi layout, copy và component phải trung tính theo bài tập (tên bài là biến).

### 1.2 Góc camera (bắt buộc)

- Điện thoại **dựng dọc (portrait)** trên sàn hoặc dựa vào vật **phía trước mặt** người tập, cách **~1–1,5 m**.
- Dùng **camera trước**. Người tập **đối diện** màn hình, nhìn thẳng vào điện thoại khi hít đất.
- Camera thấy: đầu, vai, ngực, hai tay chống, hông (từ phía trước).
- Skeleton hiển thị các khớp **vai – khuỷu – cổ tay – hông**, nét trắng mảnh 2 px (90% opacity), chấm khớp xanh chanh `#C8FF2E` r = 6 px có viền `#0B0B0C` 2 px.
- Không có chế độ landscape. Không có góc quay ngang hông cho hít đất.
- Bài tương lai có thể khuyến nghị góc khác (vd Gập bụng: “Bên hông · máy dựng ngang”) nhưng layout HUD giữ nguyên.

### 1.3 Nguyên tắc đọc từ xa

- Người tập nhìn màn hình từ ~1 m trong lúc vận động. Số rep **cực lớn (200–220 pt)** đặt ở **nửa trên** màn hình, gần camera trước.
- **Không đặt chữ hay nút ở vùng thân người** (y ≈ 490–712 trên màn 852). Nút điều khiển nằm ở đáy, ở giữa hai cổ tay.
- Mỗi rep có **giọng đọc số** tiếng Việt (TTS), **rung nhẹ**, số “đập” và viền màn hình nháy.

### 1.4 AI nhận xét

- Khi kết thúc buổi tập: lưu local → nếu AI bật và có mạng thì tự gửi payload tổng hợp → hiển thị nhận xét ngay trong card đầu tiên của màn Kết quả. Người dùng **không cần bấm**.
- Không có mạng → dùng **nhận xét offline** tạo trên máy bằng quy tắc (tag “Nhận xét nhanh (offline)”), tự thay bằng bản AI khi có mạng.
- Lần đầu kết thúc buổi tập: hỏi đồng ý bằng **Consent sheet**. Toggle tắt/bật nằm trong Cài đặt (mặc định **bật** sau khi đồng ý).
- Mọi nhận xét là tham khảo, có disclaimer: “Chỉ mang tính tham khảo tập luyện, không phải lời khuyên y khoa.”

### 1.5 Quyền riêng tư

- Video/ảnh/khuôn mặt **không bao giờ** rời máy, không được lưu.
- Chỉ gửi: bài tập, tổng rep, thời gian, nhịp, điểm form (xem §8.3).
- Component **Privacy badge** (“Xử lý trên máy”) xuất hiện ở onboarding, empty state, header màn camera/HUD.
- Không cần tài khoản. Tên người dùng (tùy chọn) chỉ lưu local.

### 1.6 Nguyên tắc trạng thái

- **Mọi trạng thái phải có icon + chữ**, không chỉ dựa vào màu.
- Màu nhấn duy nhất: xanh chanh. Màu trạng thái chỉ dùng cho trạng thái.
- Dừng sớm không bao giờ dùng chữ “thất bại” hay màu đỏ/cam. Dùng giọng tích cực.

---

## 2. Design tokens

### 2.1 Màu — Dark (mặc định)

| Token | Hex | Vai trò | Contrast trên `bg` |
|---|---|---|---|
| `bg` | `#0B0B0C` | Nền app | — |
| `surface` | `#161618` | Card, sheet, toast nền | — |
| `surface2` | `#202023` | Nút secondary, track, ô nhập, stepper − | — |
| `surface3` | `#2A2A2E` | Pressed/hover của surface2, badge “Sắp ra mắt” | — |
| `surfaceHover` | `#1B1B1E` | Hover/pressed của card bấm được | — |
| `border` | `rgba(255,255,255,0.08)` | Viền 1 px mặc định của card/surface | — |
| `borderStrong` | `rgba(255,255,255,0.12)` – `0.14` | Viền nút secondary, chip chưa chọn | — |
| `divider` | `rgba(255,255,255,0.08)` | Đường kẻ giữa các dòng | — |
| `track` | `#3A3A3F` | Dot trang chưa chọn, switch tắt | — |
| `text` | `#F4F4F0` | Chữ chính | 17.8 : 1 (AAA) |
| `textOnCamera2` | `#C9C9CE` | Chữ phụ trên nền camera/scrim | ≥ 11 : 1 |
| `text2` | `#A1A1A6` | Chữ phụ | 7.6 : 1 (AAA) |
| `text3` | `#7C7C82` | Chữ mờ, caption, icon tắt | 4.7 : 1 (AA) |
| `textDisabled` | `#5C5C62` | Icon chevron, dấu “·”, số thứ tự | chỉ dùng cho decoration |
| `accent` | `#C8FF2E` | Số rep, nút chính, progress, chấm khớp | 16.6 : 1 (AAA) |
| `accentHover` | `#D6FF5C` | Hover nút primary | — |
| `onAccent` | `#0B0B0C` | Chữ/icon trên nền accent | 16.6 : 1 |
| `accentTint` | `rgba(200,255,46,0.12)` | Nền chip chọn, badge “Đang đếm”, nền icon | — |
| `accentTintSoft` | `rgba(200,255,46,0.06)`–`0.08` | Nền card được chọn, khối “Mục tiêu buổi sau” | — |
| `accentBorder` | `rgba(200,255,46,0.24)`–`0.40` | Viền card AI, selector bài | — |
| `success` | `#3DDC97` | Sẵn sàng, đạt mục tiêu, privacy | 11.1 : 1 (AAA) |
| `successTint` | `rgba(61,220,151,0.12)` | Nền badge/khiên | — |
| `warning` | `#FF8A3D` | Cảnh báo tư thế, rep quá nhanh | 8.4 : 1 (AAA) |
| `warningText` | `#FFB27F` | Chữ cảnh báo trên nền tint cam | — |
| `warningTint` | `rgba(255,138,61,0.12)` | Nền badge cảnh báo | — |
| `danger` | `#FF5A5F` | Lỗi, xóa | 6.4 : 1 (AA) |
| `dangerText` | `#FF6B70` | Chữ destructive trên nền tint đỏ | — |
| `dangerTint` | `rgba(255,90,95,0.12)` | Nền nút destructive | — |
| `scrim` | `rgba(0,0,0,0.55)`–`0.66` | Nền mờ sau sheet/dialog | — |
| `cameraScrimTop` | gradient `rgba(11,11,12,0.82)` → `0.6` (60%) → `0` (100%), cao 500 px | Làm tối nửa trên camera để đọc chữ | — |
| `glass` | `rgba(11,11,12,0.58)` + blur 16 + viền `rgba(255,255,255,0.14)` | Nút/chip trên camera | — |

Quy tắc: status color dùng làm nền phải đi với chữ `#0B0B0C` (tất cả đạt ≥ 6.4 : 1).

### 2.2 Màu — Light

| Token | Hex | Ghi chú |
|---|---|---|
| `bg` | `#F6F6F3` | |
| `surface` | `#FFFFFF` | viền `rgba(0,0,0,0.08)` |
| `surface2` | `#EDEDEA` | |
| `border` | `rgba(0,0,0,0.08)` | |
| `borderStrong` | `rgba(0,0,0,0.12)` | |
| `text` | `#111112` | 18.2 : 1 |
| `text2` | `#5C5C62` | 6.1 : 1 |
| `text3` | `#7C7C82` | chỉ caption ≥ 12 pt đậm |
| `accent` | `#C8FF2E` | **Chỉ dùng làm nền** (chữ đen). Trên nền sáng chỉ 1.1 : 1 |
| `accentInk` | `#4A6B00` | Số rep, chữ nhấn, icon nhấn (5.7 : 1) |
| `accentFillBorder` | `inset 0 0 0 1px rgba(74,107,0,0.2)` | Viền trong cho nút/thanh chanh trên nền sáng |
| `success` | `#0F7A4F` | ≥ 4.9 : 1 |
| `warning` | `#B24A00` | ≥ 4.9 : 1 |
| `danger` | `#C8323A` | ≥ 4.9 : 1 |

Màn camera / HUD **luôn dark** bất kể theme hệ thống.

### 2.3 Typography

Font:
- **Barlow Condensed** (400/500/600/700/800) — số rep, số liệu, tiêu đề UPPERCASE. Luôn `FontFeature.tabularFigures()`.
- **Inter** (400/500/600/700) — mọi chữ UI. Hỗ trợ đầy đủ tiếng Việt.
- Monospace hệ thống chỉ dùng cho ô nhập “XÓA”.

Thang chính (theo brief: 12/14/16/20/28/40/64/Hero):

| Token | Font | Size | Weight | Line-height | Letter-spacing | Dùng cho |
|---|---|---|---|---|---|---|
| `hero` | Barlow Condensed | 200 (HUD), 220 (tối đa), 160–168 (minh họa onboarding) | 800 | 0.85 | -0.02em | Số rep khi tập |
| `heroLarge` | Barlow Condensed | 240 | 800 | 0.8 | -0.03em | Story share |
| `countdown` | Barlow Condensed | 300 | 800 | 0.85 | -0.02em | Đếm ngược 3·2·1 |
| `metric64` | Barlow Condensed | 64 | 800 | 0.9–1.0 | 0 | Điểm form, tổng rep tháng |
| `display40` | Barlow Condensed | 40 | 700–800 | 1.0 | 0, UPPERCASE | Tiêu đề màn (CHỌN BÀI TẬP, LỊCH SỬ, CÀI ĐẶT, HÍT ĐẤT HÔM NAY) |
| `headline28` | Inter | 28 | 700 | 1.2 | -0.01em | Lời chào Home, tiêu đề sheet/dialog lớn |
| `title20` | Inter | 20 | 600–700 | 1.3 | 0 | Tiêu đề card, banner |
| `body16` | Inter | 16 | 400 | 1.5 | 0 | Nội dung |
| `label16` | Inter | 16 | 600–700 | 1.0 | 0 | Nhãn nút |
| `body14` | Inter | 14 | 500 | 1.45 | 0 | Nội dung nhỏ, meta |
| `caption12` | Inter | 12 | 600 | 1.4 | +0.06em, UPPERCASE | Nhãn nhóm (HÔM NAY, BUỔI GẦN NHẤT) |

Cỡ phụ đã dùng (map vào token gần nhất khi code):
- 13 → `body14` biến thể (meta dòng lịch sử, toast phụ).
- 15 → `body16` biến thể (bullet, dòng setting).
- 17–18 → `title20` nhẹ (câu tóm tắt AI 18/600).
- 22 → “Còn 6” trên HUD (Inter 600), cue (Inter 700).
- 24 / 28 / 36 / 44 / 48 / 52 / 72 / 88 / 96 / 112 / 120 → các biến thể Barlow Condensed 700–800 cho số liệu.
- 11 → nhãn tab bar (Inter 600), badge nhỏ.

Chữ số trong mọi số liệu dùng tabular figures. Định dạng số theo vi-VN: dấu phẩy thập phân (“1,5 giây”), thời lượng `m:ss` (“4:12”), đồng hồ HUD `mm:ss` (“01:32”).

### 2.4 Spacing (lưới 4 pt)

| Token | Giá trị | Dùng |
|---|---|---|
| `s1` | 4 | Khoảng icon–chữ nhỏ |
| `s2` | 8 | Gap chip, gap nút dọc |
| `s3` | 12 | Gap trong card, padding toast dọc |
| `s4` | 16 | Padding ngang màn trong list, gap giữa card |
| `s5` | 20 | Padding card, padding ngang header |
| `s6` | 24 | Padding ngang màn onboarding/sheet |
| `s8` | 32 | Khoảng giữa section |
| `s10` | 40 | |
| `s12` | 48 | Vùng chạm tối thiểu |
| `s14` | 56 | Chiều cao nút chính |

Vùng chạm tối thiểu **48 × 48**. Safe area iOS: top 54 (status bar + Dynamic Island), bottom 34 (home indicator).

### 2.5 Radius

| Token | Giá trị | Dùng |
|---|---|---|
| `r6` | 6 | Badge nhỏ, tag |
| `r8` | 8 | Chip vuông, badge trạng thái |
| `r12` | 12 | Ô nhập, tile icon nhỏ, khối “Mục tiêu buổi sau” |
| `r16` | 16 | **Card**, toast, dòng lịch sử |
| `r20` | 20 | Card AI, banner trên camera, ô stepper |
| `r28` | 28 | **Bottom sheet** (chỉ 2 góc trên), dialog |
| `r32` | 32 | Guide zone camera |
| `pill` | 999 | Nút, chip, badge pill |

### 2.6 Border & shadow

- Dark: **không dùng shadow** cho card. Dùng viền 1 px `rgba(255,255,255,0.08)`.
- Toast nổi: `0 12px 32px rgba(0,0,0,0.5)` + viền `rgba(255,255,255,0.12)`.
- Cue trên camera: `0 8px 24px rgba(0,0,0,0.4)`.
- Card AI: viền `rgba(200,255,46,0.32)` + outer ring `0 0 0 4px rgba(200,255,46,0.04)`.
- Số rep trên camera: text-shadow `0 4px 24px rgba(0,0,0,0.45)`.

### 2.7 Motion

| Token | Giá trị | Dùng |
|---|---|---|
| `repPulse` | scale 1 → 1.08 → 1, 240 ms, `Cubic(0.34, 1.56, 0.64, 1)` (đỉnh ở 40%) | Số rep mỗi lần đếm, số countdown |
| `repFlash` | viền trong 3 px `#C8FF2E`, opacity 0.9 → 0, 400 ms easeOut | Viền màn hình mỗi rep |
| `springFast` | `SpringDescription(mass: 1, stiffness: 500, damping: 30)` | Nút, chip, toggle, stepper |
| `sheet` | spring stiffness 380, damping 36 (~320 ms) | Bottom sheet mở/đóng |
| `fade` | 160 ms `Curves.easeOut` | Xuất hiện/biến mất |
| `press` | scale 0.97 (nút), 0.94 (nút tròn stepper), 120 ms | Nhấn |
| `progress` | 320 ms `Cubic(0.34, 1.3, 0.64, 1)` | Ring/bar khi giá trị đổi |
| `toastIn` | translateY 24 → 0 + opacity, 260 ms `Cubic(0.34,1.4,0.64,1)` | Toast |
| `shimmer` | gradient chạy 1.4 s linear lặp | Skeleton AI |

Timing hành vi:

| Hành vi | Thời gian |
|---|---|
| Cue realtime tự ẩn | 2 s |
| Banner đạt mục tiêu tự ẩn | 3 s |
| Giữ nút Kết thúc | 1 s |
| Giữ yên để Ready → bắt đầu | ~1,5 s |
| Toast tự ẩn | 2,6 s |
| Toast “Hoàn tác” khi xóa | 5 s |
| Tự kết thúc set khi đứng yên | 5 s |
| Tự kết thúc buổi khi tạm dừng | 5 phút |
| Màn “Đã lưu” trước Kết quả | ~2 s |

**Giảm chuyển động** (`MediaQuery.disableAnimations`): tắt pulse, flash, shimmer, confetti. Giữ đổi số tức thì + haptic + giọng đọc.

### 2.8 Icon

- Phong cách **Lucide**: nét 2 px, bo tròn (`strokeCap/Join: round`), lưới 24.
- Kích thước: 14 (badge), 16–18 (chip, dòng), 20 (nút), 22–24 (header, bullet), 28–32 (hero icon sheet), 48–64 (illustration).
- Icon glyph bài tập: người que tự vẽ, lưới 48, nét 2.5 (xem §9).

---

## 3. Code Dart: tokens + ThemeData

### 3.1 `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_fonts: ^6.2.1
  lucide_icons_flutter: ^1.1.0
```

### 3.2 `lib/theme/app_colors.dart`

```dart
import 'package:flutter/material.dart';

/// Màu nguyên thủy. Không dùng trực tiếp trong widget — dùng AppPalette qua Theme.
abstract final class AppColors {
  // Dark
  static const bg = Color(0xFF0B0B0C);
  static const surface = Color(0xFF161618);
  static const surface2 = Color(0xFF202023);
  static const surface3 = Color(0xFF2A2A2E);
  static const surfaceHover = Color(0xFF1B1B1E);
  static const track = Color(0xFF3A3A3F);
  static const border = Color(0x14FFFFFF); // 8%
  static const borderStrong = Color(0x24FFFFFF); // 14%
  static const text = Color(0xFFF4F4F0);
  static const textOnCamera2 = Color(0xFFC9C9CE);
  static const text2 = Color(0xFFA1A1A6);
  static const text3 = Color(0xFF7C7C82);
  static const textDisabled = Color(0xFF5C5C62);

  static const accent = Color(0xFFC8FF2E);
  static const accentHover = Color(0xFFD6FF5C);
  static const onAccent = Color(0xFF0B0B0C);
  static const accentTint = Color(0x1FC8FF2E); // 12%
  static const accentTintSoft = Color(0x14C8FF2E); // 8%
  static const accentBorder = Color(0x52C8FF2E); // 32%

  static const success = Color(0xFF3DDC97);
  static const successTint = Color(0x1F3DDC97);
  static const warning = Color(0xFFFF8A3D);
  static const warningText = Color(0xFFFFB27F);
  static const warningTint = Color(0x1FFF8A3D);
  static const danger = Color(0xFFFF5A5F);
  static const dangerText = Color(0xFFFF6B70);
  static const dangerTint = Color(0x1FFF5A5F);

  static const scrim = Color(0x9E000000); // ~62%
  static const glass = Color(0x940B0B0C); // 58%

  // Light
  static const lBg = Color(0xFFF6F6F3);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurface2 = Color(0xFFEDEDEA);
  static const lBorder = Color(0x14000000);
  static const lBorderStrong = Color(0x1F000000);
  static const lText = Color(0xFF111112);
  static const lText2 = Color(0xFF5C5C62);
  static const lText3 = Color(0xFF7C7C82);
  static const lAccentInk = Color(0xFF4A6B00);
  static const lSuccess = Color(0xFF0F7A4F);
  static const lWarning = Color(0xFFB24A00);
  static const lDanger = Color(0xFFC8323A);
}

/// Màu ngữ nghĩa, đổi theo theme. Truy cập: `context.palette.accent`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.surfaceHover,
    required this.track,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.text2,
    required this.text3,
    required this.textDisabled,
    required this.accent,
    required this.accentInk,
    required this.onAccent,
    required this.accentTint,
    required this.accentTintSoft,
    required this.accentBorder,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningText,
    required this.warningTint,
    required this.danger,
    required this.dangerText,
    required this.dangerTint,
    required this.scrim,
  });

  final Color bg, surface, surface2, surface3, surfaceHover, track;
  final Color border, borderStrong;
  final Color text, text2, text3, textDisabled;
  /// Nền chanh (nút, thanh tiến độ).
  final Color accent;
  /// Chữ/số nhấn. Dark = #C8FF2E, Light = #4A6B00.
  final Color accentInk;
  final Color onAccent, accentTint, accentTintSoft, accentBorder;
  final Color success, successTint, warning, warningText, warningTint;
  final Color danger, dangerText, dangerTint, scrim;

  static const dark = AppPalette(
    bg: AppColors.bg,
    surface: AppColors.surface,
    surface2: AppColors.surface2,
    surface3: AppColors.surface3,
    surfaceHover: AppColors.surfaceHover,
    track: AppColors.track,
    border: AppColors.border,
    borderStrong: AppColors.borderStrong,
    text: AppColors.text,
    text2: AppColors.text2,
    text3: AppColors.text3,
    textDisabled: AppColors.textDisabled,
    accent: AppColors.accent,
    accentInk: AppColors.accent,
    onAccent: AppColors.onAccent,
    accentTint: AppColors.accentTint,
    accentTintSoft: AppColors.accentTintSoft,
    accentBorder: AppColors.accentBorder,
    success: AppColors.success,
    successTint: AppColors.successTint,
    warning: AppColors.warning,
    warningText: AppColors.warningText,
    warningTint: AppColors.warningTint,
    danger: AppColors.danger,
    dangerText: AppColors.dangerText,
    dangerTint: AppColors.dangerTint,
    scrim: AppColors.scrim,
  );

  static const light = AppPalette(
    bg: AppColors.lBg,
    surface: AppColors.lSurface,
    surface2: AppColors.lSurface2,
    surface3: Color(0xFFE2E2DE),
    surfaceHover: Color(0xFFF1F1EE),
    track: Color(0xFFD4D4D0),
    border: AppColors.lBorder,
    borderStrong: AppColors.lBorderStrong,
    text: AppColors.lText,
    text2: AppColors.lText2,
    text3: AppColors.lText3,
    textDisabled: Color(0xFFA1A1A6),
    accent: AppColors.accent,
    accentInk: AppColors.lAccentInk,
    onAccent: AppColors.onAccent,
    accentTint: Color(0x1A4A6B00),
    accentTintSoft: Color(0x0F4A6B00),
    accentBorder: Color(0x404A6B00),
    success: AppColors.lSuccess,
    successTint: Color(0x1A0F7A4F),
    warning: AppColors.lWarning,
    warningText: AppColors.lWarning,
    warningTint: Color(0x1AB24A00),
    danger: AppColors.lDanger,
    dangerText: AppColors.lDanger,
    dangerTint: Color(0x14C8323A),
    scrim: Color(0x66000000),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      surface3: l(surface3, other.surface3),
      surfaceHover: l(surfaceHover, other.surfaceHover),
      track: l(track, other.track),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      text: l(text, other.text),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      textDisabled: l(textDisabled, other.textDisabled),
      accent: l(accent, other.accent),
      accentInk: l(accentInk, other.accentInk),
      onAccent: l(onAccent, other.onAccent),
      accentTint: l(accentTint, other.accentTint),
      accentTintSoft: l(accentTintSoft, other.accentTintSoft),
      accentBorder: l(accentBorder, other.accentBorder),
      success: l(success, other.success),
      successTint: l(successTint, other.successTint),
      warning: l(warning, other.warning),
      warningText: l(warningText, other.warningText),
      warningTint: l(warningTint, other.warningTint),
      danger: l(danger, other.danger),
      dangerText: l(dangerText, other.dangerText),
      dangerTint: l(dangerTint, other.dangerTint),
      scrim: l(scrim, other.scrim),
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
```

### 3.3 `lib/theme/app_typography.dart`

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  static const _tnum = [FontFeature.tabularFigures()];

  static TextStyle _barlow(double size, FontWeight w, double height,
          {double spacingEm = 0}) =>
      GoogleFonts.barlowCondensed(
        fontSize: size,
        fontWeight: w,
        height: height,
        letterSpacing: size * spacingEm,
        fontFeatures: _tnum,
      );

  static TextStyle _inter(double size, FontWeight w, double height,
          {double spacingEm = 0}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: w,
        height: height,
        letterSpacing: size * spacingEm,
      );

  // Số (Barlow Condensed, tabular)
  static TextStyle get countdown => _barlow(300, FontWeight.w800, 0.85, spacingEm: -0.02);
  static TextStyle get heroLarge => _barlow(240, FontWeight.w800, 0.80, spacingEm: -0.03);
  static TextStyle get hero => _barlow(200, FontWeight.w800, 0.85, spacingEm: -0.02);
  static TextStyle get heroMax => _barlow(220, FontWeight.w800, 0.82, spacingEm: -0.02);
  static TextStyle get metric112 => _barlow(112, FontWeight.w800, 0.85, spacingEm: -0.02);
  static TextStyle get metric96 => _barlow(96, FontWeight.w800, 1.0);
  static TextStyle get metric64 => _barlow(64, FontWeight.w800, 0.9);
  static TextStyle get metric52 => _barlow(52, FontWeight.w800, 0.9);
  static TextStyle get metric40 => _barlow(40, FontWeight.w800, 0.9);
  static TextStyle get metric28 => _barlow(28, FontWeight.w800, 1.0);
  static TextStyle get metric22 => _barlow(22, FontWeight.w800, 1.0);
  static TextStyle get goalSuffix => _barlow(48, FontWeight.w700, 1.0);

  // Tiêu đề UPPERCASE (Barlow Condensed) — nhớ .toUpperCase() chuỗi
  static TextStyle get display40 => _barlow(40, FontWeight.w800, 1.0);
  static TextStyle get display44 => _barlow(44, FontWeight.w700, 1.0);
  static TextStyle get ctaHuge => _barlow(36, FontWeight.w800, 1.0, spacingEm: 0.04);
  static TextStyle get ctaLarge => _barlow(28, FontWeight.w800, 1.0, spacingEm: 0.06);
  static TextStyle get wordmark => _barlow(20, FontWeight.w800, 1.0, spacingEm: 0.02);

  // UI (Inter)
  static TextStyle get headline28 => _inter(28, FontWeight.w700, 1.2, spacingEm: -0.01);
  static TextStyle get title22 => _inter(22, FontWeight.w700, 1.25);
  static TextStyle get title20 => _inter(20, FontWeight.w600, 1.3);
  static TextStyle get lead18 => _inter(18, FontWeight.w600, 1.4);
  static TextStyle get body16 => _inter(16, FontWeight.w400, 1.5);
  static TextStyle get label16 => _inter(16, FontWeight.w700, 1.0);
  static TextStyle get labelMedium16 => _inter(16, FontWeight.w600, 1.0);
  static TextStyle get body15 => _inter(15, FontWeight.w500, 1.4);
  static TextStyle get body14 => _inter(14, FontWeight.w500, 1.45);
  static TextStyle get body13 => _inter(13, FontWeight.w500, 1.4);
  static TextStyle get caption12 => _inter(12, FontWeight.w600, 1.4, spacingEm: 0.06);
  static TextStyle get badge12 => _inter(12, FontWeight.w600, 1.0);
  static TextStyle get tab11 => _inter(11, FontWeight.w600, 1.0);

  static TextTheme textTheme(Color text, Color text2) => TextTheme(
        displayLarge: hero.copyWith(color: text),
        displayMedium: metric64.copyWith(color: text),
        displaySmall: display40.copyWith(color: text),
        headlineMedium: headline28.copyWith(color: text),
        titleLarge: title20.copyWith(color: text),
        titleMedium: labelMedium16.copyWith(color: text),
        bodyLarge: body16.copyWith(color: text),
        bodyMedium: body14.copyWith(color: text2),
        bodySmall: body13.copyWith(color: text2),
        labelLarge: label16.copyWith(color: text),
        labelMedium: badge12.copyWith(color: text2),
        labelSmall: caption12.copyWith(color: text2),
      );
}
```

### 3.4 `lib/theme/app_spacing.dart`, `app_radius.dart`, `app_motion.dart`

```dart
import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;
  static const s14 = 56.0;

  static const minTouch = 48.0;
  static const buttonHeight = 56.0;
  static const buttonHeightSmall = 48.0;
  static const selectorHeight = 64.0;
  static const ctaHugeHeight = 80.0;
  static const tabBarHeight = 83.0; // gồm 34 home indicator trên iOS
  static const screenPadding = EdgeInsets.symmetric(horizontal: 24);
  static const listPadding = EdgeInsets.symmetric(horizontal: 16);
  static const cardPadding = EdgeInsets.all(20);
}

abstract final class AppRadius {
  static const r6 = 6.0;
  static const r8 = 8.0;
  static const r12 = 12.0;
  static const card = 16.0;
  static const r20 = 20.0;
  static const sheet = 28.0;
  static const guideZone = 32.0;
  static const pill = 999.0;

  static const cardBR = BorderRadius.all(Radius.circular(card));
  static const sheetBR = BorderRadius.vertical(top: Radius.circular(sheet));
  static const pillBR = BorderRadius.all(Radius.circular(pill));
}

abstract final class AppMotion {
  static const repPulseDuration = Duration(milliseconds: 240);
  static const repPulseCurve = Cubic(0.34, 1.56, 0.64, 1);
  static const repPulseScale = 1.08;
  static const repFlashDuration = Duration(milliseconds: 400);
  static const fade = Duration(milliseconds: 160);
  static const press = Duration(milliseconds: 120);
  static const progress = Duration(milliseconds: 320);
  static const progressCurve = Cubic(0.34, 1.3, 0.64, 1);
  static const toastIn = Duration(milliseconds: 260);
  static const toastCurve = Cubic(0.34, 1.4, 0.64, 1);

  static const springFast = SpringDescription(mass: 1, stiffness: 500, damping: 30);
  static const springSheet = SpringDescription(mass: 1, stiffness: 380, damping: 36);

  static const cueVisible = Duration(seconds: 2);
  static const goalBannerVisible = Duration(seconds: 3);
  static const holdToEnd = Duration(seconds: 1);
  static const readyHold = Duration(milliseconds: 1500);
  static const toastVisible = Duration(milliseconds: 2600);
  static const undoWindow = Duration(seconds: 5);
  static const idleEndSet = Duration(seconds: 5);
  static const pausedAutoEnd = Duration(minutes: 5);
  static const savedTransition = Duration(seconds: 2);
}
```

### 3.5 `lib/theme/app_theme.dart` (Material 3)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData dark() => _build(Brightness.dark, AppPalette.dark);
  static ThemeData light() => _build(Brightness.light, AppPalette.light);

  static ThemeData _build(Brightness b, AppPalette p) {
    final scheme = ColorScheme(
      brightness: b,
      primary: p.accent,
      onPrimary: p.onAccent,
      primaryContainer: p.accentTint,
      onPrimaryContainer: p.accentInk,
      secondary: p.surface2,
      onSecondary: p.text,
      tertiary: p.success,
      onTertiary: p.onAccent,
      error: p.danger,
      onError: p.onAccent,
      errorContainer: p.dangerTint,
      onErrorContainer: p.dangerText,
      surface: p.bg,
      onSurface: p.text,
      onSurfaceVariant: p.text2,
      surfaceContainerLowest: p.bg,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surface2,
      surfaceContainerHighest: p.surface3,
      outline: p.borderStrong,
      outlineVariant: p.border,
      scrim: p.scrim,
      shadow: Colors.black,
      inverseSurface: p.text,
      onInverseSurface: p.bg,
      inversePrimary: p.accentInk,
    );

    final text = AppTypography.textTheme(p.text, p.text2);
    const pill = StadiumBorder();

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      textTheme: text,
      extensions: [p],
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.labelMedium16.copyWith(color: p.text),
        systemOverlayStyle: b == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBR,
          side: BorderSide(color: p.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.surface2,
          disabledForegroundColor: p.text3,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          shape: pill,
          textStyle: AppTypography.label16,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: p.surface2,
          foregroundColor: p.text,
          side: BorderSide(color: p.borderStrong),
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          shape: pill,
          textStyle: AppTypography.labelMedium16,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(AppSpacing.minTouch, AppSpacing.buttonHeightSmall),
          shape: pill,
          textStyle: AppTypography.labelMedium16,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size.square(AppSpacing.minTouch),
          shape: const CircleBorder(),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: p.accentTint,
        side: BorderSide(color: p.borderStrong),
        shape: pill,
        labelStyle: AppTypography.body14.copyWith(color: p.text, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.onAccent : p.text),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.accent : p.track),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.surface2,
        circularTrackColor: p.surface2,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        modalBarrierColor: p.scrim,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: const Color(0x33FFFFFF),
        dragHandleSize: const Size(36, 5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetBR),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          side: BorderSide(color: p.borderStrong),
        ),
        titleTextStyle: AppTypography.title22.copyWith(color: p.text),
        contentTextStyle: AppTypography.body15.copyWith(color: p.text2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surface2,
        contentTextStyle: AppTypography.body14.copyWith(color: p.text),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBR,
          side: BorderSide(color: p.borderStrong),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.bg.withValues(alpha: 0.94),
        indicatorColor: Colors.transparent,
        height: 56,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => AppTypography.tab11
            .copyWith(color: s.contains(WidgetState.selected) ? p.accentInk : p.text3)),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 24, color: s.contains(WidgetState.selected) ? p.accentInk : p.text3)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          borderSide: BorderSide(color: p.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          borderSide: BorderSide(color: p.danger, width: 2),
        ),
      ),
    );
  }
}
```

`MaterialApp(theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: ThemeMode.dark)` — mặc định dark, cho phép chọn “Theo hệ thống” sau.

---

## 4. Component spec

Quy ước: kích thước tính bằng logical px (pt). Tên widget đề xuất ở dạng `ClassName`.

### 4.1 Nút

| Loại | Widget | Cao | Nền | Chữ | Viền | Ghi chú |
|---|---|---|---|---|---|---|
| Primary | `AppButton.primary` | 56 (small 48) | `accent` | `onAccent` Inter 16/700 | — | pill, icon trái 20 tùy chọn, gap 8 |
| Primary disabled | | 56 | `surface2` | `text3` | — | Vd “Đang hiệu chỉnh…” |
| Secondary | `AppButton.secondary` | 56 / 48 | `surface2` | `text` Inter 16/600 | 1 px `borderStrong` | pressed `surface3` |
| Ghost | `AppButton.ghost` | 56 / 48 | trong suốt | `text` hoặc `accentInk` | — | pressed nền `rgba(255,255,255,0.06)` |
| Destructive (tint) | `AppButton.destructive` | 56 | `dangerTint` | `danger`/`dangerText` 16/600 | 1 px `rgba(255,90,95,0.32)` | Vd “Xóa buổi tập” |
| Destructive (solid) | `AppButton.destructiveSolid` | 52–56 | `danger` | `onAccent` 16/700 | — | Chỉ trong dialog xác nhận cuối |
| CTA cực lớn | `HugeCtaButton` | 80 | `accent` | Barlow Condensed 36/800, +0.04em, UPPERCASE, icon play 26 | — | “TẬP NGAY” |
| CTA lớn | `LargeCtaButton` | 64–72 | `accent` | Barlow Condensed 28–30/800, +0.06em | — | “BẮT ĐẦU”, “TIẾP TỤC” |
| Icon tròn | `CircleIconButton` | 48 (min) | trong suốt / `glass` | icon 22–24 | — | Nút ×, ‹ |

Tất cả: pressed scale 0.97, 120 ms; haptic `selectionClick` với primary.

### 4.2 Stepper số — `RepGoalStepper`

- Hàng ngang: nút − (64 × 64, tròn, `surface2`, viền `borderStrong`, icon minus 28) · ô số (flex, cao 112, `surface2`, r20) · nút + (64 × 64, `accent`, icon plus 28 màu `onAccent`). Gap 12.
- Ô số: Barlow Condensed 96/800 tabular, kèm “rep” Inter 16/600 `text2` căn baseline dưới (chỉ ở trạng thái mặc định).
- Chạm ô số → focus `TextField` bàn phím số (`TextInputType.number`, `inputFormatters: digitsOnly`, maxLength 4).
  - Đang nhập: viền 2 px `accent`, caret 3 × 64 `accent`. Helper dưới: “Nhập từ 1 đến 999” (13/500 `text2`, căn giữa).
  - Lỗi (giá trị < 1 hoặc > 999, hoặc rỗng): viền + số `danger`, cỡ số giảm 72 nếu ≥ 4 chữ số; helper: icon `circle-x` 18 + “Nhập số từ 1 đến 999” (14/600 `danger`). Nút “Xong” trên toolbar bàn phím bị khóa (`textDisabled`).
  - Mặc định helper: “Chạm vào số để nhập” (13/500 `text3`).
- Nút −/+: bước 1, giữ để lặp nhanh (sau 400 ms, mỗi 80 ms). Kẹp 1–999.
- Toolbar bàn phím (cao 44, `surface`, viền trên): trái “Mục tiêu rep · 1–999” (13/500 `text3`), phải “Xong” (16/600 `accent` hoặc `textDisabled`).
- Semantics: `Semantics(value: '20 rep', increasedValue, decreasedValue, onIncrease, onDecrease)`.

### 4.3 Chip gợi ý — `GoalChip`, `SuggestionChip`

- `GoalChip` (trong sheet): lưới 4 cột gap 8, cao 52, pill, Barlow Condensed 24/800. Chưa chọn: nền trong suốt, viền `borderStrong`, chữ `text`. Chọn: nền `accentTint`, viền `accent`, chữ `accent`.
- Chip trùng mục tiêu lần trước có nhãn nổi “Lần trước”: pill cao 20, nền `bg`, viền `rgba(255,255,255,0.16)`, Inter 11/600 `#C9C9CE`, đặt giữa, top −10.
- Không chip nào chọn khi giá trị khác 10/20/30/50.
- `SuggestionChip` (thông tin): cao 40, pill, nền `surface2`, viền `border`, icon 16 + chữ 14/500. Vd “Thử 22 rep, hơn lần trước 2”, “Nghỉ 60 giây giữa hiệp”.
- `FilterChip` (Lịch sử): cao 40, “Tất cả” chọn (nền `accentTint`, viền `accent`, chữ `accent`); “Hít đất” có glyph 26; bài chưa có: chữ `text3`, viền `border`, kèm icon clock 12 + “Sắp ra mắt” 11/600 `text2`, không bấm được. Hàng cuộn ngang, padding 20.

### 4.4 Badge trạng thái — `StatusBadge`

- Cao 32 (nhỏ 24, rất nhỏ 20), r8 (hoặc pill), padding trái 10 phải 12, icon 16 (14/11) + chữ Inter 14/600 (12/600, 11/700).
- Biến thể:
  - `ready` — `circle-check`, “Sẵn sàng”, `success` trên `successTint`.
  - `counting` — `activity`, “Đang đếm”, `accent` trên `accentTint`.
  - `warning` — `triangle-alert`, vd “Hông bị võng”, `warning` trên `warningTint`.
  - `error` — `circle-x`, vd “Ra khỏi khung hình”, `danger` trên `dangerTint`.
  - `paused` — `circle-pause`, “Tạm dừng”, `text2` trên `surface2`.
  - `available` — “Có sẵn” (success, cao 24, r6).
  - `comingSoon` — `clock`, “Sắp ra mắt”, chữ `#C9C9CE` trên `surface3` (cao 24, r6).
  - `goalMet` — “Đạt mục tiêu” / “Đạt mục tiêu +3” (success, pill cao 36, viền `rgba(61,220,151,0.4)`, chữ 15/700).
  - `partial` — `trending-up`, “14/20 · 70%” (accent, pill cao 36, viền `rgba(200,255,46,0.35)`).
  - `record` — `trophy` 11, “Kỷ lục”, nền `accent`, chữ `onAccent` 11/700, cao 20, r5.
  - `overGoal` — `chevron-up` 18, “+3 vượt mục tiêu”, success tint, viền 50%, pill cao 34, 16/700.

### 4.5 Privacy badge — `PrivacyBadge`

- Icon `shield-check` (Lucide) + chữ “Xử lý trên máy”.
- Biến thể:
  - `tinted` (mặc định): pill cao 32–36, nền `successTint` 10%, viền `rgba(61,220,151,0.28)`, chữ + icon `success`, 13–14/600, icon 16–18.
  - `glass` (trên camera): pill cao 32, nền `glass` + blur, viền `rgba(255,255,255,0.12)`, chữ `text` 12/600, icon `success` 15.
  - `inline` (dưới empty state): icon 14 `success` + “Xử lý trên máy · không cần tài khoản” 12/500 `text3`.
  - `card`: hàng icon tròn 48 (`successTint`) + tiêu đề “Xử lý trên máy” 16/600 + mô tả “Hình ảnh camera không rời khỏi điện thoại. AI chỉ nhận số liệu tổng hợp sau buổi tập, và bạn có thể tắt.” 14 `text2`.
- Semantics label: “Xử lý trên máy. Video không rời điện thoại.”

### 4.6 Progress ring — `ProgressRing`

- `CustomPainter`, bắt đầu ở 12 giờ, chạy theo chiều kim đồng hồ, đầu nét tròn.
- Size/stroke: 232/16 (Kết quả), 132/12 (card), 64/6 (mini). Track `surface2`.
- Màu tiến độ: `accent`. Khi ≥ 100%: vòng `accent` đầy + **cung chồng `success`** từ 12 giờ dài `over/goal` (vd +3/20 = 15%), ngăn cách bằng một khe 2 px màu `bg`.
- Mini đạt 100%: vòng `success` đầy, ở giữa icon check 22.
- Nội dung giữa: số Barlow 112/800 `text` + “/20” 32/700 `text3` căn baseline; hoặc “%” 40/800 + “hoàn thành” 12/500.
- Animate 320 ms `progressCurve`.
- Semantics: “23 trên 20 rep, đạt mục tiêu, vượt 3”.

### 4.7 Progress bar — `LinearProgress`

- Cao 8 (card), 6 (màn tập cũ), 4 (HUD mép trên, hiệu chỉnh), pill, track `surface2` (trên camera: `rgba(255,255,255,0.18)`).
- Màu: `accent`; đạt mục tiêu: `success`; mất tư thế: `text3`.
- Biến thể phân đoạn “Mục tiêu tuần”: 5 đoạn gap 4.

### 4.8 Card — `AppCard`

- Nền `surface`, r16, viền 1 px `border`, padding 18–20, không shadow. Bấm được: pressed `surfaceHover`, chevron-right 18–20 `textDisabled`.
- Nhãn nhóm trên cùng: `caption12` UPPERCASE `text3`.

### 4.9 Exercise card — `ExerciseCard` và `ExerciseTile`

- `ExerciseCard` (danh sách, cao ≥ 80): tile icon 56 (r14, `surface2`, glyph 34), tên 16/600, badge “Có sẵn”/“Sắp ra mắt”, dòng góc camera: icon camera 14 + chữ 13/500 `text2` (vd “Trước mặt · máy dọc · 1–1,5 m”), chevron.
- `ExerciseTile` (lưới 2 cột gap 10, cao ≥ 156–168): tile icon 52, tên 16/600, góc camera 12/500 `text3`.
  - Có sẵn + đã chọn (ở A0 là card lớn full-width): nền `accentTintSoft`, viền 2 px `accent`, check tròn 24 (`accent`, icon check 14 `onAccent`) góc phải trên. Glyph 46 trong tile 72.
  - Sắp ra mắt: nội dung opacity 45%, badge “Sắp ra mắt” giữ 100% ở góc phải trên. Chạm → toast “Sắp ra mắt”.
- Dữ liệu bài: xem §8.1.

### 4.10 Exercise picker — `ExercisePickerScreen`

Xem màn §5.6.

### 4.11 AI feedback card — `AiFeedbackCard` (4 trạng thái + tắt)

Khung chung: nền `surface`, r20, viền `rgba(200,255,46,0.32)`, outer ring 4 px `rgba(200,255,46,0.04)`, padding 20, gap 16.

Header: tile 32 (r10, `accentTint`) chứa icon `sparkles` 18 `accent` · “RepCoach AI nhận xét” Inter 16/700 · tag nguồn bên phải (cao 22, r6, 11/700, +0.04em): “AI” (nền `accentTint`, chữ `accent`) hoặc “Nhận xét nhanh (offline)” (nền `surface3`, chữ `#C9C9CE`).

Footer: icon `shield-check` 14 `success` + “Từ số liệu tổng hợp · video không rời máy” 12/500 `text3`.

| Trạng thái | Nội dung |
|---|---|
| `loading` | 2 thanh shimmer (cao 14, rộng 96% / 82%), 3 dòng (chấm 20 + thanh 12 rộng 70/78/60%), khối 62 cao r12 shimmer; dòng spinner 14 (viền 2 `accent`) + “AI đang đọc số liệu…” 14/500 `#C9C9CE`. Giữ cùng chiều cao với `ready` để không nhảy layout. |
| `ready` | Câu tóm tắt Inter 18/600 (1.4). Danh sách gap 10: tối đa 2 dòng **Tốt** (icon `circle-check` 20 `success` + “Tốt:” 600 `success` + text 15/400) và tối đa 2 dòng **Cải thiện** (icon `circle-arrow-up` 20 `warning` + “Cải thiện:” 600 `warning`). Khối **Mục tiêu buổi sau**: nền `accentTintSoft`, viền `rgba(200,255,46,0.24)`, r12, padding 12×14, icon `target` 22 `accent`, nhãn “MỤC TIÊU BUỔI SAU” 12/600 `text2` +0.04em, giá trị 16/600 (vd “24 rep, giữ mỗi rep ≥ 1,5 giây”). |
| `offline` | Tag “Nhận xét nhanh (offline)”. Thông báo: nền `warningTint` 10%, viền `rgba(255,138,61,0.3)`, r12, icon `wifi-off` 18 `warning` + “Đang dùng nhận xét offline · Sẽ cập nhật khi có mạng” 14/500 `warningText`. Sau đó nội dung như `ready` (rút gọn: 1 tốt, 1 cải thiện, mục tiêu). |
| `error` | Icon `circle-alert` 22 `danger` + “Chưa tạo được nhận xét” 17/600 + “Buổi tập đã được lưu an toàn trên máy. Kết nối bị gián đoạn khi gửi số liệu.” 14 `text2`. Nút secondary cao 48 “Thử lại” (icon `refresh-cw` 18), thụt trái 32. Không chặn màn Kết quả. |
| `disabled` | Card thường (viền `border`): icon sparkles `text3` + “AI nhận xét đang tắt” 14/600 `text2`; “Số liệu buổi tập chỉ lưu trên máy.”; nút ghost “Bật trong Cài đặt” `accent`. |

Không dùng emoji (✓ ↑ 🎯 được thay bằng icon Lucide như trên).

### 4.12 HUD rep counter — `HudRepCounter`

- Vị trí: top 156, căn giữa ngang.
- Số: Barlow 200/800, line-height 0.85, tabular, màu `accent`; text-shadow `0 4px 24px rgba(0,0,0,0.45)`. Vùng số cao 170.
- Hậu tố mục tiêu: “/ 20” Barlow 48/700 `#C9C9CE`, căn baseline, gap 6. Ẩn ở chế độ tự do (thay bằng “rep” Inter 18/600 `#C9C9CE` bên dưới).
- Dòng phụ dưới (gap 10): “Còn 6” Inter 22/600 `text`; hoặc badge `overGoal`.
- Màu theo trạng thái: đang đếm `accent`; mất tư thế `#8A8A90` (xám); đạt/vượt mục tiêu: số `success` ở khoảnh khắc đạt (D1), quay lại `accent` khi tập thêm (E1).
- Mỗi rep: `AnimatedScale` pulse (§2.7), `RepFlashOverlay` viền 3 px, `HapticFeedback.lightImpact()`, TTS đọc số (“Mười bốn”), nút loa hiển thị chuỗi đang đọc trong ngoặc kép.
- Semantics: live region `Semantics(liveRegion: true, label: '14 trên 20 rep')`.

### 4.13 Status chip tư thế — `PostureChip`

- Top 378, căn giữa. Pill cao 44, padding trái 12 phải 16, icon 20 + chữ Inter 16/600.
- `good`: `circle-check`, “Tư thế tốt”, nền `glass`, viền `rgba(61,220,151,0.45)`, chữ `success`.
- `lost`: `triangle-alert`, “Mất tư thế – tạm dừng đếm”, nền `rgba(40,20,8,0.72)` + blur, viền `rgba(255,138,61,0.6)`, chữ `warning`. Khi `lost`: dừng đếm, số rep + thanh tiến độ chuyển xám, khớp lệch trên skeleton chuyển cam (r 7).

### 4.14 Cue toast realtime — `CueToast`

- Top 436, căn giữa. Pill cao 52, nền `#F4F4F0`, chữ `#0B0B0C` Inter 22/700, icon 24 nét 2.5, padding 16/22, shadow `0 8px 24px rgba(0,0,0,0.4)`.
- Nội dung ≤ 3 từ (bộ chuẩn hít đất): “Xuống sâu hơn” (icon `arrow-down`), “Giữ thân thẳng” (icon thước dọc), “Hạ thấp hơn”, “Chậm lại”.
- Hiện 2 s rồi fade 160 ms. Không xếp chồng — cue mới thay cue cũ. Đồng thời TTS đọc cue.

### 4.15 Toast hệ thống — `AppToast`

- Cao ≥ 56, r16, nền `surface2`, viền `borderStrong`, shadow toast, min width 320, bottom 32 (trên tab bar nếu có). Icon trạng thái 20 + chữ 14/500 + action ghost tùy chọn (40 cao, `accent`).
- Mẫu: `circle-check success` “Đã lưu buổi tập · 75 rep”; `triangle-alert warning` “Ánh sáng yếu, độ chính xác có thể giảm”; `circle-x danger` “Không mở được camera” + “Cấp quyền”; “Sắp ra mắt”; “Đã xóa buổi tập” + “Hoàn tác” (5 s).

### 4.16 Bottom sheet — `AppBottomSheet`

- Nền `surface`, viền trên 1 px `border`, bo 28 hai góc trên. Drag handle 36 × 5, `rgba(255,255,255,0.2)`, cách top 8.
- Padding ngang 20–24, đáy 36–42 (gồm safe area). Scrim `scrim`.
- Mở/đóng spring `springSheet`. Kéo xuống hoặc chạm scrim để đóng (trừ khi đang nhập bàn phím).
- Khi bàn phím mở, sheet nằm **sát trên** bàn phím (không có khe).

### 4.17 Dialog xác nhận gõ chữ — `TypeToConfirmDialog`

Xem màn §5.21.

### 4.18 Heatmap — `MonthHeatmap`

- Lưới 7 cột (T2 → CN), 5 hàng tuần, gap 6, ô vuông (aspect 1), r8. Header ngày 11/600 `text3`.
- Số ngày trong ô: góc trái trên, 10/600 tabular.
- Mức theo số rep/ngày: `0` → `surface2`; `1–15` → `rgba(200,255,46,0.28)`; `16–22` → `rgba(200,255,46,0.62)` (chữ `onAccent`); `23+` → `accent` (chữ `onAccent`). Ngày ngoài tháng: trong suốt, viền nét đứt 6%.
- Hôm nay: viền trong 2 px `text`.
- Chú thích dưới: 4 ô 14×14 + “0”, “1–15”, “16–22”, “23+ rep”, và ô viền “Hôm nay” (12/500 `text2`).
- Semantics mỗi ô: “Thứ Ba 22 tháng 9, 22 rep”.

### 4.19 Line chart — `RepsLineChart`

- 30 ngày gần nhất, mỗi điểm = 1 buổi. Trục y 0–30, lưới ngang 10/20/30 (`rgba(255,255,255,0.07)`), đường 20 là mục tiêu: nét đứt `rgba(255,255,255,0.25)` + nhãn “Mục tiêu 20”.
- Đường `accent` 2.5 px, vùng dưới `rgba(200,255,46,0.08)`. Điểm r3 (nền `bg`, viền `accent` 2).
- Kỷ lục: điểm r5.5 đặc `accent` + quầng r10 `rgba(200,255,46,0.2)` + pill “Kỷ lục · 25 rep” (icon `trophy` 13, nền `accent`, chữ `onAccent` 12/700).
- Nhãn trục x: “28/8”, “7/9”, “17/9”, “26/9” (11/600 `text3`). Cao 140 + 22.

### 4.20 Pace chart — `RepPaceChart`

- Cột mỗi rep, rộng 9, gap 3, r3, cao = giây/3 × 112. Nhóm theo set, giữa nhóm gap 12, nhãn dưới “Set 1 · 8” (12/600 `text2`).
- Rep **quá nhanh** (< 1 giây, cấu hình theo bài): cột `warning` + chấm tròn 7 `warning` phía trên (viền 2 `surface`). Rep ổn: cột `accent`.
- Đường nhịp gợi ý 1,5 s: nét đứt `rgba(255,255,255,0.28)` + nhãn “1,5 s”.
- Chú thích: ô cột “Nhịp ổn”, chấm cam “Quá nhanh (dưới 1 giây)”, nét đứt “Nhịp gợi ý”.
- Tóm tắt: “**5 rep quá nhanh**, đều ở set cuối.” (phần đậm `warning`) hoặc “Không có rep nào quá nhanh.”

### 4.21 Form score card — `FormScoreCard`

- Header “ĐIỂM FORM” + tag “ước tính” (icon info 12, nền `surface2`, 11/600).
- “82” Barlow 64/800 `accent` + “/100” 24/700 `text3`.
- 4 thanh (gap 14): tên 14/500 + giá trị tabular `#C9C9CE`; bar cao 6, `accent` nếu ≥ 80, `rgba(200,255,46,0.55)` nếu < 80. Thứ tự: **Biên độ · Nhịp đều · Cân bằng trái/phải · Tư thế ổn định**.

### 4.22 Empty state — `EmptyState`

- Căn giữa, gap 16–24: illustration 72–200, tiêu đề Inter 20–22/700, mô tả 14–15 `text2` (max 280–320), nút primary 56 (icon play), privacy inline tùy chọn.

### 4.23 Tab bar — `AppTabBar`

- 3 tab: **Tập** (icon `dumbbell`), **Lịch sử** (`history`), **Cài đặt** (`settings`). Icon 24, nhãn 11/600, gap 4. Chọn: `accentInk`; chưa: `text3`.
- Cao 83 (gồm home indicator), nền `bg` 94% + blur 12, viền trên `border`. Cố định đáy.

### 4.24 Toggle — `AppSwitch`

- 51 × 31, track bật `accent` (thumb `onAccent`), tắt `track` (thumb `text`). Spring nhanh.

### 4.25 Settings row — `SettingsRow`, `SettingsGroup`

- Nhóm: nhãn 12/600 UPPERCASE `text3` (padding trái 6) + khối `surface` r16 viền `border`.
- Dòng: min cao 60, padding 10×16, tile icon 32 (r9, `surface2`, icon 18 `accent`), tiêu đề 16/500, phụ đề 13 `text2`, phần phải: switch / chevron / giá trị 15 `text2` / icon external. Divider giữa dòng.

### 4.26 Camera overlays

- `GuideZone`: left/right 20, top 392, bottom 34, r32, viền nét đứt 2 px trắng 60%. Ready: liền nét `success` + rung 1 lần.
- `Silhouette`: plank nhìn trước, trắng 16%.
- `SkeletonOverlay`: xem §1.2.
- `CameraBanner` (positioning): left/right 16, top 122, r20, nền `rgba(11,11,12,0.78)` + blur 16, viền `warning` 33%, icon tròn 44 (`warningTint`) + tiêu đề 20/700 + phụ 14/500 `#C9C9CE`.
- `SetupChecklist`: left 16, top 226, r16, nền `rgba(11,11,12,0.66)`, 3 dòng cao 28: đạt = `circle-check` 18 `success` + chữ 14/500; chưa đạt = chấm 8 `warning` + chữ `warningText` + “· chưa đạt” 12 `text2`.
- `CameraHeader`: top 58–68, cao 44–48: `PrivacyBadge.glass` trái, tên bài giữa (14/600), nút × tròn 48 (`glass`) phải.

---

## 5. Màn hình theo thứ tự flow

Ký hiệu: **[Nút]** = vùng bấm; → = điều hướng. Toạ độ theo khung 393 × 852.

### 5.1 Onboarding 1 — Đếm rep (`/onboarding` trang 0)

Layout (Scaffold `bg`, `PageView` vuốt ngang 3 trang):
1. Status bar.
2. Top bar cao 56: trái wordmark (mark icon 1.3em + “REPCOACH” + “AI” màu `accent`, Barlow 20/800 +0.02em). Phải **[Bỏ qua]** (ghost, 16/600 `text2`).
3. Minh họa (flex): 3 glyph bài khác mờ (squat trái trên, jumping jack phải trên — opacity 14%; curl phải giữa — 10%). Giữa trên: số “12” Barlow 168/800 `accent`, trôi lên xuống 8 px chu kỳ 2.4 s; dưới là chip “"Mười hai"” (icon loa 16 `accent`, nền `surface`, 13/500 `text2`). Dưới: người hít đất nhìn từ phía trước (vai, tay, đầu khối `#26262A`/`#2E2E33`) + skeleton vai–khuỷu–cổ tay–hông chấm `accent`.
4. Tiêu đề: **“Điện thoại đếm rep. AI chấm và nhận xét.”** (Barlow 40/700, balance).
5. Phụ: “Bắt đầu với hít đất. Squat, gập bụng và nhiều bài khác sắp có.” (16 `text2`).
6. Chỉ báo trang: 3 chấm (active 24 × 8 `accent`, khác 8 × 8 `track`), gap 6.
7. **[Tiếp tục]** primary 56 → trang 2.

### 5.2 Onboarding 2 — Đặt máy (trang 1)

1. Top bar như trên (có “Bỏ qua”).
2. Sơ đồ card cao 284 (`surface`, r16), nhãn “NHÌN TỪ BÊN CẠNH” 11/600 `text3`. Side view: người tư thế plank, điện thoại dựng dọc trên sàn phía trước đầu (viền `accent`), nón góc nhìn camera nét đứt `accent` 50% + nền 7% chiếu vào người, skeleton vai–khuỷu–cổ tay–hông. Tag “Camera trước · máy dọc” (viền `accent` 40%) và thước “~1–1,5 m”.
3. Tiêu đề: **“Đặt điện thoại trước mặt, camera trước hướng vào bạn.”** (Barlow 34/700).
4. 3 bullet (tile icon 40 r12 `surface`, icon 20 `accent` + chữ 15/500):
   - `smartphone` — “Dựng máy dọc, cách ~1–1.5m”
   - `user` — “Thấy rõ vai, hai tay và hông”
   - `sun` — “Đủ sáng, nền gọn”
5. Chỉ báo trang (chấm 2 active). **[Tiếp tục]** → trang 3.

### 5.3 Onboarding 3 — Riêng tư (trang 2)

1. Top bar: chỉ wordmark (**không có “Bỏ qua”**).
2. Khiên lớn: 2 vòng tròn đồng tâm 236/176 viền `success` 10%/18%, tròn 120 `successTint` chứa `shield-check` 64 nét 1.75 `success`.
3. Tiêu đề **“Riêng tư tuyệt đối.”** (Barlow 44/700).
4. Card danh sách 3 dòng (min cao 56, divider):
   - `video-off` `success` — “Video không bao giờ rời máy”
   - `wifi-off` `success` — “Tập được khi không có mạng”
   - `sparkles` `accent` — “Tập xong, AI nhận xét ngay từ số liệu — video không bao giờ rời máy.”
5. Ghi chú: “Có thể tắt AI nhận xét bất cứ lúc nào trong Cài đặt.” (13 `text3`).
6. Chỉ báo trang (chấm 3). **[Bắt đầu tập]** primary (icon play) → lưu `onboardingDone = true` → `/home`.

Hành vi chung: vuốt trái/phải, chỉ báo chạy theo ngón tay. **Bỏ qua** → `/home`. Quyền camera **không** hỏi ở onboarding.

### 5.4 Quyền camera

#### 5.4.1 Pre-permission sheet (`CameraPermissionSheet`)
Hiện khi bấm **BẮT ĐẦU** lần đầu và `status == notDetermined`. Nền: màn trước + scrim 60%.
- Icon tròn 64 `accentTint` chứa `camera` 30 `accent`.
- Tiêu đề: **“Cho RepCoach AI dùng camera”** (Inter 28/700).
- Mô tả: “Camera trước giúp đếm rep và nhận diện tư thế. Ngay sau đây iPhone sẽ hỏi quyền, hãy chọn “Cho phép”.” (Android: thay “iPhone” bằng “điện thoại”.)
- 2 dòng (icon 20 `success` + 15/500):
  - `shield-check` — “Hình ảnh được xử lý tức thì trên máy, không lưu, không gửi đi”
  - `eye` — “Camera chỉ bật khi bạn đang tập”
- **[Tiếp tục]** primary → gọi `Permission.camera.request()` → granted: vào `/workout`; denied: đóng, ở lại; permanentlyDenied: `/camera-denied`.
- **[Để sau]** ghost → đóng sheet.

#### 5.4.2 Chưa có quyền camera (`/camera-denied`)
- Top: nút **[×]** 48 → pop.
- Minh họa: vòng nét đứt 200 (`rgba(255,255,255,0.14)`), tròn 136 `surface` chứa `camera-off` 56 `text2`, huy hiệu tròn 48 `accent` (icon `rotate-ccw` 22 `onAccent`) góc dưới phải có vành 6 px `bg`.
- Tiêu đề **“Chưa có quyền camera”** (28/700, căn giữa).
- Mô tả: “Không sao cả. RepCoach AI cần camera để đếm rep, và bạn có thể bật lại trong vài giây.”
- Card 3 bước (dòng cao 48, số tròn 24 `surface2`):
  1. “Mở Cài đặt”
  2. “Chọn RepCoach AI”
  3. “Bật Camera” (kèm switch minh họa màu `success` bật)
- **[Mở Cài đặt ↗]** primary (icon `external-link`) → `openAppSettings()`.
- **[Để sau]** ghost → `/home`.
- Khi app resume và quyền đã bật → tự vào `/workout`.

### 5.5 Home — tab Tập (`/home`)

**Có dữ liệu:**
1. Status bar.
2. Header (padding 12/24/16): caption ngày “THỨ BẢY, 26 THÁNG 9” (12/600 UPPERCASE `text3`); lời chào **“Chiều nay tập nhé, Thanh?”** (28/700). Phải: wordmark nhỏ 16 `text3` (có mark icon).
   - Lời chào theo giờ: 05–10:59 “Sáng nay tập nhé, {tên}?”, 11–13:59 “Trưa nay tập nhé, {tên}?”, 14–17:59 “Chiều nay tập nhé, {tên}?”, 18–04:59 “Tối nay tập nhé, {tên}?”. Không có tên → bỏ “, {tên}”.
3. **Card hero** (`surface`, padding 18): trái icon `flame` 26 `accent` + “5” Barlow 52/800, dưới “ngày liên tiếp” 14/500 `text2`. Phải “90” 52/800 `accent` + “rep tuần này”. Dưới: mini bar chart 7 ngày (T2…CN), cột cao 56: có tập = `rgba(200,255,46,0.45)`, buổi gần nhất = `accent`, không tập = `#26262A` cao 6%, ngày tương lai = nét đứt; nhãn 11/600 (`text` cho hôm nay, `text3` khác). Dữ liệu mẫu: T2 20, T3 22, T4 25, T5 23, T6 0, T7 0 (hôm nay), CN tương lai → tổng **90**.
4. **Card “BUỔI GẦN NHẤT”** (bấm được → `/history/:id`): phải “2 ngày trước ›”. Hàng: “Hít đất” 16/600 + badge “Đạt mục tiêu”; bên phải “23/20” (40/800, “/20” `text3`) + “rep”, vạch chia, “82” `accent` + “Điểm form”. Dưới vạch: icon sparkles 16 + trích AI 1 dòng ellipsis: “Xuống đủ sâu, nhịp đều. Giữ hông thẳng ở 5 rep cuối.”
5. **Dock cố định** (padding 12/20/16, gap 8):
   - Selector **[Bài đang chọn · Hít đất ▾]** cao 64, pill, nền `accentTint` 10%, viền `rgba(200,255,46,0.4)`, chữ `accent`: tròn 44 `bg` chứa glyph 30; cột “Bài đang chọn” 12/500 `text2` + “Hít đất” 17/700; chevron-down 22 → `/exercises`.
   - **[TẬP NGAY]** `HugeCtaButton` 80 → mở sheet Kế hoạch hôm nay (§5.7).
6. Tab bar (Tập active).

**Người mới (không có buổi nào):**
- Lời chào không tên “Chiều nay tập nhé?”.
- Card trống lấp đầy: minh họa skeleton front (vai–khuỷu–cổ tay) trong vùng tròn `accentTint` 6% + số “1” Barlow 44 `accent`; tiêu đề **“Buổi đầu tiên chỉ mất 2 phút”** (22/700); mô tả “Dựng điện thoại dọc trước mặt, bấm Tập ngay. Chuỗi ngày tập và biểu đồ tuần sẽ hiện ở đây.”; privacy badge tinted “Xử lý trên máy · không cần tài khoản”.
- Dock + tab bar giữ nguyên vị trí.

### 5.6 Chọn bài tập (`/exercises`)

1. Top: **[‹]** 48 (“Quay lại”) → pop.
2. Tiêu đề **“CHỌN BÀI TẬP”** (Barlow 40/700) + “1 bài có sẵn · 4 bài sắp ra mắt” (14 `text2`).
3. Card lớn **Hít đất** (đã chọn, viền 2 px `accent`, nền `accentTintSoft`, padding 16): tile 72 glyph 46; “Hít đất” 20/700 + badge “Có sẵn”; icon camera 15 `accent` + “Camera trước · máy dựng dọc” 13/500 `text`; “Cách ~1–1,5 m” 13 `text2`; check tròn góc phải.
4. Lưới 2 × 2 (gap 10) `ExerciseTile` sắp ra mắt:
   - Squat — “Camera trước · máy dựng dọc”
   - Gập bụng — “Bên hông · máy dựng ngang”
   - Curl tạ — “Camera trước · máy dựng dọc”
   - Jumping jack — “Camera trước · máy dựng dọc”
   Chạm → toast “Sắp ra mắt”.
5. Đáy: **[Chọn Hít đất]** primary 56 → lưu bài đã chọn → pop về Home.

### 5.7 Kế hoạch hôm nay (`PlanTodaySheet`, modal bottom sheet)

Mở khi bấm **TẬP NGAY**. Tiêu đề động theo bài.

**Mặc định:**
1. Drag handle.
2. Header: **“HÍT ĐẤT HÔM NAY”** (Barlow 40/800, UPPERCASE `{exercise.name} hôm nay`) + “Mục tiêu số rep” (14/500 `text2`); phải nút **[×]** 48 `text2`.
3. `RepGoalStepper` giá trị mặc định = mục tiêu lần trước (20). Helper “Chạm vào số để nhập”.
4. `GoalChip` 10 · 20 (“Lần trước”) · 30 · 50.
5. Nhắc góc máy: khối `surface2` r16, tile 40 r10 `surface` chứa `smartphone` 22 `accent` + “Dựng máy trước mặt, cách ~1–1.5m” 14/500.
6. **[BẮT ĐẦU]** `LargeCtaButton` 64 (Barlow 28/800).
7. **[× Tập tự do (không mục tiêu)]** ghost 48 (icon x 18).

**Đang nhập bàn phím:** sheet đẩy lên sát bàn phím số; ẩn nhắc góc máy + nút BẮT ĐẦU/Tập tự do; ô số viền `accent` + caret; helper “Nhập từ 1 đến 999”; toolbar “Mục tiêu rep · 1–999” / “Xong”. Không chip nào chọn khi giá trị lẻ (vd 35).

**Lỗi giá trị:** vd “1200” — số và viền `danger`, cỡ 72; helper icon + “Nhập số từ 1 đến 999”; “Xong” khóa. Bấm − khi > 999 kẹp về 999.

Hành vi:
- **BẮT ĐẦU** → lưu `goal` → kiểm tra quyền camera: chưa hỏi → §5.4.1; granted → `/workout?goal=20`; permanentlyDenied → §5.4.2.
- **Tập tự do** → như trên với `goal = null`.

### 5.8 Màn camera trước khi tập (`/workout`, phase positioning → countdown)

Toàn màn full-bleed camera trước (portrait, mirror), luôn dark. Lớp phủ gradient tối nửa trên (0–380/500). Bố cục chung (dùng cho mọi bài):
- 0–54: safe area / status bar.
- 54–116: **Header** — `PrivacyBadge.glass` “Xử lý trên máy” (trái), tên bài “Hít đất” (giữa, 14/600), **[×]** 48 glass (phải) → dừng camera, về Home.
- 116–380: **Vùng thông điệp** — banner, checklist, đếm ngược nhỏ, số rep khi tập.
- 392–818: **Vùng thân người** — chỉ guide zone + skeleton. Không đặt chữ hay nút.

#### C1 Positioning
- `GuideZone` nét đứt trắng 60% + silhouette plank mờ.
- `CameraBanner` cam, ví dụ theo lỗi phát hiện (ưu tiên từ trên xuống):
  - “Lùi ra xa thêm một chút” / phụ “Chưa thấy trọn hai tay”
  - “Đưa hai tay vào khung” / phụ “Dịch sang trái một chút” (hoặc “phải”)
  - “Không thấy hông” / phụ “Hạ máy thấp hơn hoặc lùi xa hơn”
  - (ánh sáng) “Phòng hơi tối” / phụ “Bật thêm đèn hoặc quay mặt về phía sáng”
- Icon banner theo lỗi: `hand` (tay), `move-horizontal`/`arrow-left` (lệch), `scan` (không thấy hông), `sun` (sáng).
- `SetupChecklist`: “Thấy vai & hai tay”, “Thấy hông”, “Đủ sáng” — mục chưa đạt: chấm cam + “· chưa đạt”.
- Skeleton hiển thị khi phát hiện được.

#### C2 Ready
- Khi đủ 3 mục: guide zone viền liền `success`, rung nhẹ 1 lần (`HapticFeedback.mediumImpact`).
- Banner xanh: progress ring nhỏ (vòng ổn định đầy trong 1,5 s) + **“Giữ nguyên…”** + phụ “Đã thấy đủ người”.
- Checklist 3 mục đều tích xanh.
- Lệch khỏi khung trước khi đầy → quay về C1.
- Đầy → nếu bài chưa hiệu chỉnh: C3; nếu đã: C4.

#### C3 Calibrating (chỉ lần đầu mỗi bài)
- Tiêu đề: **“Làm 3 cái thật tự nhiên để app hiểu biên độ của bạn”**.
- 3 chấm tiến độ lớn: đã xong (nền `accent` + tích), đang làm (viền `accent`, số “2”), chưa làm (xám, số “3”).
- Dòng “Cái thứ 2 / 3”.
- Chú thích: “Không tính vào số rep · chỉ làm một lần”.
- Guide zone giữ viền `success` mảnh. Xong 3 cái → lưu `calibration[exerciseId]` → C4.

#### C4 Countdown
- Lớp tối 30% toàn màn. Số **3 · 2 · 1** Barlow 300/800 ở giữa, mỗi số pulse, TTS đọc “Ba”, “Hai”, “Một”. Phụ “Vào tư thế”.
- Hết → phase `active`.

### 5.9 HUD — đang tập (`/workout`, phase active)

Layout (camera full-bleed + scrim trên 0–500 + scrim dưới 160 px):
1. Thanh tiến độ mảnh: top 56, left/right 24, cao 4 (chỉ khi có mục tiêu).
2. Header top 68, cao 44: `PrivacyBadge.glass` trái; nút loa phải (glass, cao 44, icon `volume-2` 20) — khi đang đọc hiện chữ số đang đọc “"Mười bốn"” màu `accent`. Chạm → bật/tắt giọng đọc.
3. Dòng thông tin top 122, căn giữa, 16/600 tabular: icon `timer` 17 `text2` + “01:32” · “Set 2” · “Hít đất” (dấu “·” màu `textDisabled`).
4. `HudRepCounter` top 156: “14” + “/ 20”; dưới “Còn 6”.
5. `PostureChip` top 378.
6. `CueToast` top 436 (khi có).
7. Điều khiển đáy (bottom 40, căn giữa, gap 40): **[Tạm dừng]** tròn 64 glass (icon pause) + nhãn 12/600; **[Giữ để kết thúc]** tròn 64 glass (icon square `danger`) + nhãn “Giữ để kết thúc”.
   - Giữ: nền `rgba(255,90,95,0.28)`, scale 0.94, vòng `danger` 4 px (r 33) chạy trong 1 s; nhãn “Đang giữ…” (`#FF8F92`); pill hint phía trên “Giữ thêm chút nữa”. Thả sớm → hủy. Đủ 1 s → phase `ending`.
   - Chạm nhanh (không giữ) → chỉ hiện hint “Giữ để kết thúc” 1,5 s.
8. Mỗi rep: pulse số, flash viền màn hình, haptic light, TTS số.

Trạng thái phụ:
- **Mất tư thế**: chip cam “Mất tư thế – tạm dừng đếm”, số rep + thanh tiến độ xám `#8A8A90`/`text3`, khớp lệch cam, cue “Giữ thân thẳng”. Không đếm cho tới khi tư thế tốt lại.
- **Set**: đứng yên 5 s (không có rep) → kết thúc set hiện tại, set tiếp theo bắt đầu khi có rep mới; “Set N” tăng.

#### Tập tự do (goal == null)
- Không có thanh tiến độ, không “/ 20”, không “Còn…”. Dưới số: “rep” (18/600 `#C9C9CE`).
- Dòng thông tin thêm “· Tự do” (`text2`): “02:48 · Set 1 · Hít đất · Tự do”.
- Chip tư thế top 352.

### 5.10 HUD — Tạm dừng (phase paused)

- Camera + HUD mờ dưới lớp `rgba(11,11,12,0.6)` + blur 6. Privacy badge glass vẫn ở top 68 trái.
- Nội dung (top 140, padding 24, căn giữa, gap 20):
  - Badge “Đã tạm dừng” (icon pause, nền `rgba(255,255,255,0.1)`, r8, 14/600).
  - “14” Barlow 120/800 `accent` + “/ 20” 36/700 `#C9C9CE`.
  - “01:32 · Set 2 · Hít đất” (16/500 `#C9C9CE`).
  - **[TIẾP TỤC]** `LargeCtaButton` 72 (icon play 26, Barlow 30/800) → `active`.
  - **[Kết thúc buổi tập]** destructive tint 56 (chữ `dangerText`) → `ending` (một chạm, không cần giữ).
  - Ghi chú: “Camera vẫn mở nhưng không đếm. Tự kết thúc sau 5 phút.” (13 `text2`).
- Đồng hồ dừng. Sau 5 phút → tự `ending`.

### 5.11 HUD — Đạt mục tiêu (overlay goalReached)

Không chặn camera, không dừng đếm.
- Số “20” chuyển `success`, thanh tiến độ 100% `success`, TTS “Hai mươi”, haptic success.
- Confetti nhẹ **chỉ ở mép trái/phải** (x < 30 hoặc > 350, y 160–480), mảnh 6×10/10×5, màu `accent`/`text`/`success`, không phủ thân người, không ở header.
- Banner top 338, left/right 16, r24, nền `rgba(11,11,12,0.8)` + blur, viền `rgba(61,220,151,0.5)`, padding 14, gap 12:
  - Icon tròn 44 `successTint` + `circle-check` 24 + **“Đạt 20! Làm thêm không?”** (20/700, 1 dòng).
  - 2 nút cao 48: **[Kết thúc]** (ghost viền `rgba(255,255,255,0.16)`) → `ending`; **[Tập thêm]** (primary) → ẩn banner, tiếp tục `active` (chế độ vượt mục tiêu).
  - Vạch đếm ngược 3 px `success` ở đáy banner chạy 3 s.
- Hết 3 s không chạm → ẩn banner, tiếp tục đếm như “Tập thêm”.

### 5.12 HUD — Vượt mục tiêu

- “23” `accent` + “/ 20”; dưới: badge `overGoal` “+3 vượt mục tiêu”.
- Thanh tiến độ 100% `success`. Chip tư thế, điều khiển như active.

### 5.13 Đang lưu (phase ending → saving)

Camera tắt ngay. Nền `bg`.
- Top 150, căn giữa, gap 28: vòng 96 `successTint` + vành −14 viền `success` 18% + `circle-check` 48 `success`.
- **“Đã lưu buổi tập”** (28/700) + “Hít đất · 23 rep · 3 set · 4:12” (16/500 `text2`).
- Card AI rút gọn (nếu AI bật): sparkles 20 + **“RepCoach AI đang nhận xét…”** (16/600); thanh tiến độ không xác định 4 px `accent`; 2 thanh skeleton; dòng privacy “Chỉ gửi số liệu tổng hợp (số rep, nhịp, điểm form). Không gửi video.” (13/500 `text2`, icon shield `success`).
- Đáy: ghost **[Xem kết quả ngay]** (15/600 `text2`).
- Sau ~2 s (hoặc bấm) → lần đầu và chưa có consent: Consent sheet (§5.23) → Kết quả; ngược lại → `/results/:id`.
- AI tắt hoặc offline: bỏ khối AI, chuyển thẳng.

### 5.14 Kết quả buổi tập (`/results/:sessionId`)

Cuộn dọc. Nền `bg`. Thanh nút **cố định đáy**.

1. Status bar. Top bar cao 52: **[×]** 48 → `/home`; tiêu đề giữa “Kết quả buổi tập” (16/600).
2. **Hero** (căn giữa, gap 16): `ProgressRing` 232/16 với “23” (112/800 `text`) “/20” (32/700 `text3`) — vòng đầy + cung `success` 15%. Badge `goalMet` “Đạt mục tiêu +3”. Dòng phụ: “Hít đất · 3 set · 4:12 · Hôm nay 18:40” (14/500 `text2`).
3. **`AiFeedbackCard`** (ngay dưới hero, là điểm nhấn chính). Nội dung mẫu (ready):
   - Tóm tắt: “Vượt mục tiêu 3 rep với biên độ tốt. Set 3 bắt đầu vội hơn hai set đầu.”
   - Tốt: “Xuống đủ sâu ở 21/23 rep.” · “Hai tay đều, lệch trái/phải dưới 5%.”
   - Cải thiện: “5 rep ở set 3 nhanh hơn 1 giây.” · “Hông hơi võng ở 3 rep cuối.”
   - Mục tiêu buổi sau: “24 rep, giữ mỗi rep ≥ 1,5 giây”
4. **`FormScoreCard`**: 82/100 · Biên độ 88 · Nhịp đều 74 · Cân bằng trái/phải 90 · Tư thế ổn định 76.
5. **`RepPaceChart`** “NHỊP TỪNG REP” / “giây / rep”: Set 1 (8 rep), Set 2 (8), Set 3 (7), 5 rep quá nhanh ở set 3.
6. Disclaimer: icon info 14 + “Chỉ mang tính tham khảo tập luyện, không phải lời khuyên y khoa.” (12 `text3`).
7. **Thanh đáy cố định** (padding 12/20/34, nền `bg` 86% + blur, viền trên): **[Xong]** primary flex → `/home` (trong prototype flow đi tới Lịch sử); **[Chia sẻ]** secondary rộng 132 (icon `share`) → `/share/:id`.

**Biến thể dừng sớm (14/20):**
- Ring 70% `accent`, “14” “/20”.
- Badge `partial` “14/20 · 70%”.
- Dòng tích cực (20/600): **“Đã hoàn thành 70% — rất tốt cho hôm nay”**.
- Phụ: “Hít đất · 2 set · 2:48 · Hôm nay 18:40”.
- AI: “Hai set đầu đều và chắc. Dừng khi nhịp bắt đầu chậm là lựa chọn hợp lý.” · Tốt: “Biên độ ổn định ở cả 14 rep.”, “Không có rep nào quá nhanh.” · Cải thiện: “Nghỉ 90 giây giữa hai set để giữ sức.” · Mục tiêu: “16 rep trong 2 set”.
- Form 80: Biên độ 86 · Nhịp đều 82 · Cân bằng 84 · Tư thế ổn định 68. Pace: 2 set (8, 6), “Không có rep nào quá nhanh.”
- Không bao giờ dùng chữ “thất bại”, không màu đỏ/cam cho hero.

**Biến thể tự do:** hero hiển thị số lớn không có “/goal”, ring đầy `accent`, badge `free` (icon `infinity`) “Tập tự do”.

**Card AI theo trạng thái:** `loading` / `ready` / `offline` / `error` / `disabled` (§4.11).

### 5.15 Ảnh chia sẻ story (`/share/:sessionId`)

Tạo ảnh 1080 × 1920 (thiết kế ở 393 × 699, r24 khi xem trước) bằng `RepaintBoundary` → `share_plus`.
- Nền `bg`, nền trang trí: skeleton front nét 3 `accent` opacity 7%.
- Padding 40/32/32. Trên: “26.09.2026” (13/600 `text2`, +0.04em) trái; pill “5 ngày liên tiếp” (icon flame, `accentTint` 10%, `accent` 13/600) phải.
- Giữa: “23” Barlow 240/800 `accent`; **“REP HÍT ĐẤT”** Barlow 44/800; hàng số: “82/100” + “Điểm form”, vạch, “+3” + “Vượt mục tiêu” (36/800 + 13/500 `text2`).
- Khối trích AI: nền `surface` 90%, viền `rgba(200,255,46,0.28)`, r16, icon sparkles 18 + “"Vượt mục tiêu 3 rep với biên độ tốt."” (15/500).
- Đáy: wordmark nhỏ (mark icon + “REPCOACH AI” Barlow 18/800).
- Không chứa ảnh camera hay khuôn mặt.
- Màn xem trước: ảnh story + nút “Chia sẻ” primary + “Lưu ảnh” secondary.

### 5.16 Lịch sử — tab 2 (`/history`)

Cuộn dọc, tab bar cố định.
1. Tiêu đề **“LỊCH SỬ”** (Barlow 40/800).
2. `FilterChip` hàng ngang: **Tất cả** (chọn) · **Hít đất** · Squat / Gập bụng / Curl tạ (mờ + “Sắp ra mắt”).
3. **Card tháng**: “THÁNG 9” caption; “251” (64/800 `accent`) + “rep”; phải “14 buổi tập” + icon flame “5 ngày liên tiếp” (`accent`). Dưới: `MonthHeatmap` (31/8 → 4/10). Dữ liệu tháng 9 (rep/ngày): 2:12, 4:15, 7:18, 9:20, 11:14, 14:22, 16:20, 18:22, 20:18, 21:20, 22:22, 23:25, 24:23 → **tuần 21–27/9 = 20 + 22 + 25 + 23 = 90** (khớp Home).
4. **Card “REP MỖI BUỔI · 30 NGÀY”** (phải: “Hít đất”): `RepsLineChart`, kỷ lục 25 rep ngày 23/9.
5. **Danh sách nhóm theo ngày** (nhãn ngày 13/600 `text2`, gap 8), mỗi dòng `SessionRow`:
   - Tile 44 glyph 30 · dòng 1: số Barlow 22/800 + “·” + trạng thái (icon 15 + chữ 13/600) + badge “Kỷ lục” nếu có · dòng 2: “Hít đất · Form 82 · 4:12 · 18:40” (13/500 `text2`) · dòng 3: sparkles 13 + trích AI 1 dòng ellipsis (13 `#C9C9CE`) · chevron.
   - Dữ liệu mẫu:
     - Thứ Năm, 24/9 — “23/20 · Đạt mục tiêu” · Form 82 · 4:12 · 18:40 · “Xuống đủ sâu, nhịp đều. Giữ hông thẳng ở 5 rep cuối.”
     - Thứ Tư, 23/9 — “25/20 · Đạt mục tiêu” + Kỷ lục · Form 79 · 5:05 · 07:15 · “Kỷ lục mới. Set cuối hơi vội, thử nghỉ lâu hơn.”
     - Thứ Ba, 22/9 — “14/20 · 70%” · Form 80 · 2:48 · 18:40 · “Hai set đầu đều và chắc.” và “8 rep · Tập tự do” · Form 78 · 1:10 · 07:20 · “Buổi ngắn buổi sáng, nhịp ổn định.”
     - Thứ Hai, 21/9 — “20/20 · Đạt mục tiêu” · Form 81 · 3:40 · 18:55 · “Đạt đúng mục tiêu, biên độ đều cả 20 rep.”
     - Chủ Nhật, 20/9 — “18 rep · Tập tự do” · Form 77 · 3:20 · 19:05 · “Nhịp ổn định, biên độ giảm nhẹ về cuối.”
   - Trạng thái: đạt = `circle-check` `success` “Đạt mục tiêu”; dừng sớm = `trending-up` `accent` “70%”; tự do = `infinity` `#C9C9CE` “Tập tự do”.
   - **Vuốt trái** (`Dismissible`/`Slidable`) lộ vùng đỏ rộng 100 (`danger`, icon trash 22 + “Xóa” 13/700 `onAccent`); dòng dịch −92. Thả quá ngưỡng hoặc bấm “Xóa” → xóa + toast “Đã xóa buổi tập” với **[Hoàn tác]** 5 s.
   - Chạm dòng → `/history/:id`.
6. Tab bar (Lịch sử active).

**Empty state:** tiêu đề + chip lọc giữ nguyên; minh họa lưới 7 × 4 ô 22 (`surface2`) có 1 ô `accent` + quầng; **“Chưa có buổi tập nào”** (22/700); “Mỗi buổi tập sẽ hiện ở đây, kèm biểu đồ và nhận xét AI. Buổi đầu tiên chỉ mất 2 phút.”; **[Tập ngay]** primary (icon play) → `/home` + mở sheet kế hoạch.

### 5.17 Chi tiết buổi tập (`/history/:sessionId`)

Dùng lại **nguyên layout Kết quả** (§5.14) với khác biệt:
- Top bar: **[‹]** (“Quay lại”) → pop; tiêu đề “Thứ Năm, 24/9 · 18:40”.
- Card AI hiển thị nhận xét đã lưu (không gọi lại, trừ trạng thái offline/error có “Thử lại”).
- Thanh đáy: **[Chia sẻ]** secondary flex + nút tròn 56 destructive tint (icon trash, label “Xóa buổi tập”) → dialog xác nhận “Xóa buổi tập này?” / “Không thể hoàn tác.” / **[Hủy]** · **[Xóa]** → pop + toast Hoàn tác.

### 5.18 Cài đặt — tab 3 (`/settings`)

Cuộn dọc. Tiêu đề **“CÀI ĐẶT”**. Các nhóm (gap 24):

**TẬP LUYỆN**
- `volume-2` **Đọc số bằng giọng nói** — “Đọc số mỗi rep và nhắc tư thế” — switch (mặc định bật).
- `vibrate` **Rung mỗi rep** — switch (bật).
- `bell` **Âm thanh** — “Tiếng báo bắt đầu và kết thúc set” — switch (tắt).
- `ruler` **Hiệu chỉnh lại biên độ** — “Theo từng bài tập” — chevron → `/settings/calibration`.

**AI & QUYỀN RIÊNG TƯ**
- `sparkles` **RepCoach AI nhận xét sau mỗi buổi** — “Tập xong, app tự gửi số liệu tổng hợp để AI nhận xét.” — switch (mặc định bật sau consent).
- Khối preview (nền `bg`, r12, viền `border`, padding 12×14): “Ví dụ số liệu gửi đi sau một buổi” (12/600 `text2`); 5 dòng tích `success`: Bài tập — Hít đất; Tổng rep — 23; Thời gian — 4:12; Nhịp — 1,5 giây/rep; Điểm form — 82. Vạch chia. Dòng khiên `success`: “**Không bao giờ gửi** video, ảnh hay khuôn mặt. Hình ảnh camera chỉ xử lý trên máy.” (Dùng số liệu buổi gần nhất; ẩn khối khi toggle tắt.)
- `lock` **Chính sách bảo mật** — icon external → mở URL trong trình duyệt.

**DỮ LIỆU**
- `trash-2` (icon `danger`) **Xóa toàn bộ lịch sử** (chữ `dangerText`) — “14 buổi tập · chỉ lưu trên máy này” — chevron → dialog §5.21.

**VỀ APP**
- **Phiên bản** — “1.0.0 (42)” (`text2`).
- `message-circle` **Gửi góp ý** — chevron → mở email/form.
- `star` **Đánh giá app** — external → `in_app_review`.

Cuối: wordmark mờ (`textDisabled`/`text3`). Tab bar (Cài đặt active).

### 5.19 Hiệu chỉnh biên độ (`/settings/calibration`)

- Top: **[‹ Cài đặt]** (ghost, `accent` 16/500).
- **“HIỆU CHỈNH BIÊN ĐỘ”** (Barlow 36/800) + “App học biên độ của bạn qua 3 rep đầu tiên của mỗi bài. Đặt lại khi bạn đổi chỗ tập, đổi góc máy hoặc thấy app đếm thiếu.”
- Card danh sách (dòng cao ≥ 72): tile 44 glyph; tên 16/600; phụ:
  - Hít đất — `circle-check` `success` “Đã hiệu chỉnh · 02/9” — nút secondary 40 **[Đặt lại]** (icon `rotate-ccw`).
  - Squat / Gập bụng / Curl tạ — `clock` “Sắp ra mắt” (mờ, không nút).
- Sau khi đặt lại: dòng phụ đổi “Sẽ hiệu chỉnh ở buổi tập tiếp theo” + toast/khối xác nhận “Sau khi đặt lại: “Sẽ hiệu chỉnh ở buổi tập Hít đất tiếp theo””.

### 5.20 (dành riêng) — Chọn giao diện
Chưa có trong v1 (app mặc định dark). Để trống.

### 5.21 Dialog “Xóa toàn bộ lịch sử?” (`TypeToConfirmDialog`)

- Nền: Cài đặt + scrim 66%. Dialog: left/right 20, top 120, r28, `surface`, viền `rgba(255,255,255,0.1)`, padding 22/20/16, gap 16.
- Icon tròn 48 `dangerTint` 14% + trash 24 `danger`.
- **“Xóa toàn bộ lịch sử?”** (22/700) + “14 buổi tập, biểu đồ và nhận xét AI sẽ bị xóa khỏi máy này. Không thể hoàn tác.” (15 `text2`).
- Nhãn: “Gõ **XÓA** để xác nhận” (XÓA trong khung mono `surface2`).
- Ô nhập cao 52, r12, nền `bg`, mono 18/700 +0.12em, autofocus, bàn phím chữ in hoa. Viền `accent` khi chưa khớp, `danger` khi khớp.
- **[Hủy]** ghost viền · **[Xóa vĩnh viễn]** (flex 1.3): khóa (`surface3`/`text3`) cho tới khi nhập đúng “XÓA” (không phân biệt hoa thường, chấp nhận cả “XOA”); khi khớp: nền `danger`, chữ `onAccent`.
- Xóa → xóa DB local + reset streak → đóng → toast “Đã xóa toàn bộ lịch sử”.

### 5.22 (dành riêng) — Ngôn ngữ giọng đọc
Chưa có trong v1.

### 5.23 Consent AI (`AiConsentSheet`)

Hiện **một lần**, lần đầu kết thúc buổi tập (sau màn Đang lưu, trước Kết quả), nếu `aiConsent == unknown`. Nền: màn Kết quả + scrim 62%.
- Tile 56 r16 `accentTint` + sparkles 28 `accent`.
- **“Cho RepCoach AI nhận xét buổi tập?”** (26/700, balance).
- “Tập xong, app gửi số liệu tổng hợp để AI nhận xét ngay tại màn kết quả.” (16 `text2`).
- Chip những gì được gửi (cao 30, `surface2`, icon check 14 `success`): Bài tập · Tổng rep · Thời gian · Nhịp · Điểm form.
- Dòng khiên `success` 18: “Không gửi video, ảnh hay khuôn mặt” (14/600).
- **[Bật nhận xét AI]** primary 56 → `aiConsent = granted`, `aiEnabled = true`, gửi ngay → Kết quả (card loading → ready).
- **[Để sau]** ghost → `aiConsent = deferred`, `aiEnabled = false` → Kết quả với card `disabled`.
- Chú thích: “Đổi bất cứ lúc nào trong Cài đặt” (12 `text3`).

---

## 6. Điều hướng (routes)

Dùng `go_router` với `StatefulShellRoute` cho 3 tab.

```
/                      → redirect: onboardingDone ? /home : /onboarding
/onboarding            OnboardingScreen (PageView 3 trang)
/camera-denied         CameraDeniedScreen (fullscreen)

ShellRoute (AppTabBar)
  /home                HomeScreen                (tab Tập)
  /history             HistoryScreen             (tab Lịch sử)
    /history/:id       SessionDetailScreen       (push, ẩn tab bar)
  /settings            SettingsScreen            (tab Cài đặt)
    /settings/calibration CalibrationScreen      (push)

/exercises             ExercisePickerScreen      (push, fullscreen)
/workout?exercise=pushup&goal=20
                       WorkoutScreen (camera + HUD, fullscreen, portrait-lock, dark)
/results/:id           ResultsScreen (replace workout; back → /home)
/share/:id             ShareStoryScreen (modal fullscreen)

Modal (không phải route):
  PlanTodaySheet        từ Home “TẬP NGAY”
  CameraPermissionSheet từ PlanTodaySheet “BẮT ĐẦU”
  AiConsentSheet        từ Workout (saving) trước /results
  TypeToConfirmDialog   từ Settings “Xóa toàn bộ lịch sử”
  ConfirmDeleteSession  từ SessionDetail
```

Luồng chính:

```
Onboarding 1 ─Tiếp tục→ 2 ─Tiếp tục→ 3 ─Bắt đầu tập→ Home
      └──────Bỏ qua────────┘
Home ─pill Hít đất→ Chọn bài ─Chọn Hít đất→ Home
Home ─TẬP NGAY→ PlanTodaySheet ─BẮT ĐẦU / Tập tự do→
   ├─ quyền chưa hỏi → CameraPermissionSheet ─Tiếp tục→ (OS dialog)
   │        ├─ granted → Workout
   │        └─ permanentlyDenied → CameraDenied ─Mở Cài đặt→ OS Settings
   └─ granted → Workout
Workout: positioning → ready → (calibrating) → countdown → active ⇄ paused
         active → goalReached(overlay) → active(over goal)
         active/paused ─Kết thúc→ saving ─(consent lần đầu)→ Results
Results ─Xong→ Home   ─Chia sẻ→ ShareStory   ─×→ Home
History ─dòng→ SessionDetail ─‹→ History
Settings ─Hiệu chỉnh→ Calibration   ─Xóa toàn bộ→ TypeToConfirmDialog
```

Back Android: trong Workout active → mở trạng thái paused (không thoát). Trong paused → hỏi xác nhận kết thúc. Trong Results → Home.

---

## 7. State machine `WorkoutPhase`

```dart
enum WorkoutPhase {
  positioning,  // C1
  ready,        // C2 (đếm 1,5 s giữ yên)
  calibrating,  // C3 (lần đầu mỗi bài)
  countdown,    // C4 (3·2·1)
  active,       // HUD (có hoặc không mục tiêu)
  paused,       // Tạm dừng
  ending,       // vừa bấm kết thúc (camera tắt)
  saving,       // “Đã lưu · AI đang nhận xét…”
  done,         // điều hướng sang Results
  aborted,      // bấm × trước khi có rep → về Home, không lưu
}

@immutable
class WorkoutState {
  final WorkoutPhase phase;
  final String exerciseId;
  final int? goal;              // null = tập tự do
  final int reps;               // tổng rep hợp lệ
  final int setIndex;           // 1-based
  final Duration elapsed;       // không tính khi paused
  final PostureStatus posture;  // good | lost
  final SetupChecks checks;     // shouldersArms, hips, light
  final double readyProgress;   // 0..1 (ready)
  final int calibrationDone;    // 0..3
  final int countdownValue;     // 3,2,1
  final bool goalBannerVisible; // overlay đạt mục tiêu
  final bool goalReachedOnce;
  final String? cue;            // cue realtime đang hiện
  final double endHoldProgress; // 0..1 khi giữ nút kết thúc
  const WorkoutState({...});
  int? get remaining => goal == null ? null : (goal! - reps).clamp(0, goal!);
  int get overGoal => goal == null ? 0 : (reps - goal!).clamp(0, 9999);
}
```

Bảng chuyển trạng thái:

| Từ | Sự kiện | Đến | Side effect |
|---|---|---|---|
| positioning | `checks.allOk` | ready | haptic medium, viền xanh |
| ready | `!checks.allOk` | positioning | reset readyProgress |
| ready | readyProgress == 1 && !calibrated | calibrating | |
| ready | readyProgress == 1 && calibrated | countdown | |
| calibrating | calibrationDone == 3 | countdown | lưu calibration |
| calibrating | `!checks.allOk` (> 2 s) | positioning | |
| countdown | hết 3·2·1 | active | TTS “Ba/Hai/Một”, start timer |
| active | repDetected && posture.good | active | reps++, pulse, flash, haptic, TTS |
| active | reps == goal (lần đầu) | active + goalBannerVisible | TTS, haptic success, 3 s timer |
| active | goalBanner “Kết thúc” | ending | |
| active | goalBanner “Tập thêm” / 3 s | active | ẩn banner |
| active | posture lost | active (posture=lost) | dừng đếm, chip cam |
| active | idle 5 s | active (setIndex++ khi có rep mới) | |
| active | bấm Tạm dừng / back | paused | dừng timer |
| active | giữ Kết thúc 1 s | ending | |
| paused | Tiếp tục | active | |
| paused | Kết thúc buổi tập / 5 phút | ending | |
| any trước active | × | aborted | tắt camera, pop Home |
| active/paused | × (reps == 0) | aborted | |
| ending | — | saving | tắt camera, lưu session local, tạo offline feedback |
| saving | aiEnabled && online | saving | gửi payload |
| saving | 2 s hoặc “Xem kết quả ngay” | done | consent lần đầu nếu cần |
| done | — | → `/results/:id` | |

AI feedback state riêng:

```dart
enum AiFeedbackStatus { disabled, loading, ready, offline, error }
enum AiFeedbackSource { ai, offline }
```

- `saving` & AI bật & có mạng → `loading` → thành công `ready(source: ai)`; timeout 15 s/lỗi → `error` (có Thử lại).
- Không mạng → `offline(source: offline)`; `connectivity_plus` báo online → thử gửi lại, thành công → `ready(ai)`.
- AI tắt → `disabled`.

---

## 8. Mô hình dữ liệu & payload AI

### 8.1 Exercise

```dart
class Exercise {
  final String id;          // 'pushup', 'squat', 'situp', 'curl', 'jumping_jack', 'lunge'
  final String name;        // 'Hít đất', 'Squat', 'Gập bụng', 'Curl tạ', 'Jumping jack', 'Chùng chân'
  final bool available;     // v1: chỉ pushup = true
  final String cameraHint;  // 'Camera trước · máy dựng dọc'
  final String distance;    // 'Cách ~1–1,5 m'
  final String glyphAsset;  // 'assets/exercises/pushup.svg'
  final List<PoseJoint> trackedJoints; // vai, khuỷu, cổ tay, hông
  final double tooFastSeconds;   // 1.0
  final double targetTempoSeconds; // 1.5
}
```

| id | Tên | Có sẵn | Góc camera | Khoảng cách |
|---|---|---|---|---|
| pushup | Hít đất | ✔ | Camera trước · máy dựng dọc | ~1–1,5 m |
| squat | Squat | Sắp ra mắt | Camera trước · máy dựng dọc | 2 m |
| situp | Gập bụng | Sắp ra mắt | Bên hông · máy dựng ngang | 1,5 m |
| curl | Curl tạ | Sắp ra mắt | Camera trước · máy dựng dọc | 1,5 m |
| jumping_jack | Jumping jack | Sắp ra mắt | Camera trước · máy dựng dọc | 2,5 m |
| lunge | Chùng chân | Sắp ra mắt | Bên hông | 2 m |

### 8.2 Session

```dart
class WorkoutSession {
  final String id;
  final String exerciseId;
  final DateTime startedAt;
  final Duration duration;
  final int? goal;
  final List<WorkoutSet> sets;           // mỗi set: List<Rep>
  final int formScore;                   // 0..100 (ước tính)
  final FormBreakdown form;              // rangeOfMotion, tempo, balance, stability
  final AiFeedback? feedback;
  int get totalReps => sets.fold(0, (a, s) => a + s.reps.length);
  bool get goalMet => goal != null && totalReps >= goal!;
}
class Rep { final int durationMs; final double depth; final bool tooFast; }
class AiFeedback {
  final AiFeedbackStatus status;
  final AiFeedbackSource source;
  final String summary;
  final List<String> good;      // ≤ 2
  final List<String> improve;   // ≤ 2
  final String nextGoal;        // 1 dòng đo được
}
```

Lưu local (Drift/Isar). Streak = số ngày liên tiếp có ≥ 1 buổi, tính tới hôm nay hoặc hôm qua.

### 8.3 Payload gửi AI (duy nhất rời máy)

```json
{
  "exercise": "pushup",
  "locale": "vi-VN",
  "goal": 20,
  "total_reps": 23,
  "duration_s": 252,
  "sets": [
    { "reps": 8, "avg_rep_s": 1.71, "too_fast": 0 },
    { "reps": 8, "avg_rep_s": 1.53, "too_fast": 0 },
    { "reps": 7, "avg_rep_s": 0.91, "too_fast": 5 }
  ],
  "avg_tempo_s": 1.5,
  "form_score": 82,
  "form": { "range_of_motion": 88, "tempo": 74, "balance": 90, "stability": 76 },
  "depth_ok_reps": 21,
  "hip_sag_reps": 3,
  "history": { "last_goal": 20, "last_total": 25, "streak_days": 5 }
}
```

Không có ảnh, video, keypoints thô, định danh thiết bị hay tên người dùng. Response mong đợi: `{ summary, good[≤2], improve[≤2], next_goal }` tiếng Việt, ≤ 140 ký tự mỗi dòng.

Offline feedback (quy tắc trên máy): tóm tắt từ `goalMet`/`over`/`tooFast`; tốt từ `depth_ok_reps`; cải thiện từ `too_fast`/`hip_sag_reps`; mục tiêu = `last_total + 1`.

---

## 9. Asset cần export

### 9.1 App icon (Concept 2 · vòng đếm + chấm khớp)

Hình học (lưới 100 × 100): vòng tâm (50, 50) r = 30, nét 10, đầu tròn, cung từ 12 giờ chạy theo kim đồng hồ 300° (khoảng hở 60° ở góc trên trái, 210°–270°); chấm khớp tâm (24.02, 35) r = 9, viền màu nền 3.5. Màu `#C8FF2E` trên gradient chéo `#18181B` → `#0B0B0C`.

| File | Kích thước | Ghi chú |
|---|---|---|
| `assets/icon/ios/AppIcon-1024.png` | 1024 × 1024 | vuông, **không bo**, không alpha |
| `assets/icon/ios/AppIcon-dark-1024.png` | 1024 × 1024 | iOS 18 dark: glyph chanh, nền trong suốt |
| `assets/icon/ios/AppIcon-tinted-1024.png` | 1024 × 1024 | glyph xám `#DADAD2` trên nền đen |
| `android/.../mipmap-anydpi-v26/ic_launcher.xml` | — | adaptive: foreground + background + monochrome |
| `ic_launcher_foreground.png` | 432 × 432 (xxxhdpi, 108 dp) | glyph dịch (4, 4) trong khung 108; nằm trong safe zone 66 dp |
| `ic_launcher_background.png` (hoặc color `#0B0B0C`) | 432 × 432 | gradient `#18181B` → `#0B0B0C` |
| `ic_launcher_monochrome.png` | 432 × 432 | glyph trắng, nền trong suốt |
| `ic_launcher.png` legacy | 48/72/96/144/192 | mdpi → xxxhdpi |
| `play/icon-512.png` | 512 × 512 | Google Play |
| `play/feature-graphic-1024x500.png` | 1024 × 500 | icon 280 + wordmark “RepCoach AI” Barlow 96/800 + tagline “Đếm rep bằng camera. AI nhận xét sau mỗi buổi.” |
| `assets/brand/mark.svg` | vector | mark dùng cạnh wordmark (1.3em) |
| `assets/brand/splash.png` | 1152 × 1152 | glyph giữa, nền `#0B0B0C` (flutter_native_splash) |

Dùng `flutter_launcher_icons` với cấu hình adaptive + monochrome.

### 9.2 Illustration & glyph

| File | Mô tả |
|---|---|
| `assets/exercises/pushup.svg` | Người que nghiêng (đầu tròn r3.5, thân, tay chống) — lưới 48, nét 2.5 round |
| `assets/exercises/squat.svg` | Người que ngồi xổm |
| `assets/exercises/situp.svg` | Người que gập bụng (nằm nghiêng) |
| `assets/exercises/curl.svg` | Người que đứng co tay cầm tạ |
| `assets/exercises/jumping_jack.svg` | Người que dang tay chân |
| `assets/exercises/lunge.svg` | Người que chùng chân |
| `assets/illustrations/onboarding_front_skeleton.svg` | A1: người hít đất nhìn trước + skeleton |
| `assets/illustrations/onboarding_setup_side.svg` | A2: side view plank + điện thoại dọc + nón camera |
| `assets/illustrations/silhouette_plank_front.svg` | Silhouette trắng cho guide zone (dùng opacity 16%) |
| `assets/illustrations/empty_home.svg` | Skeleton front nhỏ + số 1 |
| `assets/illustrations/empty_history.svg` | Lưới 7 × 4 có 1 ô chanh |
| `assets/illustrations/camera_denied.svg` | Có thể dựng bằng widget (Lucide `camera-off` + huy hiệu) |
| `assets/share/story_bg_skeleton.svg` | Nền trang trí story |

Màu minh họa: khối người `#26262A` / `#2E2E33`, skeleton `#C8FF2E`, nền trong suốt. Minh họa là SVG để dùng `flutter_svg`; cho phép thay màu theo theme.

### 9.3 Icon UI (Lucide)

`play, pause, square, x, chevron-left, chevron-right, chevron-down, chevron-up, plus, minus, check, circle-check, circle-x, circle-alert, circle-arrow-up, triangle-alert, info, shield-check, camera, camera-off, video-off, wifi-off, smartphone, user, sun, hand, scan, volume-2, vibrate, bell, ruler, sparkles, target, timer, trending-up, infinity, trophy, flame, dumbbell, history, settings, share, trash-2, rotate-ccw, refresh-cw, external-link, lock, message-circle, star, eye, delete (bàn phím)`.

### 9.4 Âm thanh / giọng

- TTS tiếng Việt (`flutter_tts`, `vi-VN`): số 1–999 (“Một”, “Hai”, … “Mười bốn”, “Hai mươi”, “Hai mươi mốt”…), đếm ngược “Ba”, “Hai”, “Một”, cue (“Xuống sâu hơn”, “Giữ thân thẳng”), “Đạt mục tiêu”.
- `assets/sounds/set_start.wav`, `set_end.wav` (tùy chọn khi bật “Âm thanh”).

---

## 10. Checklist accessibility

**Tương phản**
- [ ] Chữ thường ≥ 4.5 : 1, chữ ≥ 24 pt ≥ 3 : 1 (bảng §2.1/2.2 đã đạt).
- [ ] Light mode: không dùng `#C8FF2E` làm màu chữ; dùng `accentInk #4A6B00`.
- [ ] Chữ trên camera luôn có scrim hoặc nền glass.

**Không chỉ dựa vào màu**
- [ ] Mọi trạng thái có icon + chữ (badge, chip tư thế, toast, pace chart có chấm + chú thích, heatmap có chú thích mức và số ngày).
- [ ] Rep quá nhanh: chấm + màu + dòng tóm tắt bằng chữ.

**Semantics (TalkBack / VoiceOver)**
- [ ] Số rep là `liveRegion`, đọc “14 trên 20 rep, còn 6”.
- [ ] Nút icon có `tooltip`/`semanticLabel`: “Đóng”, “Quay lại”, “Tạm dừng”, “Giữ để kết thúc”, “Giọng đọc số”, “Xóa buổi tập”, “Tăng”, “Giảm”.
- [ ] Nút “Giữ để kết thúc” có hành động thay thế cho screen reader: double-tap mở xác nhận “Kết thúc buổi tập?”.
- [ ] Stepper khai báo `increasedValue/decreasedValue`.
- [ ] Heatmap/biểu đồ có `Semantics(label: ...)` tóm tắt (“Tháng 9: 251 rep, 14 buổi, kỷ lục 25 rep ngày 23/9”).
- [ ] Minh họa trang trí `ExcludeSemantics`.
- [ ] Toast dùng `SemanticsService.announce`.

**Kích thước chữ**
- [ ] Hỗ trợ text scale đến 200% cho màn thường (không cố định chiều cao khối chứa chữ; dùng `Flexible`, `maxLines` + ellipsis có chủ đích).
- [ ] HUD: số rep không scale theo hệ thống (đã cực lớn) — `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.0)` cho số; nhãn phụ tối đa 1.3.
- [ ] Thanh đáy/dock co giãn theo nội dung.

**Vùng chạm**
- [ ] Tối thiểu 48 × 48 (chip 40 cao có vùng chạm mở rộng 48).
- [ ] Điều khiển HUD 64, cách nhau 40.

**Giọng đọc & haptic**
- [ ] Mỗi rep: TTS số + `HapticFeedback.lightImpact`; ready: `mediumImpact`; đạt mục tiêu: `heavyImpact` hoặc pattern success.
- [ ] Tôn trọng toggle Cài đặt “Đọc số bằng giọng nói”, “Rung mỗi rep”, “Âm thanh”.
- [ ] Tạm dừng TTS khi VoiceOver/TalkBack đang đọc để tránh chồng tiếng.
- [ ] Hành động kết thúc cũng có xác nhận bằng giọng “Đã lưu buổi tập”.

**Chuyển động**
- [ ] `disableAnimations` → tắt pulse, flash, shimmer, confetti, số trôi onboarding.

**Khác**
- [ ] Portrait lock cho Workout; các màn khác cũng portrait.
- [ ] Giữ màn hình sáng khi tập (`wakelock_plus`).
- [ ] Hỗ trợ Dynamic Island/notch qua `SafeArea`; HUD tính header từ `padding.top`.
- [ ] Định dạng số và ngày tiếng Việt (`intl`, `vi_VN`).

---

## 11. Package Flutter đề xuất

| Mục đích | Package |
|---|---|
| Font | `google_fonts` (hoặc bundle TTF Barlow Condensed + Inter trong `assets/fonts`) |
| Icon | `lucide_icons_flutter` |
| SVG | `flutter_svg` |
| Điều hướng | `go_router` |
| State | `flutter_riverpod` (hoặc `bloc`) |
| Camera | `camera` |
| Pose detection on-device | `google_mlkit_pose_detection` |
| Quyền | `permission_handler` |
| TTS | `flutter_tts` |
| Haptic | `HapticFeedback` (services) / `vibration` |
| DB local | `drift` hoặc `isar` |
| Mạng | `connectivity_plus`, `dio` |
| Chia sẻ | `share_plus` + `RepaintBoundary.toImage` |
| Đánh giá | `in_app_review` |
| Giữ màn sáng | `wakelock_plus` |
| Swipe xóa | `flutter_slidable` |
| Icon app | `flutter_launcher_icons`, `flutter_native_splash` |
| i18n | `intl` |

Cấu trúc thư mục gợi ý:

```
lib/
  theme/ app_colors.dart app_typography.dart app_spacing.dart app_theme.dart
  widgets/ app_button.dart status_badge.dart privacy_badge.dart progress_ring.dart
           rep_goal_stepper.dart goal_chip.dart exercise_card.dart ai_feedback_card.dart
           form_score_card.dart rep_pace_chart.dart reps_line_chart.dart month_heatmap.dart
           app_toast.dart app_bottom_sheet.dart app_tab_bar.dart settings_row.dart empty_state.dart
  features/
    onboarding/ home/ exercises/ plan/ permission/
    workout/ (workout_controller.dart, workout_phase.dart, camera_view.dart,
              skeleton_overlay.dart, guide_zone.dart, hud_rep_counter.dart,
              posture_chip.dart, cue_toast.dart, hold_to_end_button.dart)
    results/ share/ history/ settings/ ai/
  data/ models/ repositories/ ai_client.dart offline_feedback.dart
  router.dart
  main.dart
```
