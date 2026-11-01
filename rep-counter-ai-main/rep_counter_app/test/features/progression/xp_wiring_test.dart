import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/achievements/achievement.dart';
import 'package:rep_counter_app/features/auth/application/auth_scope.dart';
import 'package:rep_counter_app/features/progression/presentation/xp_widgets.dart';
import 'package:rep_counter_app/features/progression/supabase_xp_api.dart';
import 'package:rep_counter_app/features/progression/xp.dart';
import 'package:rep_counter_app/features/progression/xp_controller.dart';
import 'package:rep_counter_app/features/sync/cloud_sync.dart';
import 'package:rep_counter_app/features/sync/sync_controller.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/contract_rpc.dart';
import '../../support/l10n.dart';
import '../../support/sync_fixtures.dart';

/// The server awards XP when a workout syncs (the database trigger); this
/// stands in for it, with the same rules.
class XpAwardingServer extends TestServer {
  XpAwardingServer(this.xp);
  final InMemoryXpServer xp;

  @override
  Future<List<SyncWorkout>> push(List<SyncWorkout> workouts) async {
    final stored = await super.push(workouts);
    for (final w in stored.where((w) => !w.isTombstone)) {
      xp.onWorkoutSynced(XpWorkout(
          clientId: w.clientId,
          reps: (w.raw['reps'] as num).toInt(),
          durationSeconds: (w.raw['duration_seconds'] as num).toInt(),
          manual: w.raw['source'] == 'manual'));
      if (!xp.unlocked.any((u) => u.id == 'firstWorkout')) {
        xp.unlocked.add(UnlockedAchievement('firstWorkout', DateTime.utc(2026)));
      }
    }
    return stored;
  }
}

void main() {
  final contract = loadContract('xp');
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SupabaseXpApi.achievements', () {
    test('reads achievements_list rows (contract)', () async {
      final rpc = ContractRpc(contract, (fn, p) {
        final rows = [
          {'achievement_id': 'firstWorkout', 'unlocked_at': '2026-10-30T08:00:00Z'},
          {'achievement_id': 'streak7', 'unlocked_at': '2026-10-31T08:00:00Z'},
        ];
        for (final r in rows) {
          expect(r.keys.toSet(), contractKeys(contract, 'achievement_row'));
          expect(contractKeys(contract, 'achievement_ids'),
              contains(r['achievement_id']));
        }
        return rows;
      });
      final list = await SupabaseXpApi(rpc).achievements();
      expect(list.map((a) => a.id), ['firstWorkout', 'streak7']);
      expect(rpc.calls, ['achievements_list']);
    });

    test('the contract ids are exactly the app achievements', () {
      expect(contractKeys(contract, 'achievement_ids'),
          {for (final id in AchievementId.values) id.name});
    });

    test('a malformed answer is a backend error', () async {
      await expectLater(
          SupabaseXpApi(ContractRpc(contract, (fn, p) => {'x': 1}))
              .achievements(),
          throwsA(isA<BackendException>()));
    });
  });

  group('XpController', () {
    test('off unless the flag is on', () async {
      expect(Xp.enabled, isFalse);
      final (auth, _) = await authFor('a@x.com');
      expect(createXpController(auth), isNull);
    });

    test('reads after each sync round; deleting keeps XP (D-05)', () async {
      final xp = InMemoryXpServer();
      final server = XpAwardingServer(xp);
      final (auth, _) = await authFor('a@x.com');
      final sync = SyncController(
          auth: auth,
          workoutsApi: server,
          debounce: const Duration(days: 1),
          retryDelays: const []);
      addTearDown(sync.dispose);
      final c = XpController(auth: auth, api: xp, sync: sync);
      addTearDown(c.dispose);
      sync.start();
      await pumpEventQueue();
      expect(c.progress!.xpTotal, 0);

      final store = WorkoutHistoryStore();
      await store.save(workout('w', reps: 20));
      await sync.syncNow();
      await pumpEventQueue();
      expect(c.progress!.xpTotal, 30);
      expect(c.achievements, [AchievementId.firstWorkout]);

      await store.delete('w');
      await sync.syncNow();
      await pumpEventQueue();
      expect(c.progress!.xpTotal, 30);
      expect(c.achievements, [AchievementId.firstWorkout]);
    });

    test('a failed read keeps the last values; guests see nothing', () async {
      final xp = _FlakyXp();
      final (auth, _) = await authFor('a@x.com');
      final c = XpController(auth: auth, api: xp);
      await pumpEventQueue();
      expect(c.progress!.xpTotal, 60);
      xp.fail = true;
      await c.refresh();
      expect(c.failed, isTrue);
      expect(c.progress!.xpTotal, 60);
      await auth.signOut();
      expect(c.progress, isNull);
    });
  });

  group('screens', () {
    Future<XpController> controller(WidgetTester tester) async =>
        (await tester.runAsync(() async {
          final (auth, _) = await authFor('a@x.com');
          final xp = InMemoryXpServer()
            ..events.add((type: 'workout', id: 'w', amount: 110))
            ..unlocked.addAll([
              UnlockedAchievement('firstWorkout', DateTime.utc(2026, 10, 1)),
              UnlockedAchievement('streak7', DateTime.utc(2026, 10, 8)),
            ]);
          final c = XpController(auth: auth, api: xp);
          await pumpEventQueue();
          return c;
        }))!;

    Future<void> pump(WidgetTester tester, XpController c, Widget child,
        AppLanguage language) async {
      final locale = LocaleController(language);
      addTearDown(locale.dispose);
      await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: AuthScope(
          controller: c.auth,
          child: XpScope(
            controller: c,
            child: MaterialApp(
              theme: RepCoachTheme.dark(),
              locale: language.locale,
              supportedLocales: testSupportedLocales,
              localizationsDelegates: testLocalizationsDelegates,
              home: Scaffold(body: ListView(children: [child])),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    for (final (language, level, value, toGo, streak) in [
      (AppLanguage.en, 'Level 2', 'LV 2 · 110 / 200 XP', '90 XP to Level 3',
          '7-Day Streak'),
      (AppLanguage.vi, 'Cấp 2', 'Cấp 2 · 110 / 200 XP', 'Còn 90 XP để lên Cấp 3',
          'Streak 7 ngày'),
    ]) {
      testWidgets('level card and achievements (${language.name})',
          (tester) async {
        final c = await controller(tester);
        await pump(
            tester,
            c,
            const Column(children: [XpLevelCard(), XpAchievementsSection()]),
            language);
        expect(find.byKey(const Key('xp-level-card')), findsOneWidget);
        final meter = tester.getSemantics(find.byKey(const Key('xp-level-card')));
        expect(meter.label, contains(level));
        expect(meter.label, contains(value));
        expect(meter.label, contains(toGo));
        expect(find.text(streak), findsOneWidget);
        c.dispose();
      });
    }

    testWidgets('guests see no XP', (tester) async {
      final c = (await tester.runAsync(() async {
        final (auth, _) = await authFor(null);
        return XpController(auth: auth, api: InMemoryXpServer());
      }))!;
      await pump(tester, c,
          const Column(children: [XpLevelCard(), XpAchievementsSection()]),
          AppLanguage.en);
      expect(find.byKey(const Key('xp-level-card')), findsNothing);
      expect(find.text('Achievements'), findsNothing);
      c.dispose();
    });
  });
}

class _FlakyXp implements XpApi {
  bool fail = false;

  @override
  Future<XpProgress> progress() async {
    if (fail) throw const BackendException('network');
    return const XpProgress(60);
  }

  @override
  Future<List<UnlockedAchievement>> achievements() async => const [];
}
