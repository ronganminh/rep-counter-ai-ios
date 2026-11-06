/// Movement demo clips from namnq/workout-free-videos (CC0 1.0), bundled in
/// `assets/guide/` (plan 07, PR A). UI only: nothing here touches the
/// camera, pose detection or rep counting.
library;

import '../../../l10n/app_localizations.dart';

/// How close the library clip is to the app's exercise.
enum GuideClipFit {
  /// Same movement.
  exact,

  /// Similar movement with other equipment (curl: barbell, not dumbbells).
  similar,
}

class ExerciseGuideClip {
  const ExerciseGuideClip({
    required this.appId,
    required this.sourceId,
    required this.slug,
    required this.fit,
    required this.bytes,
    required this.sha256,
    required this.cuesEn,
    required this.cuesViReviewed,
    required String Function(AppLocalizations) semanticLabel,
    required List<String> Function(AppLocalizations) cues,
  })  : _semanticLabel = semanticLabel,
        _cues = cues;

  /// `ExerciseProfile.id`.
  final String appId;

  /// Library `id` and `slug` (stable across releases).
  final String sourceId;
  final String slug;
  final GuideClipFit fit;

  /// Size and SHA-256 of the bundled MP4, as published in the library's
  /// `data/exercises.json` (tag v2.0.0). Checked by a test.
  final int bytes;
  final String sha256;

  /// The three English cues copied verbatim from `exercises.json`. The UI
  /// reads the ARB strings; a test keeps the EN ARB equal to these.
  final List<String> cuesEn;

  /// The library has no Vietnamese; the VI cues are our own translation and
  /// wait for the owner's review (listed in docs/implementation/07).
  final bool cuesViReviewed;

  final String Function(AppLocalizations) _semanticLabel;
  final List<String> Function(AppLocalizations) _cues;

  String get videoAsset => 'assets/guide/$slug.mp4';

  /// First frame of the clip, shown while loading and with reduced motion.
  String get posterAsset => 'assets/guide/$slug.jpg';

  String semanticLabel(AppLocalizations l) => _semanticLabel(l);
  List<String> cues(AppLocalizations l) => _cues(l);

  static const source = 'https://github.com/namnq/workout-free-videos';
  static const sourceTag = 'v2.0.0';
  static const license = 'CC0 1.0';

  /// The clip for an app exercise, or null (push-up and overhead extension
  /// have no match in the library and keep the current guide).
  static ExerciseGuideClip? forExercise(String appId) =>
      all.where((c) => c.appId == appId).firstOrNull;

  static final all = <ExerciseGuideClip>[
    ExerciseGuideClip(
      appId: 'pull_up',
      sourceId: 'l02',
      slug: 'wide-grip-pull-up',
      fit: GuideClipFit.exact,
      bytes: 419675,
      sha256:
          '36cd4dd2c16527e1fc191e5f771a72dd28e4c4e66f8ad29b4af003c2f6ff4e93',
      cuesEn: const [
        'Start from a dead hang',
        'Pull the chest toward the bar',
        'Lower all the way each rep',
      ],
      cuesViReviewed: false,
      semanticLabel: (l) => l.guideClipPullUpLabel,
      cues: (l) => [l.guideCuePullUp1, l.guideCuePullUp2, l.guideCuePullUp3],
    ),
    ExerciseGuideClip(
      appId: 'curl',
      sourceId: 'b01',
      slug: 'standing-barbell-curl',
      fit: GuideClipFit.similar,
      bytes: 410834,
      sha256:
          'f4b18a0452de7b5fc10fe7fc8dd73ccda67204bd0bab788aef3bfcafe5f2b182',
      cuesEn: const [
        'Elbows stay pinned to the sides',
        'Curl without leaning back',
        'Lower all the way to full extension',
      ],
      cuesViReviewed: false,
      semanticLabel: (l) => l.guideClipCurlLabel,
      cues: (l) => [l.guideCueCurl1, l.guideCueCurl2, l.guideCueCurl3],
    ),
  ];
}
