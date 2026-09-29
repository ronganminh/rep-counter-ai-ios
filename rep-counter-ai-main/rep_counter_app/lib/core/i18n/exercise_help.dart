/// Nội dung màn hướng dẫn (nút "?") của từng bài, theo ngôn ngữ.
///
/// Viết theo thứ người tập NHÌN THẤY trên màn hình — các chấm vai, khuỷu, cổ
/// tay của khung xương — chứ không theo số độ: người tập không đo được góc.
/// Mỗi câu phải khớp với code đếm thật (exercise.dart, rep_counter.dart); đổi
/// ngưỡng thì đọc lại chỗ này.
library;

class ExerciseHelp {
  const ExerciseHelp({
    required this.placement,
    required this.watchIntro,
    required this.poses,
    required this.oneRep,
    required this.notCounted,
  });

  final List<String> placement;
  final String watchIntro;

  /// (tư thế, trông thế nào trên khung xương)
  final List<(String, String)> poses;
  final String oneRep;
  final List<String> notCounted;
}

const exerciseHelpVi = <String, ExerciseHelp>{
  'push_up': ExerciseHelp(
    placement: [
      'Dựng điện thoại sát sàn, ngay trước mặt, camera trước hướng về phía bạn.',
      'Chống tay sao cho người khớp với khung xương mẫu: hai chấm vai ở phía trên, hai chấm bàn tay ở hai bên phía dưới.',
      'Khung chuyển xanh lá là app bắt đầu đếm.',
    ],
    watchIntro:
        'Trên màn hình, mỗi tay có 3 chấm nối nhau: vai → khuỷu tay → cổ tay. App chỉ theo dõi đường gấp khúc này.',
    poses: [
      ('Trên cao (chống thẳng tay)',
          '3 chấm vai, khuỷu, cổ tay gần như nằm trên một đường thẳng.'),
      ('Dưới thấp (ngực gần sàn)',
          'Chấm khuỷu bẻ gập ra ngoài, gập khoảng vuông góc hoặc hơn.'),
    ],
    oneRep:
        '1 rep = từ trên cao xuống thấp, rồi đẩy lên cao lại. App cộng +1 lúc tay gần duỗi thẳng trở lại. Hạ chưa tới lúc khuỷu gập vuông, hoặc đẩy lên nửa chừng rồi hạ tiếp, thì không tính.',
    notCounted: [
      'Mất dấu người, hoặc rời tư thế quá 2 giây.',
      'Làm quá nhanh: hai lần đẩy lên sát nhau dưới 0,7 giây.',
      'Rep chỉ được cộng sau khi hoàn tất đủ biên độ; nghỉ giữa các rep không làm mất số đã đếm.',
    ],
  ),
  'pull_up': ExerciseHelp(
    placement: [
      'Dựng điện thoại cách xà 2–3 m. Quay trực diện hay từ sau lưng đều được.',
      'Khi đang treo, màn hình phải thấy cả xà và hai bàn tay. Tay bị khuất thì app báo "lùi máy ra".',
      'Người trông nhỏ giữa màn hình như khung mẫu là đúng.',
    ],
    watchIntro:
        'App theo dõi 3 chấm vai → khuỷu tay → cổ tay, cộng thêm một điều kiện: hai chấm cổ tay phải ở ngang vai hoặc cao hơn — dấu hiệu bạn đang bám xà.',
    poses: [
      ('Treo',
          'Cổ tay ở tít trên đầu; 3 chấm vai, khuỷu, cổ tay gần như thẳng hàng.'),
      ('Lên đỉnh',
          'Vai kéo lên gần xà; chấm khuỷu gập hẳn xuống dưới, gập hơn góc vuông.'),
    ],
    oneRep:
        '1 rep = từ treo thẳng tay, kéo lên đỉnh, rồi hạ xuống treo thẳng tay lại. App cộng +1 lúc tay duỗi thẳng trở lại.',
    notCounted: [
      'Cổ tay thấp hơn vai (đứng nghỉ, vươn vai, lắc tay).',
      'Lúc nhảy lên bám xà và lúc buông xà: app chỉ bắt đầu theo dõi sau khi bạn đã treo thẳng tay.',
      'Kéo lên chưa tới lúc khuỷu gập hẳn.',
      'Làm quá nhanh: hai lần hạ xuống sát nhau dưới 0,8 giây.',
    ],
  ),
};

const exerciseHelpEn = <String, ExerciseHelp>{
  'push_up': ExerciseHelp(
    placement: [
      'Stand the phone upright on the floor right in front of you, front camera facing you.',
      'Get into position so your body lines up with the guide skeleton: both shoulder dots near the top, both hand dots low on either side.',
      'When the guide turns green, counting has started.',
    ],
    watchIntro:
        'On screen, each arm has 3 connected dots: shoulder → elbow → wrist. The app only watches this bent line.',
    poses: [
      ('Top (arms straight)',
          'Shoulder, elbow and wrist dots are almost in one straight line.'),
      ('Bottom (chest near the floor)',
          'The elbow dot bends outwards, to about a right angle or more.'),
    ],
    oneRep:
        '1 rep = from the top down to the bottom, then back up to the top. The app adds +1 when your arms are nearly straight again. Stopping before the elbows reach a right angle, or pushing only halfway up and going down again, does not count.',
    notCounted: [
      'The app loses track of you, or you leave the position for more than 2 seconds.',
      'Going too fast: two push-ups finishing less than 0.7 s apart.',
      'A rep is only added after a full valid cycle; resting later never removes reps already counted.',
    ],
  ),
  'pull_up': ExerciseHelp(
    placement: [
      'Stand the phone upright 2–3 m from the bar. Front or back view both work.',
      'While hanging, the bar and both hands must be on screen. If your hands are cut off, the app asks you to move the phone back.',
      'Looking small in the middle of the screen, like the guide skeleton, is correct.',
    ],
    watchIntro:
        'The app watches the 3 dots shoulder → elbow → wrist, plus one condition: both wrist dots must be level with your shoulders or higher — the sign that you are holding the bar.',
    poses: [
      ('Hang',
          'Wrists high above your head; shoulder, elbow and wrist dots almost in a straight line.'),
      ('Top',
          'Shoulders pulled up near the bar; the elbow dot bends right down, past a right angle.'),
    ],
    oneRep:
        '1 rep = from a straight-arm hang, pull up to the top, then lower back to a straight-arm hang. The app adds +1 when your arms are straight again.',
    notCounted: [
      'Wrists below your shoulders (resting, stretching, shaking out your arms).',
      'Jumping up to the bar and dropping off: the app only starts watching once you hang with straight arms.',
      'Not pulling up far enough for the elbows to bend fully.',
      'Going too fast: two reps finishing less than 0.8 s apart.',
    ],
  ),
};
