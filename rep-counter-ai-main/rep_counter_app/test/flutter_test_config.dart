import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/workout/data/workout_database.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Every test gets a fresh in-memory workout database (F-3). The no-isolate
/// FFI factory completes inside the widget tester's fake-async zone, like the
/// SharedPreferences mock the tests already use.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  WorkoutDatabase.pathOverride = inMemoryDatabasePath;
  void reset() {
    WorkoutDatabase.close();
    WorkoutHistoryStore.resetForTest();
  }

  setUp(reset);
  tearDown(reset);
  await testMain();
}
