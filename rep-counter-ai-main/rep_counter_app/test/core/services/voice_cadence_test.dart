import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/services/training_preferences.dart';
import 'package:rep_counter_app/core/services/workout_feedback.dart';

class FakeSpeechDriver implements SpeechDriver {
  final spoken = <String>[];

  @override
  Future<void> configure(String locale) async {}

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cadence persists separately from existing training controls', () async {
    final original = const TrainingPreferences(
      voice: false,
      haptics: true,
      sound: true,
      cues: false,
    );
    final updated = await original.update(
      repSpeechCadence: RepSpeechCadence.every5Reps,
    );
    final loaded = await TrainingPreferences.load();

    expect(updated.repSpeechCadence, RepSpeechCadence.every5Reps);
    expect(loaded.repSpeechCadence, RepSpeechCadence.every5Reps);
    expect(loaded.voice, isTrue,
        reason: 'only explicitly persisted fields may change on disk');
    expect(loaded.haptics, isTrue);
    expect(loaded.sound, isFalse);
    expect(loaded.cues, isTrue);
  });

  test('every5 cadence speaks exactly 5 10 15', () async {
    final speech = FakeSpeechDriver();
    final feedback = WorkoutFeedback(
      speech: speech,
      haptic: (_) async {},
    );
    addTearDown(feedback.dispose);
    feedback.configure(
      const TrainingPreferences(
        haptics: false,
        cues: false,
        repSpeechCadence: RepSpeechCadence.every5Reps,
      ),
      AppLanguage.en,
    );
    await feedback.settled;

    for (var rep = 1; rep <= 15; rep++) {
      feedback.rep(rep, goalReached: false);
      await feedback.settled;
    }

    expect(speech.spoken, <String>['5', '10', '15']);
  });

  test('master voice mute overrides cadence without disabling haptics', () async {
    final speech = FakeSpeechDriver();
    var haptics = 0;
    final feedback = WorkoutFeedback(
      speech: speech,
      haptic: (_) async => haptics++,
    );
    addTearDown(feedback.dispose);
    feedback.configure(
      const TrainingPreferences(
        voice: false,
        haptics: true,
        repSpeechCadence: RepSpeechCadence.everyRep,
      ),
      AppLanguage.en,
    );
    await feedback.settled;

    feedback.rep(1, goalReached: false);
    await feedback.settled;

    expect(speech.spoken, isEmpty);
    expect(haptics, 1);
  });

  test('posture cue remains independent when cadence suppresses rep number',
      () async {
    final speech = FakeSpeechDriver();
    final feedback = WorkoutFeedback(
      speech: speech,
      haptic: (_) async {},
    );
    addTearDown(feedback.dispose);
    feedback.configure(
      const TrainingPreferences(
        haptics: false,
        cues: true,
        repSpeechCadence: RepSpeechCadence.every5Reps,
      ),
      AppLanguage.en,
    );
    await feedback.settled;

    feedback.rep(
      1,
      goalReached: false,
      cue: 'Keep your torso steady',
      at: const Duration(seconds: 10),
    );
    await feedback.settled;

    expect(speech.spoken, <String>['Keep your torso steady']);
  });

  test('milestones-only still speaks goal completion', () async {
    final speech = FakeSpeechDriver();
    final feedback = WorkoutFeedback(
      speech: speech,
      haptic: (_) async {},
    );
    addTearDown(feedback.dispose);
    feedback.configure(
      const TrainingPreferences(
        haptics: false,
        cues: false,
        repSpeechCadence: RepSpeechCadence.milestonesOnly,
      ),
      AppLanguage.en,
    );
    await feedback.settled;

    feedback.rep(1, goalReached: false);
    await feedback.settled;
    feedback.rep(2, goalReached: true);
    await feedback.settled;

    expect(speech.spoken, <String>['2. Goal reached!']);
  });
}
