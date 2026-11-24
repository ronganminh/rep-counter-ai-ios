/// Chuỗi hiển thị theo ngôn ngữ.
///
/// Dùng một lớp có **trường bắt buộc** thay vì `Map<String, String>` hay ARB:
/// thêm một chuỗi mà quên dịch sang ngôn ngữ kia thì **không biên dịch được**.
/// Với Map hoặc file ARB, lỗi đó chỉ lộ ra khi người dùng mở đúng màn hình đó.
///
/// Cũng không cần `flutter gen-l10n` (sinh code) — dự án chỉ có hai ngôn ngữ, và
/// bước sinh code thêm một chỗ có thể hỏng mà máy dựng code không chạy được.
///
/// v2 (roadmap F-1) thêm gen-l10n từ ARB của gói Final C (`lib/l10n`). Lớp này
/// vẫn là nguồn cho các màn cũ cho tới khi L-1 chuyển dần sang ARB; test
/// `test/l10n/arb_parity_test.dart` giữ cho hai file ARB luôn đủ khoá.
library;

import 'dart:ui' show Locale;

import '../legal/legal_config.dart';
import 'exercise_help.dart';

enum AppLanguage {
  vi('vi', 'Tiếng Việt'),
  en('en', 'English');

  const AppLanguage(this.code, this.label);
  final String code;
  final String label;

  /// Locale for `MaterialApp.locale` and gen-l10n lookups.
  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) =>
      values.where((l) => l.code == code).firstOrNull ?? AppLanguage.vi;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

class S {
  const S({
    required this.language,
    required this.appTitle,
    required this.chooseExercise,
    required this.settings,
    required this.languageLabel,
    required this.pushUpName,
    required this.pushUpSetupHint,
    required this.curlName,
    required this.curlSetupHint,
    required this.overheadName,
    required this.overheadSetupHint,
    required this.pullUpName,
    required this.pullUpSetupHint,
    required this.placeNoPose,
    required this.placePartiallyOut,
    required this.placeTooFar,
    required this.placeTooNear,
    required this.placeWrongPose,
    required this.placeReady,
    required this.guideHorizontal,
    required this.guideVertical,
    required this.hudReps,
    required this.hudSetReps,
    required this.hudSets,
    required this.hudState,
    required this.hudWorking,
    required this.hudResting,
    required this.calibrate,
    required this.calibrateStart,
    required this.calibrateNotEnough,
    required this.calibrateDone,
    required this.calibrateRestored,
    required this.finishTitle,
    required this.finishNoReps,
    required this.finishContinue,
    required this.finishSeeResult,
    required this.resultTitle,
    required this.resultReps,
    required this.resultDuration,
    required this.resultSets,
    required this.resultQuality,
    required this.resultNotEnoughData,
    required this.resultRangeOfMotion,
    required this.resultCadence,
    required this.resultBalance,
    required this.resultAlignment,
    required this.resultAiLoading,
    required this.resultAiOffline,
    required this.resultAiFailed,
    required this.resultAiRetry,
    required this.resultDisclaimer,
    required this.historyTitle,
    required this.historyEmpty,
    required this.cameraPermissionTitle,
    required this.cameraPermissionBody,
    required this.cameraOffMessage,
    required this.cameraUnavailable,
    required this.openSettings,
    required this.retry,
    required this.cancel,
    required this.ok,
    required this.delete,
    required this.repsShort,
    required this.minutesShort,
    required this.secondsShort,
    required this.aiNotConfigured,
    required this.aiTimeout,
    required this.aiOffline,
    required this.aiServerBusy,
    required this.aiUnknownError,
    required this.aiPrivacyNote,
    required this.aiAsk,
    required this.aiAskAgain,
    required this.resultDetail,
    required this.resultDone,
    required this.resultGoalHit,
    required this.resultSavedOk,
    required this.resultTime,
    required this.resultPlacement,
    required this.backHome,
    required this.historyDeleteTitle,
    required this.historyDeleteBody,
    required this.historyDeleted,
    required this.historyOptions,
    required this.historyDeleteAction,
    required this.goalTitle,
    required this.goalQuestion,
    required this.goalHelp,
    required this.goalOther,
    required this.goalEnter,
    required this.goalStart,
    required this.goalSkip,
    required this.onbCameraTitle,
    required this.onbCameraBody,
    required this.onbPrivacyTitle,
    required this.onbPrivacyBody,
    required this.onbSafetyTitle,
    required this.onbSafetyBody,
    required this.onbAccept,
    required this.onbNext,
    required this.onbReadPolicy,
    required this.goalReachedTitle,
    required this.goalDonePrefix,
    required this.goalReachedAsk,
    required this.goalKeepGoing,
    required this.finishSaveHint,
    required this.finishDiscard,
    required this.finishSave,
    required this.finishWorkoutTooltip,
    required this.cameraContinue,
    required this.cameraBack,
    required this.cameraOnDeviceNote,
    required this.cameraOpening,
    required this.cameraOpeningBody,
    required this.cameraUnavailableBody,
    required this.cameraReady,
    required this.cameraPaused,
    required this.cameraPausedBody,
    required this.settingsTitle,
    required this.privacyPolicy,
    required this.termsOfUse,
    required this.healthNotice,
    required this.trainSafelyTitle,
    required this.trainSafelyBody,
    required this.clearHistory,
    required this.clearHistorySub,
    required this.clearHistoryConfirm,
    required this.cannotUndo,
    required this.historyCleared,
    required this.versionLabel,
    required this.detailMissingPoints,
    required this.detailPointsOutside,
    required this.detailShoulders,
    required this.detailTorsoTilt,
    required this.detailNotHanging,
    required this.tagline,
    required this.homeReady,
    required this.homeReadySub,
    required this.exercisesLabel,
    required this.exerciseCardSub,
    required this.debugVideoTest,
    required this.fbTitle,
    required this.fbSourceRules,
    required this.fbStrengths,
    required this.fbImprovements,
    required this.fbNextGoal,
    required this.fbNotEnoughData,
    required this.fbNothingYet,
    required this.fbGoalReached,
    required this.fbSteadyCadence,
    required this.fbGoodRange,
    required this.fbBalancedSides,
    required this.fbGoodCameraSetup,
    required this.fbPoseLostOften,
    required this.fbAmplitudeDropped,
    required this.fbLeftRightUneven,
    required this.fbRepsTooFast,
    required this.fbShortSession,
    required this.aiCoach,
    required this.guidePushUp,
    required this.guidePullUp,
    required this.exerciseHelp,
    required this.helpTooltip,
    required this.helpPlacement,
    required this.helpWatch,
    required this.helpNotCounted,
    required this.hudRecord,
    required this.hudStopRecord,
    required this.hudCalibrateShort,
    required this.hudCalibrateStop,
    required this.hudFinishShort,
    required this.hudHelp,
    required this.legalEffective,
    required this.legalDate,
    required this.privacyIntroBody,
    required this.privCameraTitle,
    required this.privCameraBody,
    required this.privWorkoutTitle,
    required this.privWorkoutBody,
    required this.privAiTitle,
    required this.privAiBody,
    required this.privRetentionTitle,
    required this.privRetentionBody,
    required this.privSecurityTitle,
    required this.privSecurityBody,
    required this.privContactTitle,
    required this.termsIntroPrefix,
    required this.termsIntroSuffix,
    required this.termsPurposeTitle,
    required this.termsPurposeBody,
    required this.termsNotMedicalTitle,
    required this.termsNotMedicalBody,
    required this.termsSafetyTitle,
    required this.termsSafetyBody,
    required this.termsLiabilityTitle,
    required this.termsLiabilityBody,
    required this.termsUseTitle,
    required this.termsUseBody,
    required this.termsChangesTitle,
    required this.termsChangesBody,
    required this.privChildrenTitle,
    required this.privChildrenBody,
    required this.privChoicesTitle,
    required this.privChoicesBody,
    required this.privChangesTitle,
    required this.privChangesBody,
    required this.privAccountTitle,
    required this.privAccountBody,
    required this.privSyncTitle,
    required this.privSyncBody,
    required this.privSocialTitle,
    required this.privSocialBody,
    required this.privCoachTitle,
    required this.privCoachBody,
    required this.privNotifTitle,
    required this.privNotifBody,
    required this.privDeletionTitle,
    required this.privDeletionBody,
    required this.privNoAdsTitle,
    required this.privNoAdsBody,
    required this.termsContactTitle,
    required this.termsContactBody,
  });

  final AppLanguage language;

  final String appTitle;
  final String chooseExercise;
  final String settings;
  final String languageLabel;

  // Bài tập
  final String pushUpName;
  final String pushUpSetupHint;
  final String curlName;
  final String curlSetupHint;
  final String overheadName;
  final String overheadSetupHint;
  final String pullUpName;
  final String pullUpSetupHint;

  // Chấm tư thế
  final String placeNoPose;
  final String placePartiallyOut;
  final String placeTooFar;
  final String placeTooNear;
  final String placeWrongPose;
  final String placeReady;
  final String guideHorizontal;
  final String guideVertical;

  // Màn hình tập
  final String hudReps;
  final String hudSetReps;
  final String hudSets;
  final String hudState;
  final String hudWorking;
  final String hudResting;
  final String calibrate;
  final String calibrateStart;
  final String calibrateNotEnough;
  final String calibrateDone;
  final String calibrateRestored;
  final String finishTitle;
  final String finishNoReps;
  final String finishContinue;
  final String finishSeeResult;

  // Kết quả
  final String resultTitle;
  final String resultReps;
  final String resultDuration;
  final String resultSets;
  final String resultQuality;
  final String resultNotEnoughData;
  final String resultRangeOfMotion;
  final String resultCadence;
  final String resultBalance;
  final String resultAlignment;
  final String resultAiLoading;
  final String resultAiOffline;
  final String resultAiFailed;
  final String resultAiRetry;
  final String resultDisclaimer;

  // Lịch sử
  final String historyTitle;
  final String historyEmpty;

  // Camera / quyền
  final String cameraPermissionTitle;
  final String cameraPermissionBody;
  /// Neutral notice when camera access is off (App Store 5.1.1(iv)).
  final String cameraOffMessage;
  final String cameraUnavailable;
  final String openSettings;
  final String retry;
  final String cancel;
  final String ok;
  final String delete;

  // Đơn vị viết tắt — ghép vào câu, nên tách riêng thay vì viết cứng trong trang
  final String repsShort;
  final String minutesShort;
  final String secondsShort;

  // Nhận xét AI
  final String aiNotConfigured;
  final String aiTimeout;
  final String aiOffline;
  final String aiServerBusy;
  final String aiUnknownError;
  final String aiPrivacyNote;
  final String aiAsk;
  final String aiAskAgain;

  // Trang kết quả
  final String resultDetail;
  final String resultDone;
  final String resultGoalHit;
  final String resultSavedOk;
  final String resultTime;
  final String resultPlacement;
  final String backHome;

  // Lịch sử
  final String historyDeleteTitle;
  final String historyDeleteBody;
  final String historyDeleted;
  final String historyOptions;
  final String historyDeleteAction;

  // Đặt mục tiêu
  final String goalTitle;
  final String goalQuestion;
  final String goalHelp;
  final String goalOther;
  final String goalEnter;
  final String goalStart;
  final String goalSkip;

  // Màn hình giới thiệu
  final String onbCameraTitle;
  final String onbCameraBody;
  final String onbPrivacyTitle;
  final String onbPrivacyBody;
  final String onbSafetyTitle;
  final String onbSafetyBody;
  final String onbAccept;
  final String onbNext;
  final String onbReadPolicy;

  // Man hinh tap + camera
  final String goalReachedTitle;
  final String goalDonePrefix;
  final String goalReachedAsk;
  final String goalKeepGoing;
  final String finishSaveHint;
  final String finishDiscard;
  final String finishSave;
  final String finishWorkoutTooltip;
  final String cameraContinue;
  final String cameraBack;
  final String cameraOnDeviceNote;
  final String cameraOpening;
  final String cameraOpeningBody;
  final String cameraUnavailableBody;
  final String cameraReady;
  final String cameraPaused;
  final String cameraPausedBody;

  // Cai dat & phap ly
  final String settingsTitle;
  final String privacyPolicy;
  final String termsOfUse;
  final String healthNotice;
  final String trainSafelyTitle;
  final String trainSafelyBody;
  final String clearHistory;
  final String clearHistorySub;
  final String clearHistoryConfirm;
  final String cannotUndo;
  final String historyCleared;
  final String versionLabel;

  // Chi tiet cham tu the (hien duoi dang goi y ngan)
  final String detailMissingPoints;
  final String detailPointsOutside;
  final String detailShoulders;
  final String detailTorsoTilt;

  /// Cổ tay thấp hơn vai — chưa bám xà (bài kéo xà).
  final String detailNotHanging;

  // Trang chu
  final String tagline;
  final String homeReady;
  final String homeReadySub;
  final String exercisesLabel;
  final String exerciseCardSub;
  final String debugVideoTest;

  // Nhan xet ngoai tuyen (suy tu luat)
  final String fbTitle;
  final String fbSourceRules;
  final String fbStrengths;
  final String fbImprovements;
  final String fbNextGoal;
  final String fbNotEnoughData;
  final String fbNothingYet;
  final String fbGoalReached;
  final String fbSteadyCadence;
  final String fbGoodRange;
  final String fbBalancedSides;
  final String fbGoodCameraSetup;
  final String fbPoseLostOften;
  final String fbAmplitudeDropped;
  final String fbLeftRightUneven;
  final String fbRepsTooFast;
  final String fbShortSession;
  final String aiCoach;
  final String guidePushUp;
  final String guidePullUp;

  /// Nội dung nút "?" theo id bài. Bài chưa có thì không hiện nút.
  final Map<String, ExerciseHelp> exerciseHelp;
  final String helpTooltip;
  final String helpPlacement;
  final String helpWatch;
  final String helpNotCounted;

  // Nhan duoi cac nut tren man hinh tap
  final String hudRecord;
  final String hudStopRecord;
  final String hudCalibrateShort;
  final String hudCalibrateStop;
  final String hudFinishShort;
  final String hudHelp;

  // Văn bản pháp lý
  final String legalEffective;
  final String legalDate;
  final String privacyIntroBody;
  final String privCameraTitle;
  final String privCameraBody;
  final String privWorkoutTitle;
  final String privWorkoutBody;
  final String privAiTitle;
  final String privAiBody;
  final String privRetentionTitle;
  final String privRetentionBody;
  final String privSecurityTitle;
  final String privSecurityBody;
  final String privContactTitle;
  final String termsIntroPrefix;
  final String termsIntroSuffix;
  final String termsPurposeTitle;
  final String termsPurposeBody;
  final String termsNotMedicalTitle;
  final String termsNotMedicalBody;
  final String termsSafetyTitle;
  final String termsSafetyBody;
  final String termsLiabilityTitle;
  final String termsLiabilityBody;
  final String termsUseTitle;
  final String termsUseBody;
  final String termsChangesTitle;
  final String termsChangesBody;
  final String privChildrenTitle;
  final String privChildrenBody;
  final String privChoicesTitle;
  final String privChoicesBody;
  final String privChangesTitle;
  final String privChangesBody;
  final String privAccountTitle;
  final String privAccountBody;
  final String privSyncTitle;
  final String privSyncBody;
  final String privSocialTitle;
  final String privSocialBody;
  final String privCoachTitle;
  final String privCoachBody;
  final String privNotifTitle;
  final String privNotifBody;
  final String privDeletionTitle;
  final String privDeletionBody;
  final String privNoAdsTitle;
  final String privNoAdsBody;
  final String termsContactTitle;
  final String termsContactBody;

  static const S vi = S(
    language: AppLanguage.vi,
    appTitle: 'Đếm rep',
    chooseExercise: 'Chọn bài tập',
    settings: 'Cài đặt',
    languageLabel: 'Ngôn ngữ',
    pushUpName: 'Hít đất',
    pushUpSetupHint:
        'Đặt máy thấp trước mặt, chống tay sao cho khung xương trùng với mẫu.',
    curlName: 'Cuốn tạ đơn',
    curlSetupHint: 'Đứng thẳng, thấy rõ vai và hai cẳng tay trong khung.',
    overheadName: 'Đẩy tạ qua đầu',
    overheadSetupHint: 'Chừa khoảng trống phía trên đầu để thấy tạ khi duỗi thẳng tay.',
    pullUpName: 'Kéo xà',
    pullUpSetupHint: 'Đặt máy cách xà 2–3 m, thấy cả xà và hai bàn tay khi treo.',
    placeNoPose: 'Chưa thấy người — bước vào khung',
    placePartiallyOut: 'Đưa cả người vào trong khung',
    placeTooFar: 'Lại gần máy hơn',
    placeTooNear: 'Lùi ra xa hơn',
    placeWrongPose: 'Chưa đúng tư thế bắt đầu',
    placeReady: 'Sẵn sàng — bắt đầu đếm',
    guideHorizontal: 'Chống tay và khớp xương người với mẫu',
    guideVertical: 'Đứng lọt trong khung, chừa khoảng trống trên đầu',
    hudReps: 'REP',
    hudSetReps: 'SET NÀY',
    hudSets: 'SET',
    hudState: 'TRẠNG THÁI',
    hudWorking: 'TẬP',
    hudResting: 'NGHỈ',
    calibrate: 'Hiệu chỉnh',
    calibrateStart: 'Đang hiệu chỉnh — tập 3-5 rep rồi bấm lại',
    calibrateNotEnough: 'Chưa đủ dao động — tập vài rep rồi hiệu chỉnh lại',
    calibrateDone: 'Đã cập nhật ngưỡng theo bạn',
    calibrateRestored: 'Đang dùng ngưỡng bạn đã hiệu chỉnh lần trước',
    finishTitle: 'Kết thúc buổi tập?',
    finishNoReps: 'Bạn chưa hoàn thành rep nào.',
    finishContinue: 'Tiếp tục tập',
    finishSeeResult: 'Xem kết quả',
    resultTitle: 'Kết quả',
    resultReps: 'Số rep',
    resultDuration: 'Thời lượng',
    resultSets: 'Số set',
    resultQuality: 'Điểm chất lượng',
    resultNotEnoughData: 'Chưa đủ dữ liệu để chấm chất lượng',
    resultRangeOfMotion: 'Biên độ',
    resultCadence: 'Đều nhịp',
    resultBalance: 'Cân bằng hai bên',
    resultAlignment: 'Tư thế và pose',
    resultAiLoading: 'Đang lấy nhận xét…',
    resultAiOffline: 'Không có mạng — chỉ hiển thị nhận xét cơ bản',
    resultAiFailed: 'Không lấy được nhận xét AI',
    resultAiRetry: 'Thử lại',
    resultDisclaimer: 'Nhận xét chỉ mang tính tham khảo tập luyện, không phải tư vấn y tế.',
    historyTitle: 'Lịch sử',
    historyEmpty: 'Chưa có buổi tập nào',
    cameraPermissionTitle: 'Cần quyền camera',
    cameraPermissionBody:
        'Camera chỉ dùng để đếm rep ngay trên máy. Video không được ghi lại và không rời khỏi thiết bị.',
    cameraOffMessage:
        'Quyền truy cập camera của RepCoach đang tắt. Tính năng đếm rep cần camera.',
    cameraUnavailable: 'Không mở được camera',
    openSettings: 'Mở Cài đặt',
    retry: 'Thử lại',
    cancel: 'Huỷ',
    ok: 'Đồng ý',
    delete: 'Xóa',
    repsShort: 'rep',
    minutesShort: 'phút',
    secondsShort: 'giây',
    aiNotConfigured: 'Tính năng AI chưa được cấu hình ở bản này.',
    aiTimeout:
        'Dịch vụ AI phản hồi quá lâu. Kết quả đã được lưu, bạn có thể thử lại.',
    aiOffline: 'Không có kết nối mạng. Kết quả đã được lưu trên máy.',
    aiServerBusy: 'Máy chủ AI đang bận. Kết quả vẫn an toàn, hãy thử lại sau.',
    aiUnknownError: 'Không thể nhận xét lúc này. Kết quả vẫn được lưu trên máy.',
    aiPrivacyNote:
        'Dịch vụ AI chỉ nhận số liệu tổng hợp của buổi tập, không nhận video hay ảnh của bạn.',
    aiAsk: 'Nhận nhận xét AI',
    aiAskAgain: 'Nhận xét lại',
    resultDetail: 'Chi tiết buổi tập',
    resultDone: 'Hoàn thành',
    resultGoalHit: 'Xuất sắc, bạn đã đạt mục tiêu!',
    resultSavedOk: 'Tốt lắm, buổi tập đã được lưu!',
    resultTime: 'THỜI GIAN',
    resultPlacement: 'VỊ TRÍ',
    backHome: 'Về trang chủ',
    historyDeleteTitle: 'Xóa buổi tập này?',
    historyDeleteBody: 'Buổi tập này sẽ bị xóa vĩnh viễn.',
    historyDeleted: 'Đã xóa buổi tập',
    historyOptions: 'Tùy chọn',
    historyDeleteAction: 'Xóa buổi tập',
    goalTitle: 'Kế hoạch hôm nay',
    goalQuestion: 'Bạn muốn hoàn thành bao nhiêu rep?',
    goalHelp:
        'Chọn mục tiêu vừa sức. Bạn vẫn có thể tiếp tục tập sau khi đạt mục tiêu.',
    goalOther: 'Mục tiêu khác',
    goalEnter: 'Nhập mục tiêu',
    goalStart: 'Bắt đầu',
    goalSkip: 'Bỏ qua mục tiêu',
    onbCameraTitle: 'Camera trở thành HLV',
    onbCameraBody:
        'Đặt điện thoại chắc chắn, căn người theo khung xương và tập. MediaPipe đếm rep ngay trên thiết bị.',
    onbPrivacyTitle: 'Hình ảnh ở lại trên máy',
    onbPrivacyBody:
        'Khung hình camera và video test không được tải lên. Chỉ thống kê nhẹ được gửi khi bạn yêu cầu hoặc đã bật nhận xét AI tự động.',
    onbSafetyTitle: 'Tập an toàn, hiểu giới hạn',
    onbSafetyBody:
        'Đây là công cụ hỗ trợ thể dục, không phải thiết bị y tế. AI và bộ đếm có thể sai; hãy dừng khi cơ thể khó chịu.',
    onbAccept: 'Tôi hiểu và tiếp tục',
    onbNext: 'Tiếp tục',
    onbReadPolicy: 'Đọc chính sách quyền riêng tư',
    goalReachedTitle: 'Đạt mục tiêu rồi!',
    goalDonePrefix: 'Bạn đã hoàn thành',
    goalReachedAsk: 'Muốn tập thêm hay kết thúc?',
    goalKeepGoing: 'Tập thêm',
    finishSaveHint: 'Bạn có thể lưu kết quả trước khi rời đi.',
    finishDiscard: 'Thoát không lưu',
    finishSave: 'Lưu & kết thúc',
    finishWorkoutTooltip: 'Kết thúc buổi tập',
    cameraContinue: 'Tiếp tục',
    cameraBack: 'Quay lại',
    cameraOnDeviceNote:
        'Khung hình được xử lý trực tiếp trên thiết bị và không được tải lên máy chủ.',
    cameraOpening: 'Đang mở camera…',
    cameraOpeningBody: 'Quá trình này có thể mất vài giây.',
    cameraUnavailableBody:
        'Camera có thể đang được ứng dụng khác sử dụng hoặc thiết bị không hỗ trợ định dạng cần thiết.',
    cameraReady: 'Camera sẵn sàng',
    cameraPaused: 'Đã tạm dừng',
    cameraPausedBody:
        'Camera đã tắt trong lúc bạn rời ứng dụng. Quay lại là tiếp tục được.',
    settingsTitle: 'Cài đặt & pháp lý',
    privacyPolicy: 'Chính sách quyền riêng tư',
    termsOfUse: 'Điều khoản sử dụng',
    healthNotice: 'Lưu ý sức khỏe',
    trainSafelyTitle: 'Tập luyện an toàn',
    trainSafelyBody:
        'Ứng dụng không phải thiết bị y tế. Dừng tập khi đau, chóng mặt hoặc khó chịu và hỏi chuyên gia y tế khi cần.',
    clearHistory: 'Xóa lịch sử trên máy',
    clearHistorySub: 'Xóa vĩnh viễn buổi tập đã lưu và ngưỡng hiệu chỉnh',
    clearHistoryConfirm: 'Xóa toàn bộ lịch sử?',
    cannotUndo: 'Hành động này không thể hoàn tác.',
    historyCleared: 'Đã xóa lịch sử trên máy',
    versionLabel: 'phiên bản',
    detailMissingPoints: 'điểm bị thiếu',
    detailPointsOutside: 'điểm ngoài khung',
    detailShoulders: 'vai',
    detailTorsoTilt: 'thân nghiêng',
    detailNotHanging: 'bám xà, treo thẳng tay để bắt đầu',
    tagline: 'Huấn luyện thông minh, dữ liệu riêng tư',
    homeReady: 'Sẵn sàng cho buổi tập?',
    homeReadySub: 'Chọn mục tiêu, căn camera và bắt đầu.',
    exercisesLabel: 'BÀI TẬP',
    exerciseCardSub: 'Tập → Kết thúc → AI nhận xét',
    debugVideoTest: 'Kiểm thử bằng video có sẵn (debug)',
    fbTitle: 'Nhận xét buổi tập',
    fbSourceRules: 'Tính trên máy, không cần mạng',
    fbStrengths: 'Làm tốt',
    fbImprovements: 'Có thể cải thiện',
    fbNextGoal: 'Gợi ý buổi sau',
    fbNotEnoughData:
        'Chưa đủ dữ liệu để nhận xét kỹ thuật. Số rep vẫn được lưu đầy đủ.',
    fbNothingYet: 'Chưa có gì đáng lưu ý ở buổi này.',
    fbGoalReached: 'Đạt mục tiêu đề ra',
    fbSteadyCadence: 'Nhịp tập đều',
    fbGoodRange: 'Biên độ tốt',
    fbBalancedSides: 'Hai bên cân đối',
    fbGoodCameraSetup: 'Đặt máy tốt, giữ nguyên cho buổi sau',
    fbPoseLostOften:
        'Máy mất dấu bạn khá nhiều. Thử đặt thấp hơn, lùi ra xa hơn, hoặc bật thêm đèn.',
    fbAmplitudeDropped: 'Biên độ giảm dần về cuối buổi',
    fbLeftRightUneven: 'Hai bên chưa đều nhau',
    fbRepsTooFast: 'Nhịp khá nhanh — thử chậm lại, xuống 1 giây, lên 1 giây',
    fbShortSession: 'Buổi tập khá ngắn',
    aiCoach: 'HLV AI',
    guidePushUp: 'Chống tay, hạ người vào khung — đầu ở phía trên',
    guidePullUp: 'Thấy cả xà và hai tay — lùi máy ra nếu tay khuất',
    exerciseHelp: exerciseHelpVi,
    helpTooltip: 'Hướng dẫn',
    helpPlacement: 'Đặt máy',
    helpWatch: 'App nhìn gì để đếm',
    helpNotCounted: 'Khi nào app không tính',
    hudRecord: 'GHI VIDEO',
    hudStopRecord: 'DỪNG GHI',
    hudCalibrateShort: 'HIỆU CHỈNH',
    hudCalibrateStop: 'XONG',
    hudFinishShort: 'KẾT THÚC',
    hudHelp: 'HƯỚNG DẪN',
    legalEffective: 'Có hiệu lực',
    legalDate: LegalConfig.effectiveDate,
    privacyIntroBody:
        'tôn trọng quyền riêng tư của bạn. Bộ đếm rep chạy trên thiết bị và bạn có thể tập mà không cần tài khoản. Tài khoản là tùy chọn: nó sao lưu buổi tập và mở bạn bè, AI Coach. Chính sách này nêu mỗi lựa chọn gửi gì đi và cách xóa.',
    privCameraTitle: 'Camera và video',
    privCameraBody:
        'Ứng dụng dùng camera để nhận diện tư thế và đếm rep. Khung hình camera trực tiếp và landmark dùng cho việc đếm được xử lý trên thiết bị. Ảnh camera, video buổi tập và tọa độ landmark thô không được gửi tới backend để đếm rep hoặc nhận xét AI.',
    privWorkoutTitle: 'Dữ liệu buổi tập',
    privWorkoutBody:
        'Lịch sử tập, kế hoạch, hiệu chỉnh và cài đặt được lưu trên thiết bị. Một bản ghi buổi tập có thể gồm bài tập, thời điểm bắt đầu, thời lượng, rep, set, mục tiêu, thống kê tư thế/chất lượng, chi tiết từng rep và nhận xét AI đã trả về. Nếu không có tài khoản, các dữ liệu này không rời khỏi điện thoại, ngoại trừ yêu cầu AI mô tả bên dưới.',
    privAiTitle: 'Nhận xét AI',
    privAiBody:
        'Khi bạn yêu cầu nhận xét AI cho một buổi tập, hoặc đã đồng ý bật AI tự động, app gửi bản tóm tắt giới hạn (bài tập, mục tiêu, rep/set, thời lượng, thống kê tư thế và chỉ số chất lượng) tới máy chủ RepCoach AI; máy chủ gửi prompt tối giản tới GroqCloud bằng API key chỉ lưu trên máy chủ. Yêu cầu này không kèm ID tài khoản, tên hay email. Không gửi ảnh, video, âm thanh hoặc tọa độ landmark thô.',
    privRetentionTitle: 'Lưu giữ và xóa dữ liệu',
    privRetentionBody:
        'Dữ liệu trên điện thoại được giữ cho tới khi bạn xóa trong app, xóa dữ liệu ứng dụng hoặc gỡ app. Dữ liệu tài khoản được giữ khi tài khoản còn tồn tại. Buổi tập bạn xóa bị gỡ khỏi tài khoản và dấu xóa của chúng được dọn sau 90 ngày. Lời mời kết bạn chưa trả lời hết hạn sau 7 ngày. Máy chủ RepCoach AI không lưu lịch sử tập; log Nginx xoay mỗi ngày, giữ log hiện tại cộng 14 bản xoay, metadata backend vào system journal của máy chủ. GroqCloud có thể giữ dữ liệu inference tối đa 30 ngày để bảo đảm độ tin cậy hoặc điều tra lạm dụng.',
    privSecurityTitle: 'Bảo mật và bên xử lý',
    privSecurityBody:
        'Mọi dữ liệu rời thiết bị đi qua HTTPS. Bên xử lý dữ liệu thay mặt RepCoach: Supabase (tài khoản, cơ sở dữ liệu, Edge Functions; máy chủ ở vùng Asia-Pacific, Tokyo), GroqCloud (AI) và máy chủ RepCoach AI. Apple và Google chỉ tham gia khi bạn chọn đăng nhập bằng họ. Cơ sở dữ liệu dùng row-level security để mỗi người chỉ đọc được dữ liệu của mình. Theo tài liệu GroqCloud hiện hành, dữ liệu inference không được lưu mặc định, trừ khi cần cho độ tin cậy hoặc điều tra lạm dụng (tối đa 30 ngày). RepCoach hiện không tuyên bố Zero Data Retention.',
    privContactTitle: 'Liên hệ',
    termsIntroPrefix: 'Khi sử dụng',
    termsIntroSuffix: ', bạn đồng ý với các điều khoản dưới đây.',
    termsPurposeTitle: 'Mục đích',
    termsPurposeBody:
        'Ứng dụng giúp bạn theo dõi hoạt động thể dục và đưa ra phản hồi mang tính thông tin chung.',
    termsNotMedicalTitle: 'Không phải thiết bị y tế',
    termsNotMedicalBody:
        'RepCoach AI không đưa ra lời khuyên y tế và không chẩn đoán, điều trị, chữa khỏi hay phòng ngừa bất kỳ tình trạng y khoa nào. Số rep và nhận xét AI có thể không chính xác.',
    termsSafetyTitle: 'Tập luyện an toàn',
    termsSafetyBody:
        'Dừng tập nếu bạn thấy đau, chóng mặt hoặc khó chịu bất thường. Hãy hỏi ý kiến chuyên gia y tế có chuyên môn trước khi bắt đầu một chương trình tập mới, nhất là khi bạn đang có chấn thương, bệnh nền hoặc đang mang thai. Đặt điện thoại chắc chắn và giữ khu vực tập thông thoáng.',
    termsLiabilityTitle: 'Giới hạn kỹ thuật',
    termsLiabilityBody:
        'Kết quả phụ thuộc góc máy, ánh sáng, hiệu năng thiết bị, trang phục và mức độ camera nhìn rõ cơ thể bạn. Bạn tự chịu trách nhiệm chọn bài tập và cường độ phù hợp.',
    termsUseTitle: 'Sử dụng hợp lệ',
    termsUseBody:
        'Bạn không được phá hoại dịch vụ, lạm dụng API, dịch ngược ứng dụng trái pháp luật, hoặc dùng ứng dụng cho mục đích trái pháp luật.',
    termsChangesTitle: 'Tính khả dụng và thay đổi',
    termsChangesBody:
        'Các tính năng có thể thay đổi, bị gián đoạn hoặc ngừng cung cấp. Điều khoản có thể được cập nhật và ngày hiệu lực mới sẽ được công bố tại đây.',
    privChildrenTitle: 'Quyền riêng tư của trẻ em',
    privChildrenBody:
        'RepCoach AI không hướng tới trẻ em dưới 13 tuổi; tài khoản, bạn bè và AI Coach không dành cho trẻ em dưới 13 tuổi. Groq cho phép tích hợp API vào ứng dụng của khách hàng và cung cấp AI cho người dùng cuối. Nếu ứng dụng hướng tới hoặc có khả năng được người chưa đủ tuổi trưởng thành sử dụng, nhà phát triển chịu trách nhiệm tuân thủ các luật áp dụng về trẻ em và dữ liệu cá nhân.',
    privChoicesTitle: 'Lựa chọn của bạn',
    privChoicesBody:
        'Bạn có thể tập như khách, không cần tài khoản và không cần AI. Bạn có thể thu hồi quyền camera trong cài đặt thiết bị, tắt AI tự động cho các yêu cầu tương lai, xuất hoặc xóa lịch sử tập trong Cài đặt, đổi tên hiển thị hoặc chặn một người trong Bạn bè, đăng xuất và xóa tài khoản. Tắt AI hoặc xóa dữ liệu cục bộ không thu hồi được yêu cầu AI đã gửi.',
    privChangesTitle: 'Thay đổi và liên hệ',
    privChangesBody:
        'Chính sách này có thể được cập nhật. Ngày hiệu lực ở trên cho biết bản sửa đổi mới nhất. Mọi câu hỏi về quyền riêng tư xin gửi về địa chỉ dưới đây.',
    privAccountTitle:
        'Tài khoản (tùy chọn)',
    privAccountBody:
        'Bạn có thể tạo tài khoản bằng email và mật khẩu, Đăng nhập bằng Apple hoặc Đăng nhập bằng Google. Tài khoản do Supabase Auth vận hành và gồm địa chỉ email, ID người dùng, nhà cung cấp đăng nhập và, với Apple hoặc Google, tên và email mà nhà cung cấp chia sẻ (Apple có thể cho địa chỉ chuyển tiếp ẩn). Supabase chỉ lưu mật khẩu ở dạng băm. Token đăng nhập được giữ trong Keychain (iOS) hoặc Keystore (Android) trên điện thoại. Bạn có thể đặt tên hiển thị trong Bạn bè.',
    privSyncTitle:
        'Đồng bộ đám mây',
    privSyncBody:
        'Khi đã đăng nhập, buổi tập lưu trong lúc đăng nhập được đồng bộ vào tài khoản: bài tập, thời điểm bắt đầu, thời lượng, rep, ghi tay hay dang dở, và bản ghi buổi tập kèm chi tiết từng rep và thống kê chất lượng. Buổi tập lưu khi là khách chỉ được tải lên nếu bạn chọn gộp vào tài khoản. Kế hoạch, XP, thành tích, sổ tín dụng AI (thay đổi tín dụng kèm request ID ngẫu nhiên) và tin trong hộp thư của app cũng được lưu theo tài khoản. Ảnh và video camera không bao giờ được đồng bộ.',
    privSocialTitle:
        'Bạn bè và bảng xếp hạng',
    privSocialBody:
        'Bạn bè là tính năng tùy chọn. Bạn bè thấy tên hiển thị và tổng tuần các buổi tập đếm bằng camera của bạn trên bảng xếp hạng bạn bè. Lời mời hết hạn sau 7 ngày. Bạn có thể chặn hoặc báo cáo một người kèm lý do; báo cáo được giữ để nhà phát triển xử lý lạm dụng. Không ai tìm được bạn theo tên.',
    privCoachTitle:
        'AI Coach',
    privCoachBody:
        'AI Coach, phân tích nâng cao và đánh giá tiến bộ cần tài khoản và dùng tín dụng AI miễn phí hằng tuần. Tin nhắn bạn gõ, phần hội thoại trước đó trong phiên và, với phân tích, số liệu tổng hợp của buổi tập được gửi tới dịch vụ ai-request trên Supabase; dịch vụ chuyển tới GroqCloud và trả câu trả lời về. Hội thoại không được lưu trên máy chủ; chỉ ghi lại thay đổi tín dụng và một request ID ngẫu nhiên. Đoạn chat chỉ nằm trong bộ nhớ trên điện thoại và không được lưu lại.',
    privNotifTitle:
        'Thông báo',
    privNotifBody:
        'Nhắc lịch tập là thông báo cục bộ, được điện thoại lên lịch từ kế hoạch của bạn. Chúng tắt cho tới khi bạn bật. Phiên bản này không dùng thông báo đẩy từ máy chủ.',
    privDeletionTitle:
        'Xóa tài khoản',
    privDeletionBody:
        'Trong app, mở Hồ sơ › Xóa tài khoản và xác nhận. Việc này thu hồi Đăng nhập bằng Apple (nếu dùng), xóa hồ sơ, buổi tập đã đồng bộ, kế hoạch, XP, thành tích, tín dụng, bạn bè, danh sách chặn, lời mời và hộp thư, rồi xóa chính tài khoản. Báo cáo bạn gửi hoặc bị gửi được giữ lại nhưng bỏ ID người dùng. Buổi tập trên điện thoại vẫn còn cho tới khi bạn xóa trong Cài đặt › Xóa lịch sử tập hoặc gỡ app. Bạn cũng có thể yêu cầu xóa trên web tại ${LegalConfig.accountDeletionUrl} hoặc qua email từ địa chỉ của tài khoản.',
    privNoAdsTitle:
        'Không quảng cáo, không theo dõi',
    privNoAdsBody:
        'RepCoach AI không có SDK quảng cáo, analytics hay báo lỗi, không theo dõi bạn qua ứng dụng hoặc trang web khác và không bán dữ liệu cá nhân.',
    termsContactTitle: 'Liên hệ',
    termsContactBody:
        'Mọi câu hỏi về điều khoản xin gửi về địa chỉ dưới đây.',
  );

  static const S en = S(
    language: AppLanguage.en,
    appTitle: 'Rep Counter',
    chooseExercise: 'Choose an exercise',
    settings: 'Settings',
    languageLabel: 'Language',
    pushUpName: 'Push-up',
    pushUpSetupHint:
        'Place the phone low in front of you and set your hands so your skeleton matches the guide.',
    curlName: 'Dumbbell curl',
    curlSetupHint: 'Stand upright with your shoulders and forearms clearly in frame.',
    overheadName: 'Overhead extension',
    overheadSetupHint: 'Leave headroom above you so the weight stays in frame at full extension.',
    pullUpName: 'Pull-up',
    pullUpSetupHint: 'Place the phone 2–3 m from the bar so the bar and both hands stay in frame.',
    placeNoPose: 'No one detected — step into the frame',
    placePartiallyOut: 'Move your whole body inside the guide',
    placeTooFar: 'Move closer to the camera',
    placeTooNear: 'Move further away',
    placeWrongPose: 'Not in the starting position yet',
    placeReady: 'Ready — counting',
    guideHorizontal: 'Set your hands and match the skeleton to the guide',
    guideVertical: 'Stand inside the guide, leave room above your head',
    hudReps: 'REPS',
    hudSetReps: 'THIS SET',
    hudSets: 'SETS',
    hudState: 'STATUS',
    hudWorking: 'WORKING',
    hudResting: 'RESTING',
    calibrate: 'Calibrate',
    calibrateStart: 'Calibrating — do 3-5 reps then tap again',
    calibrateNotEnough: 'Not enough movement — do a few reps and try again',
    calibrateDone: 'Thresholds updated for you',
    calibrateRestored: 'Using the thresholds you calibrated last time',
    finishTitle: 'Finish this workout?',
    finishNoReps: 'You have not completed any reps.',
    finishContinue: 'Keep going',
    finishSeeResult: 'See results',
    resultTitle: 'Results',
    resultReps: 'Reps',
    resultDuration: 'Duration',
    resultSets: 'Sets',
    resultQuality: 'Quality score',
    resultNotEnoughData: 'Not enough data to score quality',
    resultRangeOfMotion: 'Range of motion',
    resultCadence: 'Cadence',
    resultBalance: 'Left/right balance',
    resultAlignment: 'Posture and pose',
    resultAiLoading: 'Getting feedback…',
    resultAiOffline: 'Offline — showing basic feedback only',
    resultAiFailed: 'Could not get AI feedback',
    resultAiRetry: 'Retry',
    resultDisclaimer: 'Feedback is for training reference only and is not medical advice.',
    historyTitle: 'History',
    historyEmpty: 'No workouts yet',
    cameraPermissionTitle: 'Camera permission needed',
    cameraPermissionBody:
        'The camera is only used to count reps on your device. Nothing is recorded and nothing leaves the phone.',
    cameraOffMessage:
        'Camera access is off for RepCoach. Rep counting needs the camera.',
    cameraUnavailable: 'Could not open the camera',
    openSettings: 'Open Settings',
    retry: 'Retry',
    cancel: 'Cancel',
    ok: 'Allow',
    delete: 'Delete',
    repsShort: 'reps',
    minutesShort: 'min',
    secondsShort: 'sec',
    aiNotConfigured: 'AI feedback is not configured in this build.',
    aiTimeout:
        'The AI service took too long to answer. Your workout is saved — you can try again.',
    aiOffline: 'No network connection. Your workout is saved on this device.',
    aiServerBusy: 'The AI server is busy. Your workout is safe — try again later.',
    aiUnknownError:
        'Could not get feedback right now. Your workout is still saved on this device.',
    aiPrivacyNote:
        'The AI service only receives limited workout statistics — no videos or photos are sent.',
    aiAsk: 'Get AI feedback',
    aiAskAgain: 'Get feedback again',
    resultDetail: 'Workout detail',
    resultDone: 'Completed',
    resultGoalHit: 'Excellent — you hit your goal!',
    resultSavedOk: 'Nice work, your workout is saved!',
    resultTime: 'TIME',
    resultPlacement: 'POSITION',
    backHome: 'Back to home',
    historyDeleteTitle: 'Delete this workout?',
    historyDeleteBody: 'This workout will be permanently deleted.',
    historyDeleted: 'Workout deleted',
    historyOptions: 'Options',
    historyDeleteAction: 'Delete workout',
    goalTitle: 'Today\'s plan',
    goalQuestion: 'How many reps do you want to complete?',
    goalHelp:
        'Pick a goal you can manage. You can keep training after you reach it.',
    goalOther: 'Custom goal',
    goalEnter: 'Enter a goal',
    goalStart: 'Start',
    goalSkip: 'Skip the goal',
    onbCameraTitle: 'Your camera becomes the coach',
    onbCameraBody:
        'Prop the phone up steadily, line yourself up with the skeleton and train. MediaPipe counts your reps right on the device.',
    onbPrivacyTitle: 'Your footage stays on the phone',
    onbPrivacyBody:
        'Camera frames and test videos are never uploaded. Only aggregate statistics are sent when you ask for AI feedback or consent to automatic feedback.',
    onbSafetyTitle: 'Train safely, know the limits',
    onbSafetyBody:
        'This is a fitness aid, not a medical device. The AI and the counter can be wrong — stop if anything feels off.',
    onbAccept: 'I understand, continue',
    onbNext: 'Continue',
    onbReadPolicy: 'Read the privacy policy',
    goalReachedTitle: 'Goal reached!',
    goalDonePrefix: 'You completed',
    goalReachedAsk: 'Keep going or finish here?',
    goalKeepGoing: 'Keep going',
    finishSaveHint: 'You can save your results before you leave.',
    finishDiscard: 'Leave without saving',
    finishSave: 'Save & finish',
    finishWorkoutTooltip: 'Finish workout',
    cameraContinue: 'Continue',
    cameraBack: 'Back',
    cameraOnDeviceNote:
        'Frames are processed directly on your device and are never uploaded to a server.',
    cameraOpening: 'Opening the camera…',
    cameraOpeningBody: 'This can take a few seconds.',
    cameraUnavailableBody:
        'The camera may be in use by another app, or this device does not support the required format.',
    cameraReady: 'Camera ready',
    cameraPaused: 'Paused',
    cameraPausedBody:
        'The camera was turned off while you were away. Come back to continue.',
    settingsTitle: 'Settings & legal',
    privacyPolicy: 'Privacy policy',
    termsOfUse: 'Terms of use',
    healthNotice: 'Health notice',
    trainSafelyTitle: 'Train safely',
    trainSafelyBody:
        'This app is not a medical device. Stop training if you feel pain, dizziness or discomfort, and consult a health professional when needed.',
    clearHistory: 'Delete history on this device',
    clearHistorySub: 'Permanently delete saved workouts and calibration',
    clearHistoryConfirm: 'Delete the entire history?',
    cannotUndo: 'This action cannot be undone.',
    historyCleared: 'History deleted from this device',
    versionLabel: 'version',
    detailMissingPoints: 'landmarks missing',
    detailPointsOutside: 'landmarks outside the guide',
    detailShoulders: 'shoulders',
    detailTorsoTilt: 'torso tilt',
    detailNotHanging: 'grab the bar and hang with straight arms',
    tagline: 'Smart coaching, private data',
    homeReady: 'Ready for a workout?',
    homeReadySub: 'Pick a goal, line up the camera and start.',
    exercisesLabel: 'EXERCISES',
    exerciseCardSub: 'Train → Finish → AI feedback',
    debugVideoTest: 'Test with a saved video (debug)',
    fbTitle: 'Workout feedback',
    fbSourceRules: 'Calculated on your device, no network needed',
    fbStrengths: 'Went well',
    fbImprovements: 'Could improve',
    fbNextGoal: 'Suggested next goal',
    fbNotEnoughData:
        'Not enough data to comment on technique. Your rep count is still saved in full.',
    fbNothingYet: 'Nothing notable in this session.',
    fbGoalReached: 'Hit your goal',
    fbSteadyCadence: 'Steady pace',
    fbGoodRange: 'Good range of motion',
    fbBalancedSides: 'Both sides even',
    fbGoodCameraSetup: 'Good camera placement — keep it for next time',
    fbPoseLostOften:
        'The camera lost track of you often. Try placing it lower, moving further back, or adding light.',
    fbAmplitudeDropped: 'Range of motion dropped towards the end',
    fbLeftRightUneven: 'Left and right are not even yet',
    fbRepsTooFast: 'Pace is quite fast — try one second down, one second up',
    fbShortSession: 'Short session',
    aiCoach: 'AI Coach',
    guidePushUp: 'Hands down, body inside the frame — head at the top',
    guidePullUp: 'Keep the bar and both hands in view — move the phone back if they are cut off',
    exerciseHelp: exerciseHelpEn,
    helpTooltip: 'How it works',
    helpPlacement: 'Phone placement',
    helpWatch: 'What the app watches',
    helpNotCounted: 'When a rep is not counted',
    hudRecord: 'RECORD',
    hudStopRecord: 'STOP REC',
    hudCalibrateShort: 'CALIBRATE',
    hudCalibrateStop: 'DONE',
    hudFinishShort: 'FINISH',
    hudHelp: 'HELP',
    legalEffective: 'Effective',
    legalDate: LegalConfig.effectiveDateEn,
    privacyIntroBody:
        'respects your privacy. Rep counting runs on your device, and you can train without an account. An account is optional: it backs up your workouts and unlocks friends and AI Coach. This policy explains what each choice sends and how to delete it.',
    privCameraTitle: 'Camera and video',
    privCameraBody:
        'The app uses your camera to detect body pose and count repetitions. Live camera frames and landmarks used for counting are processed on-device. Camera images, workout video and raw landmark coordinates are not sent to the backend for rep counting or AI feedback.',
    privWorkoutTitle: 'Workout data',
    privWorkoutBody:
        'Workout history, plans, calibration and settings are stored on your device. A workout record can include the exercise, start time, duration, reps, sets, goals, pose and quality statistics, per-rep detail and returned AI feedback. Without an account none of this leaves the phone, except the AI requests described below.',
    privAiTitle: 'AI feedback',
    privAiBody:
        'When you request AI feedback on a workout, or opt in to automatic feedback, the app sends a limited summary (exercise, goal, reps/sets, duration, pose statistics and quality metrics) to the RepCoach AI server, which sends a minimized prompt to GroqCloud using an API key stored only on the server. This request carries no account ID, name or email. No images, video, audio or raw landmark coordinates are sent.',
    privRetentionTitle: 'Data retention and deletion',
    privRetentionBody:
        'Data on your phone stays until you delete it in the app, clear the app\'s storage or uninstall it. Account data stays while your account exists. Workouts you delete are removed from your account and their deletion markers are purged after 90 days. Unanswered friend invites expire after 7 days. The RepCoach AI server keeps no workout history; its Nginx logs rotate daily, keeping the current log plus 14 rotations, and backend metadata goes to the host system journal. GroqCloud may keep inference data for up to 30 days for reliability or abuse checks.',
    privSecurityTitle: 'Security and processors',
    privSecurityBody:
        'All data that leaves the device is sent over HTTPS. Processors acting for RepCoach: Supabase (accounts, database, Edge Functions; servers in the Asia-Pacific Tokyo region), GroqCloud (AI) and the RepCoach AI server. Apple and Google take part only when you choose to sign in with them. The database uses row-level security so each person can read only their own data. Under GroqCloud\'s current documentation, inference data is not retained by default except for reliability or abuse investigation (up to 30 days). RepCoach does not currently claim Zero Data Retention.',
    privContactTitle: 'Contact',
    termsIntroPrefix: 'By using',
    termsIntroSuffix: ', you agree to the terms below.',
    termsPurposeTitle: 'Purpose',
    termsPurposeBody:
        'The app helps you track fitness activity and provides general informational feedback.',
    termsNotMedicalTitle: 'Not a medical device',
    termsNotMedicalBody:
        'RepCoach AI does not provide medical advice and does not diagnose, treat, cure, or prevent any medical condition. Rep counts and AI feedback may be inaccurate.',
    termsSafetyTitle: 'Exercise safety',
    termsSafetyBody:
        'Stop exercising if you experience pain, dizziness, or unusual discomfort. Consult a qualified healthcare professional before beginning a new exercise program, especially if you have an injury, a health condition, or are pregnant. Place your phone securely and keep the workout area clear.',
    termsLiabilityTitle: 'Technical limitations',
    termsLiabilityBody:
        'Results depend on camera angle, lighting, device performance, clothing, and how clearly the camera can see your body. You are responsible for choosing an appropriate exercise and intensity.',
    termsUseTitle: 'Acceptable use',
    termsUseBody:
        'You must not disrupt the service, abuse its API, unlawfully reverse engineer the app, or use it for unlawful purposes.',
    termsChangesTitle: 'Availability and changes',
    termsChangesBody:
        'Features may change, be interrupted, or be discontinued. We may update these terms, and a new effective date will be published here.',
    privChildrenTitle: 'Children and privacy',
    privChildrenBody:
        'RepCoach AI is not directed to children under 13, and accounts, friends and AI Coach are not intended for them. Groq permits API integration into a Customer Application and making AI services available to End Users. If the app is directed toward or likely to be accessed by people under the age of majority, the developer is responsible for complying with applicable child and personal-data laws.',
    privChoicesTitle: 'Your choices',
    privChoicesBody:
        'You can train as a guest, without an account and without AI. You may revoke camera permission in your device settings, turn off automatic AI for future requests, export or delete your workout history in Settings, change your display name or block a person in Friends, sign out, and delete your account. Turning off AI or deleting local data cannot recall an AI request already sent.',
    privChangesTitle: 'Changes and contact',
    privChangesBody:
        'We may update this policy. The effective date above identifies the latest revision. Send privacy questions to the address below.',
    privAccountTitle:
        'Account (optional)',
    privAccountBody:
        'You can create an account with email and password, Sign in with Apple or Google Sign-In. The account is run by Supabase Auth and holds your email address, a user ID, the sign-in provider and, for Apple or Google, the name and email the provider shares (Apple may give a private relay address). Supabase stores passwords only as a hash. Sign-in tokens are kept in the iOS Keychain or Android Keystore on your phone. You can set a display name in Friends.',
    privSyncTitle:
        'Cloud sync',
    privSyncBody:
        'When you are signed in, workouts saved while signed in are synced to your account: exercise, start time, duration, reps, whether it was manual or partial, and the workout record with its per-rep detail and quality statistics. Workouts saved as a guest are uploaded only if you choose to merge them into your account. Your plans, XP, achievements, the AI credit ledger (credit changes with a random request ID) and in-app inbox messages are stored with your account too. Camera images and video are never synced.',
    privSocialTitle:
        'Friends and leaderboard',
    privSocialBody:
        'Friends is optional. Friends see your display name and your weekly totals from camera-counted workouts on the friends leaderboard. Invites expire after 7 days. You can block or report a person with a reason; reports are kept so the developer can act on abuse. Nobody can search for you by name.',
    privCoachTitle:
        'AI Coach',
    privCoachBody:
        'AI Coach, advanced analysis and progress reviews need an account and use weekly free AI credits. The messages you type, the earlier messages of that session and, for analyses, aggregate workout numbers are sent to the ai-request service on Supabase, which forwards them to GroqCloud and returns the answer. The conversation is not stored on the server; only the credit change and a random request ID are recorded. The chat is kept in memory on your phone only and is not saved.',
    privNotifTitle:
        'Notifications',
    privNotifBody:
        'Workout reminders are local notifications that your phone schedules from your plan. They stay off until you turn them on. This version does not use remote push notifications.',
    privDeletionTitle:
        'Deleting your account',
    privDeletionBody:
        'In the app, open Profile › Delete account and confirm. This revokes Sign in with Apple when used, deletes your profile, synced workouts, plans, XP, achievements, credits, friends, blocks, invites and inbox, then deletes the account itself. Reports you sent or received are kept without your user ID. Workouts on your phone stay until you delete them in Settings › Delete workout history or uninstall the app. You can also request deletion on the web at ${LegalConfig.accountDeletionUrl} or by email from your account\'s address.',
    privNoAdsTitle:
        'No ads, no tracking',
    privNoAdsBody:
        'RepCoach AI has no advertising, analytics or crash-reporting SDK, does not track you across other apps or websites, and does not sell personal data.',
    termsContactTitle: 'Contact',
    termsContactBody:
        'Questions about these terms may be sent to the address below.',
  );

  static S of(AppLanguage l) => l == AppLanguage.en ? en : vi;
}
