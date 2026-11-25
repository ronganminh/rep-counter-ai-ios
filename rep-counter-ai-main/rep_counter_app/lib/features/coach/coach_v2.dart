import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../credits/ai_coach_v2.dart';
import '../credits/credits_controller.dart';

/// AI Coach · PT ảo UI (design handoff 2026-11-25, screens AC-01…AC-04,
/// `docs/design/v2-final-c/aicoach/AI_COACH_PT_HANDOFF.md`). Everything here
/// sits behind `ENABLE_AI_COACH_V2` ([AiCoachV2.enabled], off by default,
/// on in staging): with the flag off no screen, card or row of this folder
/// is shown and the app is unchanged.

/// D-29 AI credit costs (owner-confirmed 2026-11-25). Strings take the
/// amount as `{credits}` so it can change; the server's ledger decides what
/// is actually charged (`ai-request`).
abstract final class CoachCost {
  /// Coach's pick on Home: free once a day.
  static const dailyPick = 0;

  /// "New suggestion" on Home.
  static const newSuggestion = 1;

  /// Coach review after a workout.
  static const review = 1;

  /// Each chat message.
  static const chatMessage = 1;

  /// Pain / injury safety reply (D-34).
  static const safetyReply = 0;

  /// Next-week suggestion in My plan.
  static const weekPlan = 2;
}

/// D-32 minimum data before the coach is asked.
abstract final class CoachMinimum {
  /// Saved workouts before the daily pick.
  static const pickWorkouts = 3;

  /// Days of history before a next-week suggestion.
  static const weekHistoryDays = 14;
}

/// The AI Coach consent (AC-03a): asked once, before the first coach
/// request; "Not now" never blocks training. Same key as the v2 chat
/// consent ([AiCoachV2.consentKey]), so agreeing once covers every coach
/// screen.
class CoachConsentStore {
  const CoachConsentStore();

  Future<bool> given() async {
    try {
      return (await SharedPreferences.getInstance())
              .getBool(AiCoachV2.consentKey) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> give() async => (await SharedPreferences.getInstance())
      .setBool(AiCoachV2.consentKey, true);

  Future<void> withdraw() async =>
      (await SharedPreferences.getInstance()).remove(AiCoachV2.consentKey);
}

/// Whether the AI Coach UI can show here: the flag is on and AI credits
/// are configured (accounts + backend).
abstract final class CoachGate {
  static bool available(BuildContext context,
          {bool enabled = AiCoachV2.enabled}) =>
      enabled && CreditsScope.maybeOf(context) != null;
}
