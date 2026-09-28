/// Khung hướng dẫn đặt người + chấm điểm tư thế.
///
/// Mục đích không phải trang trí: **chỉ đếm rep khi tư thế đạt**. Bộ video thật
/// cho thấy góc đặt máy ảnh hưởng độ chính xác nhiều hơn mọi lựa chọn model —
/// cùng bài hít đất, cùng thuật toán, tỉ lệ frame đủ keypoint chênh từ 72% lên
/// 99% chỉ vì camera đặt khác. Khung này để người dùng tự sửa trước khi tập.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'core/i18n/app_strings.dart';
import 'exercise.dart';

enum PlacementStatus {
  noPose, // không thấy người
  partiallyOut, // thấy người nhưng thiếu điểm / lọt ra ngoài khung
  tooFar, // người quá nhỏ trong khung
  tooNear, // người quá to, dễ bị khung cắt
  wrongPose, // sai hướng thân (hít đất mà đang đứng, v.v.)
  ready, // đạt -> cho phép đếm
}

extension PlacementStatusX on PlacementStatus {
  bool get canCount => this == PlacementStatus.ready;

  /// Xanh lá = đếm được. Hổ phách = thấy người nhưng chưa đạt. Đỏ = chưa thấy.
  Color get color => switch (this) {
        PlacementStatus.ready => const Color(0xFF22C55E),
        PlacementStatus.noPose => const Color(0xFFEF4444),
        _ => const Color(0xFFF59E0B),
      };

  /// Câu nhắc cho người dùng, theo ngôn ngữ đang chọn.
  String message(S s) => switch (this) {
        PlacementStatus.noPose => s.placeNoPose,
        PlacementStatus.partiallyOut => s.placePartiallyOut,
        PlacementStatus.tooFar => s.placeTooFar,
        PlacementStatus.tooNear => s.placeTooNear,
        PlacementStatus.wrongPose => s.placeWrongPose,
        PlacementStatus.ready => s.placeReady,
      };
}

class PlacementResult {
  const PlacementResult(this.status, {this.detail = ''});
  final PlacementStatus status;
  final String detail;
}

/// Khung hướng dẫn, toạ độ CHUẨN HOÁ 0..1 theo khung hiển thị.
///
/// Dùng toạ độ chuẩn hoá để một định nghĩa chạy đúng trên mọi độ phân giải và
/// mọi tỉ lệ khung hình — đúng bài học từ notebook cũ: ngưỡng pixel cứng thì
/// đổi độ phân giải là hỏng.
class GuideZone {
  const GuideZone(
      {required this.body, required this.hands, required this.label});


  /// Vùng thân người nên nằm gọn bên trong.
  ///
  /// `null` = **không kiểm tra "lọt trong khung"** cho bài này.
  ///
  /// Cần thiết cho hít đất quay trực diện. Đo MediaPipe trên 4 video thật
  /// (1031 khung): các điểm bài tập cần trải x từ **-0,05 đến 1,17** — nghĩa
  /// là cổ tay và khuỷu tay nằm NGOÀI CẢ khung hình, MediaPipe suy ra toạ độ
  /// vượt khỏi [0,1]. Không hình chữ nhật nào chứa nổi.
  ///
  /// Khung cũ Rect(0.20, 0.10, 0.80, 0.95) chặn **400/400 khung** của video
  /// thật: 3–6 trong 8 điểm luôn nằm ngoài, vượt ngưỡng 35% nên trạng thái mãi
  /// là `partiallyOut`. Vì `canCount` chỉ đúng khi `ready`, app KHÔNG đếm được
  /// một rep nào. Người dùng chỉ thấy "Đưa cả người vào trong khung" mãi.
  ///
  /// Bỏ kiểm tra này không làm mất chốt an toàn: điểm ra khỏi ảnh thì
  /// visibility tụt nên bước 1 (thiếu điểm) bắt được, còn khoảng cách tới máy
  /// do bước 3 (bề rộng vai) lo.
  final Rect? body;

  /// Vị trí gợi ý đặt hai bàn tay (null nếu bài không cần).
  final List<Offset>? hands;

  final String label;

  Rect? scaled(Size s) => body == null
      ? null
      : Rect.fromLTRB(body!.left * s.width, body!.top * s.height,
          body!.right * s.width, body!.bottom * s.height);

  List<Offset> handsScaled(Size s) => (hands ?? const [])
      .map((o) => Offset(o.dx * s.width, o.dy * s.height))
      .toList();
}

GuideZone guideFor(ExerciseProfile p, S s) {
  // HÍT ĐẤT — không có khung chữ nhật.
  //
  // Hai lý do, cùng một gốc: đo trên 4 video thật (1031 khung) thấy tay vươn
  // ra tới x = -0,05 và 1,17, tức NGOÀI cả khung hình.
  //
  //  1. Về chức năng: khung nào cũng chặn, nên app không đếm được rep nào.
  //  2. Về hiển thị: một hình chữ nhật mà người tập không thể lọt vào thì
  //     không truyền đạt gì, chỉ che mất hình.
  //
  // Thay bằng MẪU KHUNG XƯƠNG hít đất (`_paintPushUpTemplate`) — dựng từ trung
  // vị 48 khung chống tay thật, nên nó chỉ đúng chỗ cần đặt tay và đặt người.
  // Mẫu đó vốn đã có sẵn trong painter nhưng trước đây là mã chết: nó chỉ vẽ
  // khi `orientation == horizontal`, mà hít đất lại khai `vertical`.
  if (p.id == 'push_up') {
    return GuideZone(
      body: null,
      hands: const [Offset(0.10, 0.765), Offset(0.96, 0.765)],
      label: s.guidePushUp,
    );
  }
  // KÉO XÀ — cũng không có khung chữ nhật. Máy đặt xa nên người nhỏ và nằm ở
  // đâu trong ảnh là tuỳ vị trí xà; thứ cần kiểm là thấy được hai bàn tay, và
  // việc đó `requiredLandmarks` + `countGate` đã làm.
  if (p.id == 'pull_up') {
    return GuideZone(body: null, hands: null, label: s.guidePullUp);
  }
  if (p.orientation == BodyOrientation.horizontal) {
    return GuideZone(
      body: const Rect.fromLTRB(0.06, 0.35, 0.99, 0.82),
      hands: const [Offset(0.10, 0.76), Offset(0.96, 0.76)],
      label: s.guideHorizontal,
    );
  }
  // Bài đứng (cuốn tạ, đẩy tạ qua đầu): người đứng thẳng nên khung dọc hợp lý,
  // và chừa khoảng trống phía trên đầu cho động tác đưa tay lên.
  return GuideZone(
    body: const Rect.fromLTRB(0.20, 0.10, 0.80, 0.95),
    hands: null,
    label: s.guideVertical,
  );
}

/// Góc trục thân (vai giữa -> hông giữa) so với phương ngang, đơn vị độ, 0..90.
double? _torsoAngleFromHorizontal(Landmarks lm, double ml) {
  final sh = lm.mid(
      PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
      minLikelihood: ml);
  final hp = lm.mid(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
      minLikelihood: ml);
  if (sh == null || hp == null) return null;
  final d = sh - hp;
  if (d.distance < 1e-3) return null;
  return (math.atan2(d.dy.abs(), d.dx.abs()) * 180 / math.pi);
}

/// Chấm tư thế người trong khung.
///
/// [viewSize] là kích thước khung hiển thị; toạ độ landmark phải ĐÃ đổi sang hệ
/// toạ độ đó (xem `PoseMapper` trong camera_page.dart).
PlacementResult evaluatePlacement({
  required ExerciseProfile profile,
  required Landmarks? lm,
  required Size viewSize,
  required GuideZone guide,
  required S strings,
}) {
  if (lm == null) return const PlacementResult(PlacementStatus.noPose);

  final ml = profile.minLikelihood;

  // 1) Đủ các điểm bài tập cần
  final missing = profile.requiredLandmarks
      .where((t) => lm.pt(t, minLikelihood: ml) == null)
      .toList();
  if (missing.length > profile.requiredLandmarks.length * 0.25) {
    return PlacementResult(PlacementStatus.partiallyOut,
        detail: '${missing.length} ${strings.detailMissingPoints}');
  }

  // 2) Các điểm chính phải nằm trong khung hướng dẫn — CHỈ khi bài có khung.
  //     Xem chú thích ở `GuideZone.body`: bài hít đất quay trực diện không
  //     dùng được kiểm tra này, vì tay vươn ra ngoài cả khung hình.
  final zone = guide.scaled(viewSize);
  if (zone != null) {
    var outside = 0, checked = 0;
    for (final t in profile.requiredLandmarks) {
      final p = lm.pt(t, minLikelihood: ml);
      if (p == null) continue;
      checked++;
      if (!zone.contains(p)) outside++;
    }
    if (checked == 0) return const PlacementResult(PlacementStatus.noPose);
    if (outside > checked * 0.35) {
      return PlacementResult(PlacementStatus.partiallyOut,
          detail: '$outside/$checked ${strings.detailPointsOutside}');
    }
  }

  // 3) Khoảng cách tới máy, đo qua bề rộng vai so với cạnh ngắn của khung
  final sw = lm.shoulderWidth(minLikelihood: ml);
  if (sw != null) {
    final frac = sw / math.min(viewSize.width, viewSize.height);
    if (frac < profile.shoulderWidthFraction.min) {
      return PlacementResult(PlacementStatus.tooFar,
          detail: '${strings.detailShoulders} '
              '${(frac * 100).toStringAsFixed(0)}%');
    }
    if (frac > profile.shoulderWidthFraction.max) {
      return PlacementResult(PlacementStatus.tooNear,
          detail: '${strings.detailShoulders} '
              '${(frac * 100).toStringAsFixed(0)}%');
    }
  }

  // 4) Hướng thân người
  final ang = _torsoAngleFromHorizontal(lm, ml);
  if (ang != null) {
    // Push-up is viewed from the front camera: shoulder-to-hip runs vertically
    // on screen even though the body itself is horizontal relative to ground.
    const want = 90.0;
    if ((ang - want).abs() > profile.torsoAngleTolerance) {
      return PlacementResult(PlacementStatus.wrongPose,
          detail: '${strings.detailTorsoTilt} ${ang.toStringAsFixed(0)}°');
    }
  }

  // 5) Điều kiện riêng của bài (kéo xà: phải đang bám xà). Chỉ để báo cho
  //    người dùng — bộ đếm tự kiểm lại ở từng khung, xem `countGate`.
  final gate = profile.countGate;
  if (gate != null && !gate(lm, ml)) {
    return PlacementResult(PlacementStatus.wrongPose,
        detail: strings.detailNotHanging);
  }

  return const PlacementResult(PlacementStatus.ready);
}

/// Giữ trạng thái ổn định: chỉ đổi khi trạng thái mới lặp lại đủ [needed] frame.
///
/// Không có bộ này thì màu nhấp nháy liên tục ở ranh giới và người dùng không
/// biết mình đang đạt hay không.
class StatusDebouncer {
  StatusDebouncer({this.needed = 5});

  final int needed;
  PlacementStatus _stable = PlacementStatus.noPose;
  PlacementStatus? _pending;
  int _count = 0;

  PlacementStatus get value => _stable;

  PlacementStatus update(PlacementStatus s) {
    if (s == _stable) {
      _pending = null;
      _count = 0;
      return _stable;
    }
    if (s == _pending) {
      if (++_count >= needed) {
        _stable = s;
        _pending = null;
        _count = 0;
      }
    } else {
      _pending = s;
      _count = 1;
    }
    return _stable;
  }
}
