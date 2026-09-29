/// Định nghĩa bài tập: tín hiệu 1 chiều + ngưỡng + khung hướng dẫn đặt người.
///
/// Cùng cấu trúc với `PROFILES` trong notebook Python: lõi đếm không biết gì về
/// bài tập, mỗi bài chỉ khác cách rút ra một con số từ bộ keypoint.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'core/i18n/app_strings.dart';

/// Hướng thân người mà bài tập yêu cầu — dùng để vẽ khung và chấm tư thế.
enum BodyOrientation { horizontal, vertical }

/// Cách gộp tín hiệu hai tay.
///
/// [perArm] đếm riêng từng tay rồi gộp rep trùng thời điểm — đúng cho bài có thể
/// tập xen kẽ hoặc một tay (cuốn tạ).
///
/// [mean] lấy trung bình hai tay rồi đếm một lần — bắt buộc cho bài mà hai tay
/// ràng buộc cứng cùng pha (hít đất). Đếm riêng ở những bài này sẽ khuếch đại lỗi
/// pose gán nhầm tay trái/phải: hai tay lệch 0.5-0.7 s, không đủ gần để gộp, nên
/// mỗi lần nhầm sinh thêm một rep ma. Đo trên video thật: 120 rep ở nơi thực tế
/// chỉ có ~97.
enum CombineArms { perArm, mean }

class Landmarks {
  Landmarks(this._m);

  final Map<PoseLandmarkType, PoseLandmark> _m;

  factory Landmarks.fromPose(Pose pose) => Landmarks(pose.landmarks);

  PoseLandmark? get(PoseLandmarkType t) => _m[t];

  /// Toạ độ, hoặc null nếu thiếu điểm / độ tin cậy dưới [minLikelihood].
  Offset? pt(PoseLandmarkType t, {double minLikelihood = 0.5}) {
    final l = _m[t];
    if (l == null || l.likelihood < minLikelihood) return null;
    return Offset(l.x, l.y);
  }

  Offset? mid(PoseLandmarkType a, PoseLandmarkType b,
      {double minLikelihood = 0.5}) {
    final pa = pt(a, minLikelihood: minLikelihood);
    final pb = pt(b, minLikelihood: minLikelihood);
    if (pa == null || pb == null) return null;
    return Offset((pa.dx + pb.dx) / 2, (pa.dy + pb.dy) / 2);
  }

  /// Bề rộng vai — thước đo tỉ lệ ổn định nhất, không đổi theo tư thế tay.
  ///
  /// Trả null khi bất thường: lúc pose sập hai vai dồn về một điểm, mọi tín hiệu
  /// chia cho nó sẽ bắn lên hàng chục lần. Notebook đã dính đúng lỗi này.
  double? shoulderWidth({double minLikelihood = 0.5}) {
    final l = pt(PoseLandmarkType.leftShoulder, minLikelihood: minLikelihood);
    final r = pt(PoseLandmarkType.rightShoulder, minLikelihood: minLikelihood);
    if (l == null || r == null) return null;
    final w = (l - r).distance;
    return w < 1e-3 ? null : w;
  }
}

double? _angleAt(Offset? a, Offset? b, Offset? c) {
  if (a == null || b == null || c == null) return null;
  final v1 = a - b, v2 = c - b;
  final n1 = v1.distance, n2 = v2.distance;
  if (n1 < 1e-3 || n2 < 1e-3) return null;
  final cos = (v1.dx * v2.dx + v1.dy * v2.dy) / (n1 * n2);
  return math.acos(cos.clamp(-1.0, 1.0)) * 180 / math.pi;
}

/// Một tín hiệu trả về giá trị cho tay trái và tay phải (null nếu không tính được).
typedef SignalFn = ({double? left, double? right}) Function(
    Landmarks lm, double minLikelihood);

({double? left, double? right}) _elbowAngle(Landmarks lm, double ml) => (
      left: _angleAt(
        lm.pt(PoseLandmarkType.leftShoulder, minLikelihood: ml),
        lm.pt(PoseLandmarkType.leftElbow, minLikelihood: ml),
        lm.pt(PoseLandmarkType.leftWrist, minLikelihood: ml),
      ),
      right: _angleAt(
        lm.pt(PoseLandmarkType.rightShoulder, minLikelihood: ml),
        lm.pt(PoseLandmarkType.rightElbow, minLikelihood: ml),
        lm.pt(PoseLandmarkType.rightWrist, minLikelihood: ml),
      ),
    );

double? _forearmTiltOne(Offset? elbow, Offset? wrist) {
  if (elbow == null || wrist == null) return null;
  final d = elbow - wrist;
  final len = d.distance;
  if (len < 1e-3) return null;
  // y của ảnh hướng xuống, nên (y_khuỷu - y_cổtay) > 0 <=> cổ tay CAO hơn khuỷu
  return d.dy / len;
}

({double? left, double? right}) _forearmTilt(Landmarks lm, double ml) => (
      left: _forearmTiltOne(
          lm.pt(PoseLandmarkType.leftElbow, minLikelihood: ml),
          lm.pt(PoseLandmarkType.leftWrist, minLikelihood: ml)),
      right: _forearmTiltOne(
          lm.pt(PoseLandmarkType.rightElbow, minLikelihood: ml),
          lm.pt(PoseLandmarkType.rightWrist, minLikelihood: ml)),
    );

({double? left, double? right}) _wristAboveNose(Landmarks lm, double ml) {
  final nose = lm.pt(PoseLandmarkType.nose, minLikelihood: ml);
  final sw = lm.shoulderWidth(minLikelihood: ml);
  if (nose == null || sw == null) return (left: null, right: null);
  double? one(PoseLandmarkType t) {
    final w = lm.pt(t, minLikelihood: ml);
    return w == null ? null : (nose.dy - w.dy) / sw;
  }

  return (
    left: one(PoseLandmarkType.leftWrist),
    right: one(PoseLandmarkType.rightWrist)
  );
}

/// Cổ tay có đang ở ngang vai trở lên không — tức là đang bám xà.
///
/// Đo trên video kéo xà thật (IMG_8708, 7359 khung), tính theo
/// (y_vai - y_cổtay) / bề rộng vai:
///
///   - treo thẳng tay:        >= 2.0
///   - lên đỉnh (cằm qua xà): 0.04 .. 1.5 — vai lên sát xà nên gần 0
///   - đứng nghỉ giữa set:    <= 0.07 ở 98% khung
///
/// Ngưỡng -0.3 giữ trọn đỉnh rep mà vẫn loại người đứng thả tay. Ngưỡng 0.5
/// (thử trước) chặn chính đỉnh rep và làm mất 60% số rep.
const _pullUpGateMargin = -0.3;

bool _handsAtBarLevel(Landmarks lm, double ml) {
  final ls = lm.pt(PoseLandmarkType.leftShoulder, minLikelihood: ml);
  final rs = lm.pt(PoseLandmarkType.rightShoulder, minLikelihood: ml);
  final sw = lm.shoulderWidth(minLikelihood: ml);
  if (ls == null || rs == null || sw == null) return false;
  final wrists = [
    lm.pt(PoseLandmarkType.leftWrist, minLikelihood: ml),
    lm.pt(PoseLandmarkType.rightWrist, minLikelihood: ml),
  ].whereType<Offset>().toList();
  if (wrists.isEmpty) return false;
  final wristY = wrists.map((w) => w.dy).reduce((a, b) => a + b) / wrists.length;
  final shoulderY = (ls.dy + rs.dy) / 2;
  return (shoulderY - wristY) / sw > _pullUpGateMargin;
}

/// Điều kiện phải đúng ở TỪNG khung thì khung đó mới được đưa vào bộ đếm.
typedef CountGate = bool Function(Landmarks lm, double minLikelihood);

class ExerciseProfile {
  const ExerciseProfile({
    required this.id,
    required this.name,
    required this.signal,
    required this.signalLabel,
    required this.repHi,
    required this.repLo,
    required this.minAmplitude,
    required this.orientation,
    required this.minLikelihood,
    required this.requiredLandmarks,
    this.combineArms = CombineArms.perArm,
    this.minPeriod = const Duration(milliseconds: 500),
    this.torsoAngleTolerance = 30,
    this.shoulderWidthFraction = const (min: 0.12, max: 0.42),
    this.setupHint = '',
    this.smoothWindow = 5,
    this.startFromTop = false,
    this.countGate,
    this.minRepsPerSet = 1,
  });

  final String id;

  /// Tên và câu hướng dẫn hiển thị: lấy từ `S` theo [id] thay vì lưu cứng ở đây,
  /// để đổi ngôn ngữ không phải dựng lại profile.
  final String name;
  final SignalFn signal;
  final String signalLabel;

  /// Cách gộp hai tay. Xem chú thích ở [CombineArms].
  final CombineArms combineArms;

  /// Khoảng cách tối thiểu giữa hai rep — chặn rep ma do pose giật.
  final Duration minPeriod;

  /// Ngưỡng MẶC ĐỊNH — xem README: phải hiệu chỉnh lại cho MediaPipe.
  final double repHi;
  final double repLo;
  final double minAmplitude;

  final BodyOrientation orientation;
  final double minLikelihood;
  final List<PoseLandmarkType> requiredLandmarks;

  /// Sai lệch cho phép của trục thân so với hướng yêu cầu (độ).
  final double torsoAngleTolerance;

  /// Bề rộng vai tính theo tỉ lệ cạnh ngắn của khung — dùng để chấm khoảng cách.
  final ({double min, double max}) shoulderWidthFraction;

  final String setupHint;

  /// Số khung của trung bình trượt. Cửa sổ tính theo KHUNG nên ở fps thấp nó
  /// dài ra theo thời gian: 5 khung ở 5 fps là 1 s, đủ san phẳng cả đỉnh rep.
  final int smoothWindow;

  /// Xem [RepCounter.startFromTop].
  final bool startFromTop;

  /// Chặn từng khung, KHÔNG qua thời gian ân hạn của trạng thái đặt người.
  ///
  /// Trạng thái đặt người được giữ thêm 2 s sau khi mất (cần cho hít đất, vì ở
  /// đáy pose hay vỡ). Với kéo xà, 2 s đó đúng lúc buông xà: tay gập rồi thả
  /// xuống duỗi thẳng — đủ một vòng để bị tính rep.
  final CountGate? countGate;

  /// Ngưỡng nhóm set cũ, giữ lại để tương thích cấu hình.
  ///
  /// Rep đã được engine xác nhận không còn bị trừ theo độ dài set; set chỉ dùng
  /// để nhóm lịch sử/nhịp tập. Giá trị mặc định vì vậy là 1.
  final int minRepsPerSet;
}

const _upperBody = [
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.leftElbow,
  PoseLandmarkType.rightElbow,
  PoseLandmarkType.leftWrist,
  PoseLandmarkType.rightWrist,
];

const pushUp = ExerciseProfile(
  id: 'push_up',
  name: 'Hít đất',
  signal: _elbowAngle,
  signalLabel: 'góc khuỷu (độ)',
  repHi: 140,
  repLo: 100,
  minAmplitude: 40,
  // Quay TRUC DIEN (camera truoc, dat thap): thân người trong ẢNH gần như thẳng
  // đứng — vai ở trên, hông ở dưới — dù ngoài đời thân nằm ngang.
  //
  // Đo trên 7 video thật: trục thân 75–88° so với phương ngang. Với
  // `horizontal` + dung sai 30°, chỉ 0.0–3.4% frame vượt qua được kiểm tra
  // hướng, nên `PlacementStatus.ready` gần như không bao giờ đạt và app KHÔNG
  // đếm được rep nào. Với `vertical`: 85.7–99.8% frame đạt.
  orientation: BodyOrientation.vertical,
  minLikelihood: 0.4,
  combineArms: CombineArms.mean,
  minPeriod: Duration(milliseconds: 700),
  requiredLandmarks: [
    ..._upperBody,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip
  ],
  shoulderWidthFraction: (min: 0.20, max: 0.65),
  setupHint:
      'Đặt máy thấp trước mặt, chống tay sao cho khung xương trùng với mẫu.',
);

const dumbbellCurl = ExerciseProfile(
  id: 'curl',
  name: 'Cuốn tạ đơn',
  signal: _forearmTilt,
  signalLabel: 'độ nghiêng cẳng tay',
  repHi: 0.15,
  repLo: -0.55,
  minAmplitude: 0.60,
  orientation: BodyOrientation.vertical,
  minLikelihood: 0.5,
  requiredLandmarks: _upperBody,
  setupHint: 'Đứng thẳng, thấy rõ vai và hai cẳng tay trong khung.',
);

const overheadExtension = ExerciseProfile(
  id: 'overhead_extension',
  name: 'Đẩy tạ qua đầu',
  signal: _wristAboveNose,
  signalLabel: 'cổ tay trên mũi',
  repHi: 0.85,
  repLo: 0.60,
  minAmplitude: 0.30,
  orientation: BodyOrientation.vertical,
  minLikelihood: 0.5,
  requiredLandmarks: [..._upperBody, PoseLandmarkType.nose],
  setupHint: 'Chừa khoảng trống phía trên đầu để thấy tạ khi duỗi thẳng tay.',
);

/// Kéo xà — quay trực diện hoặc từ sau lưng, máy đặt xa thấy cả xà.
///
/// Thông số chọn trên hai video thật trong `pull_up/`, xem docs/PULL_UP.md.
/// Góc khuỷu: treo ~175°, đỉnh ~30-60°. Với hi 140 / lo 90, cửa sổ 2, cổng
/// [_handsAtBarLevel] và [startFromTop]: video trực diện đếm đúng 47/47 rep ở
/// cả 5, 7.5 và 15 fps, không rep ma nào lúc lên/xuống xà.
///
/// Tín hiệu "mũi ngang cổ tay" (đúng định nghĩa cằm qua xà) đã thử và thua xa:
/// chia cho bề rộng vai, mà lúc treo vai co giãn nên sai 20+ rep.
const pullUp = ExerciseProfile(
  id: 'pull_up',
  name: 'Kéo xà',
  signal: _elbowAngle,
  signalLabel: 'góc khuỷu (độ)',
  repHi: 140,
  repLo: 90,
  minAmplitude: 40,
  orientation: BodyOrientation.vertical,
  minLikelihood: 0.4,
  combineArms: CombineArms.mean,
  minPeriod: Duration(milliseconds: 800),
  requiredLandmarks: _upperBody,
  // Máy phải đặt xa để thấy cả xà: trên video thật vai chỉ chiếm 12–16%
  // cạnh ngắn, dưới mức tối thiểu 0.12 mặc định ở rìa.
  shoulderWidthFraction: (min: 0.06, max: 0.45),
  smoothWindow: 2,
  startFromTop: true,
  countGate: _handsAtBarLevel,
  minRepsPerSet: 1,
  setupHint: 'Đặt máy cách xà 2–3 m, thấy cả xà và hai bàn tay khi treo.',
);

const allExercises = [pushUp, pullUp, dumbbellCurl, overheadExtension];

/// Tên và câu hướng dẫn theo ngôn ngữ.
///
/// Tra theo `id` chứ không lưu trong profile, để đổi ngôn ngữ không cần dựng lại
/// profile — và để bản ghi cũ trong lịch sử (chỉ lưu `exerciseId`) vẫn hiển thị
/// đúng ngôn ngữ đang chọn.
String exerciseNameFor(String id, S s) => switch (id) {
      'push_up' => s.pushUpName,
      'pull_up' => s.pullUpName,
      'curl' => s.curlName,
      'overhead_extension' => s.overheadName,
      _ => id,
    };

String exerciseHintFor(String id, S s) => switch (id) {
      'push_up' => s.pushUpSetupHint,
      'pull_up' => s.pullUpSetupHint,
      'curl' => s.curlSetupHint,
      'overhead_extension' => s.overheadSetupHint,
      _ => '',
    };

extension ExerciseL10n on ExerciseProfile {
  String localizedName(S s) => exerciseNameFor(id, s);
  String localizedHint(S s) => exerciseHintFor(id, s);
}
