import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/features/auth/application/auth_controller.dart';
import 'package:rep_counter_app/features/plan/data/plan_store.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/domain/workout_plan.dart';
import 'package:rep_counter_app/features/sync/cloud_sync.dart';
import 'package:rep_counter_app/features/sync/plan_sync.dart';
import 'package:rep_counter_app/features/sync/sync_controller.dart';
import 'package:rep_counter_app/features/sync/sync_scope.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/widgets/status_badges.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_fixtures.dart';

/// A-2 wiring: when sync runs, what it uploads, and that failures never
/// lose a workout.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = WorkoutHistoryStore();
  late TestServer server;
  late TestServer planServer;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = TestServer();
    planServer = TestServer();
  });

  Future<SyncController> controllerFor(AuthController auth,
      {bool plans = false}) async {
    final c = SyncController(
        auth: auth,
        workoutsApi: server,
        plansApi: plans ? planServer : null,
        debounce: Duration.zero,
        retryDelays: const []);
    addTearDown(c.dispose);
    c.start();
    await pumpEventQueue();
    await c.syncNow();
    return c;
  }

  test('off unless both flags are on', () async {
    expect(CloudSync.enabled, isFalse);
    final (auth, _) = await authFor('a@x.com');
    expect(createSyncController(auth), isNull);
  });

  test('a guest never calls the server', () async {
    final (auth, _) = await authFor(null);
    await store.save(workout('g'));
    final c = await controllerFor(auth);
    expect(c.badge, SyncBadgeState.guestOnly);
    expect(server.pulls + server.pushes, 0);
    expect(c.mergeOffered, isFalse);
  });

  test('signed in: pulls the account, pushes new workouts, badge synced',
      () async {
    await server.seed(workout('from-tablet', reps: 33), clientId: 'c-tab');
    final (auth, _) = await authFor('a@x.com');
    final c = await controllerFor(auth);
    expect((await store.load()).single.reps, 33);
    expect(c.badge, SyncBadgeState.synced);

    await store.save(workout('new', reps: 12));
    await pumpEventQueue();
    await c.syncNow();
    expect(server.live.length, 2);
    expect(c.pending, 0);
    expect(c.badge, SyncBadgeState.synced);
  });

  test('offline or 5xx: nothing lost, "N waiting", then synced once',
      () async {
    final (auth, _) = await authFor('a@x.com');
    final c = await controllerFor(auth);
    server.fail = const BackendException('network');
    await store.save(workout('w1'));
    await store.save(workout('w2'));
    await c.syncNow();
    expect(c.badge, SyncBadgeState.offline);
    expect(c.pending, 2);
    expect((await store.load()).length, 2);

    server.fail = const BackendException('503');
    await c.syncNow();
    expect(c.badge, SyncBadgeState.failed);
    expect(c.pending, 2);

    server.fail = null;
    await c.syncNow();
    expect(c.badge, SyncBadgeState.synced);
    expect(server.live.length, 2);
    await c.syncNow();
    expect(server.live.length, 2, reason: 'never uploaded twice');
  });

  test('401 marks the session expired and keeps the changes', () async {
    final (auth, _) = await authFor('a@x.com');
    final c = await controllerFor(auth);
    server.fail = const BackendException('http_401', status: 401);
    await store.save(workout('w'));
    await c.syncNow();
    await pumpEventQueue();
    expect(auth.state, isA<AuthExpired>());
    expect(c.pending, 1);
    expect((await store.load()).length, 1);
  });

  test('guest workouts: offered, previewed, merged without duplicates',
      () async {
    // Guest workouts, one already in the account (same client id, same
    // content), one that differs.
    await store.save(workout('only-phone', reps: 5));
    await store.save(workout('same', reps: 6));
    await store.save(workout('differs', reps: 7));
    final ids = {
      for (final r in await store.load())
        r.id: (await const WorkoutSyncSourceProbe().clientIdOf(r.id))
    };
    await server.seed(workout('same', reps: 6), clientId: ids['same']!);
    await server.seed(workout('differs', reps: 70), clientId: ids['differs']!);
    await server.seed(workout('only-account', reps: 9), clientId: 'c-acc');

    final (auth, _) = await authFor('a@x.com');
    final c = await controllerFor(auth);
    expect(c.mergeOffered, isTrue);
    expect(c.undecided, 3);
    // Nothing of the phone's was uploaded before the choice.
    expect(server.rows[ids['differs']]!.raw['reps'], 70);

    final plan = await c.prepareMerge();
    expect(plan.preview.toUpload, 1);
    expect(plan.preview.alreadyInAccount, 1);
    expect(plan.preview.needsChoice, 1);

    await c.applyMerge(plan, keepPhone: false);
    expect(c.mergeOffered, isFalse);
    final local = {for (final r in await store.load()) r.id: r.reps};
    expect(local, {'only-phone': 5, 'same': 6, 'differs': 70, 'only-account': 9});
    expect(server.live.length, 4);
    expect(server.rows[ids['differs']]!.raw['reps'], 70);
  });

  test('merge keeping the phone version wins on the server', () async {
    await store.save(workout('differs', reps: 7));
    final id = await const WorkoutSyncSourceProbe().clientIdOf('differs');
    await server.seed(workout('differs', reps: 70), clientId: id);
    final (auth, _) = await authFor('a@x.com');
    final c = await controllerFor(auth);
    await c.applyMerge(await c.prepareMerge(), keepPhone: true);
    expect(server.rows[id]!.raw['reps'], 7);
    expect((await store.load()).single.reps, 7);
  });

  test('keep on this phone: never uploaded, not offered again', () async {
    await store.save(workout('mine'));
    final (auth, _) = await authFor('a@x.com');
    final c = await controllerFor(auth);
    await c.keepOnPhone();
    expect(c.mergeOffered, isFalse);
    await c.syncNow();
    expect(server.live, isEmpty);
  });

  test('a failed merge read changes nothing', () async {
    await store.save(workout('mine'));
    final (auth, _) = await authFor('a@x.com');
    final c = await controllerFor(auth);
    server.fail = const BackendException('network');
    await expectLater(c.prepareMerge(), throwsA(isA<BackendException>()));
    expect(c.undecided, 1);
    expect(server.live, isEmpty);
  });

  test('D-20 "my account": tombstones everywhere, the phone keeps its copy',
      () async {
    final (auth, _) = await authFor('a@x.com');
    final c = await controllerFor(auth);
    await store.save(workout('w1'));
    await store.save(workout('w2'));
    await c.syncNow();
    await server.seed(workout('tablet-only'), clientId: 'c-t');
    expect(server.live.length, 3);

    await c.deleteFromAccount();
    expect(server.live, isEmpty);
    expect(server.rows.length, 3, reason: 'tombstones reach other phones');
    expect((await store.load()).length, 2);
    await c.syncNow();
    expect(server.live, isEmpty, reason: 'kept copies never go up again');
    expect((await store.load()).length, 2);

    server.fail = const BackendException('network');
    await expectLater(c.deleteFromAccount(), throwsA(isA<BackendException>()));
  });

  test('sign out: new workouts stay local and are offered at sign-in',
      () async {
    final (auth, repo) = await authFor('a@x.com');
    final c = await controllerFor(auth);
    await auth.signOut();
    await pumpEventQueue();
    expect(c.badge, SyncBadgeState.guestOnly);
    await store.save(workout('while-out'));
    await c.syncNow();
    expect(server.live, isEmpty);

    repo.saved = sessionFor('a@x.com');
    await auth.restore();
    await pumpEventQueue();
    expect(c.mergeOffered, isTrue);
  });

  test('plans: saved plans go up, the account plan comes down', () async {
    final (auth, _) = await authFor('a@x.com');
    final c = await controllerFor(auth, plans: true);
    final now = DateTime.utc(2026, 10, 31);
    final plan = PlanTemplates.beginnerPlan(
            id: 'p1',
            startDate: LocalDate(2026, 11, 2),
            timezone: 'UTC',
            now: now)
        .copyWith(status: PlanStatus.active);
    await PlanStore().update((s) => s.replacePlan(plan, const []));
    await pumpEventQueue();
    await c.syncNow();
    expect(planServer.live, {'p1'});
    expect(c.pending, 0);
    await c.syncNow();
    expect(planServer.pushes, 1, reason: 'unchanged plans are not resent');

    // Another phone renamed it later.
    final doc = PlanSyncSource.docOf(
        plan.copyWith(name: 'Renamed', updatedAt: now.add(
            const Duration(days: 1))),
        const []);
    await planServer.push([
      SyncWorkout(
          clientId: 'p1',
          raw: doc,
          clientUpdatedAt: DateTime.now().toUtc().add(const Duration(hours: 1)))
    ]);
    await c.syncNow();
    expect((await PlanStore().load()).plans.single.name, 'Renamed');
    expect(c.pending, 0);
  });
}

/// Reads a workout's client id through the store's queue.
class WorkoutSyncSourceProbe {
  const WorkoutSyncSourceProbe();
  Future<String> clientIdOf(String id) => WorkoutHistoryStore.exclusive(
      (db) async => (await db!.db.query('workouts',
              columns: ['client_id'], where: 'id = ?', whereArgs: [id]))
          .single['client_id'] as String);
}
