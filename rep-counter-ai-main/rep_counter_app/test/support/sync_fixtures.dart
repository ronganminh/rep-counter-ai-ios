import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/features/auth/application/auth_controller.dart';
import 'package:rep_counter_app/features/auth/domain/auth_repository.dart';
import 'package:rep_counter_app/features/sync/cloud_sync.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';

import 'fake_auth_repository.dart';

/// Shared fixtures for the A-2 sync wiring tests.

WorkoutRecord workout(String id,
        {int reps = 20, DateTime? at, bool manual = false}) =>
    WorkoutRecord(
        id: id,
        exerciseId: 'push_up',
        exerciseName: 'Push-up',
        startedAt: at ?? DateTime.utc(2026, 10, 30, 8),
        durationSeconds: 120,
        reps: reps,
        sets: 1,
        targetReps: null,
        poseFrames: 100,
        readyFrames: 90,
        lostFrames: 0,
        manual: manual);

AuthSession sessionFor(String email) => AuthSession(AuthUser(
    id: 'u-$email',
    email: email,
    emailVerified: true,
    provider: AuthProvider.email));

/// An [AuthController] that restores [email]'s session (null: guest).
Future<(AuthController, FakeAuthRepository)> authFor(String? email) async {
  final repo = FakeAuthRepository(
      saved: email == null ? null : sessionFor(email));
  final auth = AuthController(repo);
  await auth.restore();
  return (auth, repo);
}

/// The in-memory server (last writer by client time wins), able to fail
/// like staging: set [fail] for every call, or [failPush] for pushes only.
class TestServer extends InMemoryCloudSyncApi {
  BackendException? fail, failPush;
  int pulls = 0, pushes = 0;

  @override
  Future<SyncPage> pull({required int after, int limit = 500}) async {
    pulls++;
    if (fail != null) throw fail!;
    return super.pull(after: after, limit: limit);
  }

  @override
  Future<List<SyncWorkout>> push(List<SyncWorkout> workouts) async {
    pushes++;
    if (fail != null) throw fail!;
    if (failPush != null) throw failPush!;
    return super.push(workouts);
  }

  /// A workout saved in the account by another phone.
  Future<void> seed(WorkoutRecord r,
          {required String clientId, DateTime? at, bool deleted = false}) =>
      super.push([
        SyncWorkout(
            clientId: clientId,
            raw: {...r.toJson(), 'client_id': clientId},
            clientUpdatedAt: at ?? DateTime.utc(2026, 10, 30, 9),
            deletedAt: deleted ? (at ?? DateTime.utc(2026, 10, 30, 9)) : null)
      ]);

  Set<String> get live => {
        for (final w in rows.values)
          if (!w.isTombstone) w.clientId
      };
}
