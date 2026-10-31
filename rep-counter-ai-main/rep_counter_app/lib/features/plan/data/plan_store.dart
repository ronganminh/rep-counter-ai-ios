import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/local_data_changes.dart';
import '../domain/workout_plan.dart';

/// Plans and their sessions as one local JSON document (PL-1). Local-first:
/// guests and signed-in users alike. With cloud sync on (A-2) each plan and
/// its sessions are copied to the account by `PlanSyncSource`; this store
/// stays the source of truth on the phone. A few hundred sessions a year
/// stay small.
@immutable
class PlanSnapshot {
  const PlanSnapshot(
      {this.plans = const [],
      this.sessions = const [],
      this.unreadable = const []});

  final List<WorkoutPlan> plans;
  final List<PlannedSession> sessions;

  /// Entries this version cannot read, kept verbatim and written back so
  /// they are never lost.
  final List<Object?> unreadable;

  WorkoutPlan? get current {
    for (final status in [PlanStatus.active, PlanStatus.paused]) {
      for (final p in plans) {
        if (p.status == status) return p;
      }
    }
    return null;
  }

  List<PlannedSession> sessionsOf(String planId) => [
        for (final s in sessions)
          if (s.planId == planId) s
      ];

  PlanSnapshot replacePlan(WorkoutPlan plan, List<PlannedSession> sessions) =>
      PlanSnapshot(
        plans: [
          for (final p in plans)
            if (p.id != plan.id) p,
          plan
        ],
        sessions: [
          for (final s in this.sessions)
            if (s.planId != plan.id) s,
          ...sessions
        ],
        unreadable: unreadable,
      );
}

class PlanStore {
  static const key = 'workout_plans_v1';
  static const schemaVersion = 1;

  static Future<void>? _pending;

  static Future<T> _serial<T>(Future<T> Function() operation) {
    final next =
        _pending == null ? operation() : _pending!.then((_) => operation());
    final barrier =
        next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _pending = barrier;
    return next.whenComplete(() {
      if (identical(_pending, barrier)) _pending = null;
    });
  }

  Future<PlanSnapshot> load() => _serial(_read);

  /// Read-modify-write in one serialized step, so two quick edits never
  /// lose each other.
  Future<PlanSnapshot> update(
          PlanSnapshot Function(PlanSnapshot current) change) =>
      _serial(() async {
        final next = change(await _read());
        final prefs = await SharedPreferences.getInstance();
        final raw = jsonEncode({
          'schema_version': schemaVersion,
          'plans': [for (final p in next.plans) p.toJson()],
          'sessions': [for (final s in next.sessions) s.toJson()],
          if (next.unreadable.isNotEmpty) 'unreadable': next.unreadable,
        });
        if (!await prefs.setString(key, raw)) {
          throw StateError('Cannot write plans');
        }
        LocalDataChanges.notify(LocalDataKind.plans);
        return next;
      });

  static Future<PlanSnapshot> _read() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return const PlanSnapshot();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final version = (json['schema_version'] as num?)?.toInt() ?? 1;
    if (version > schemaVersion) {
      // Written by a newer app: refuse rather than overwrite it.
      throw StateError('Unsupported plan schema_version $version');
    }
    final unreadable = [...(json['unreadable'] as List?) ?? const []];
    final plans = <WorkoutPlan>[];
    for (final p in (json['plans'] as List?) ?? const []) {
      try {
        plans.add(WorkoutPlan.fromJson(p as Map<String, dynamic>));
      } catch (_) {
        unreadable.add({'plan': p});
      }
    }
    final sessions = <PlannedSession>[];
    for (final s in (json['sessions'] as List?) ?? const []) {
      try {
        sessions.add(PlannedSession.fromJson(s as Map<String, dynamic>));
      } catch (_) {
        unreadable.add({'session': s});
      }
    }
    return PlanSnapshot(
        plans: plans, sessions: sessions, unreadable: unreadable);
  }
}
