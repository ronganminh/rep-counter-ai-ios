import 'package:flutter/widgets.dart';

import '../auth/application/auth_controller.dart';
import '../plan/application/plan_repository.dart';
import '../plan/application/reminder_service.dart';
import '../plan/domain/local_date.dart';
import '../plan/domain/reminder_copy.dart';
import '../plan/domain/reminder_planner.dart';
import '../workout/data/workout_database.dart';
import 'ai_coach_v2.dart';
import 'ai_credits.dart';
import 'credits_controller.dart';

/// NT-2 layer 2 (L-D44): the AI coach writes reminder lines for the next
/// 3–7 planned sessions (`ai-request` kind `reminder_batch`). Optional
/// (reminder settings, off by default), AI coach v2 only, signed in only,
/// at most one AI request (one credit) per week; a failed try waits a day.
/// Only session ids, days, times and targets are sent, plus the plan goal;
/// the server adds the numbers-only history. Any failure keeps layer 1.
class ReminderAiWriterImpl {
  ReminderAiWriterImpl(this.credits,
      {ReminderAiStore? store, DateTime Function()? now, String Function()? newId})
      : _store = store ?? ReminderAiStore(),
        _now = now ?? DateTime.now,
        _newId = newId ?? WorkoutDatabase.newClientId;

  final CreditsController credits;
  final ReminderAiStore _store;
  final DateTime Function() _now;
  final String Function() _newId;

  static const maxSessions = 7;

  Future<bool> call(PlanView view, ReminderPrefs prefs, Locale locale) async {
    if (!prefs.enabled || !prefs.aiCopy) return false;
    if (credits.auth.state is! AuthSignedIn) return false;
    final now = _now();
    final today = LocalDate.of(now);
    final saved = await _store.load();
    // One successful request per week (Monday start); one try per day.
    if (saved.requested != null &&
        saved.requested!.startOfWeek == today.startOfWeek) {
      return false;
    }
    if (saved.tried == today) return false;
    final upcoming = ReminderPlanner.plan(view.plan, view.sessions, prefs, now)
        .take(maxSessions)
        .toList();
    if (upcoming.isEmpty) return false;
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final context = <String, Object?>{
      'sessions': [
        for (final r in upcoming)
          {
            'session_id': r.sessionId,
            'in_days': today.daysUntil(r.date),
            'weekday': r.date.weekday,
            'time': hhmm(r.fireAt),
            'targets': [
              for (final t in view.sessions
                  .firstWhere((s) => s.id == r.sessionId)
                  .exerciseTargets)
                {
                  'exercise_id': t.exerciseId,
                  'sets': t.sets,
                  if (t.reps != null) 'reps': t.reps,
                  if (t.seconds != null) 'seconds': t.seconds,
                }
            ],
          }
      ],
      'goal': {'goal': view.plan.goal.name, 'difficulty': view.plan.difficulty.name},
    };
    try {
      final answer = await credits.api.ask(
        requestId: _newId(),
        kind: CreditedRequest.reminderBatch,
        locale: locale.languageCode == 'vi' ? 'vi' : 'en',
        version: 2,
        context: context,
      );
      final wanted = {for (final r in upcoming) r.sessionId};
      final lines = <String, String>{};
      final raw = answer.data?['lines'];
      if (raw is List) {
        for (final l in raw) {
          if (l is! Map) continue;
          final id = l['session_id'];
          final text = ReminderCopy.cleanAi(l['text']);
          if (id is String && wanted.contains(id) && text != null) {
            lines[id] = text;
          }
        }
      }
      await _store.save(lines, requested: today, tried: today);
      return lines.isNotEmpty;
    } catch (_) {
      // Offline, no credits, limit, provider error: layer 1 stays.
      await _store.save(saved.lines, requested: saved.requested, tried: today);
      return false;
    }
  }
}

/// Installs the writer for this app session (AI coach v2 builds only).
void installReminderAiWriter(CreditsController? credits,
    {bool enabled = AiCoachV2.enabled}) {
  ReminderService.installedAiWriter =
      credits != null && enabled ? ReminderAiWriterImpl(credits).call : null;
}
