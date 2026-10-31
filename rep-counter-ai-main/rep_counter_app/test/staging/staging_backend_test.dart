import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/features/credits/ai_credits.dart';
import 'package:rep_counter_app/features/credits/supabase_ai_credits_api.dart';
import 'package:rep_counter_app/features/progression/supabase_xp_api.dart';
import 'package:rep_counter_app/features/progression/xp.dart';
import 'package:rep_counter_app/features/sync/cloud_sync.dart';
import 'package:rep_counter_app/features/sync/supabase_cloud_sync_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Backend v2 on the REAL staging project, through the app's own adapters
/// (the same code a staging build runs). Skipped unless every variable is
/// set, so `flutter test` and CI never touch the network:
///
/// ```
/// SUPABASE_URL=https://rvysencgtomkzwgdjaqh.supabase.co \
/// SUPABASE_ANON_KEY=<staging publishable key> \
/// STAGING_TEST_EMAIL=<you>+rcit1@gmail.com \
/// STAGING_TEST_PASSWORD=<10+ characters> \
/// flutter test test/staging/staging_backend_test.dart --reporter expanded
/// ```
///
/// The account is single use: the last step deletes it (delete-account),
/// so the email must contain `+rcit`. Staging has "Confirm email" ON, so
/// the first run signs up, Supabase mails a link, and the run stops there;
/// open the link, then run again for the full flow. Docs:
/// `docs/implementation/05_SUPABASE_SETUP.md` §11.
void main() {
  final env = Platform.environment;
  final url = env['SUPABASE_URL'] ?? '';
  final key = env['SUPABASE_ANON_KEY'] ?? '';
  final email = env['STAGING_TEST_EMAIL'] ?? '';
  final password = env['STAGING_TEST_PASSWORD'] ?? '';
  final missing = [
    if (url.isEmpty) 'SUPABASE_URL',
    if (key.isEmpty) 'SUPABASE_ANON_KEY',
    if (email.isEmpty) 'STAGING_TEST_EMAIL',
    if (password.isEmpty) 'STAGING_TEST_PASSWORD',
  ];
  final Object skip = missing.isEmpty
      ? (email.contains('+rcit')
          ? false
          : 'STAGING_TEST_EMAIL must contain "+rcit": the run deletes it')
      : 'staging env not set: ${missing.join(', ')}';

  sb.SupabaseClient newClient() => sb.SupabaseClient(url, key,
      authOptions: const sb.AuthClientOptions(
          authFlowType: sb.AuthFlowType.implicit, autoRefreshToken: false));

  late sb.SupabaseClient client;
  late BackendRpc rpc;

  /// Set once signed in; later steps skip without it.
  var signedIn = false;
  final runId = DateTime.now().toUtc().millisecondsSinceEpoch;
  final clientId = 'rcit-$runId';

  void needSession() {
    if (!signedIn) markTestSkipped('not signed in (see the sign-in step)');
  }

  group('staging backend v2', skip: skip, () {
    setUpAll(() {
      client = newClient();
      rpc = SupabaseBackendRpc(client);
    });
    tearDownAll(() => client.dispose());

    test('0. without a session every call is refused', () async {
      final anon = SupabaseBackendRpc(client);
      await expectLater(
          anon.rpc('sync_pull_workouts', {'p_after': 0, 'p_limit': 1}),
          throwsA(isA<BackendException>()));
      await expectLater(
          anon.invoke('ai-request', {}),
          throwsA(isA<BackendException>()
              .having((e) => e.status, 'status', 401)
              .having((e) => e.notSignedIn, 'notSignedIn', isTrue)));
    });

    test('1. sign up, then sign in once the email is confirmed', () async {
      try {
        await client.auth.signUp(email: email, password: password);
      } on sb.AuthException catch (e) {
        // Already registered, or the mail rate limit: sign-in decides.
        printOnFailure('signUp: ${e.code ?? e.statusCode}');
      }
      try {
        await client.auth.signInWithPassword(email: email, password: password);
      } on sb.AuthException catch (e) {
        if (e.code == 'email_not_confirmed') {
          markTestSkipped('Confirm the email sent to $email (open the '
              'link from Supabase), then run again.');
          return;
        }
        fail('sign-in failed: ${e.code ?? e.statusCode} (wrong password '
            'for an existing account?)');
      }
      expect(client.auth.currentUser?.email, email.toLowerCase());
      signedIn = true;
    });

    test('2. sync: push one workout, pull it back, then a tombstone', () async {
      needSession();
      if (!signedIn) return;
      final sync = SupabaseCloudSyncApi(rpc);
      final at = DateTime.now().toUtc();
      final workout =
          SyncWorkout(clientId: clientId, clientUpdatedAt: at, raw: {
        'id': clientId,
        'started_at': at.subtract(const Duration(minutes: 3)).toIso8601String(),
        'exercise_id': 'squat',
        'reps': 20,
        'duration_seconds': 120,
        'source': 'camera',
      });

      final xpBefore = (await SupabaseXpApi(rpc).progress()).xpTotal;
      final stored = await sync.push([workout]);
      expect(stored.single.clientId, clientId);
      expect(stored.single.serverSeq, greaterThan(0));

      final page = await sync.pull(after: stored.single.serverSeq - 1);
      final pulled = page.workouts.singleWhere((w) => w.clientId == clientId);
      expect(pulled.raw['reps'], 20);
      expect(pulled.isTombstone, isFalse);
      expect(await sync.clientIds(), contains(clientId));

      // XP is awarded by the database from the synced row (G-1, Q4).
      final xp = await SupabaseXpApi(rpc).progress();
      expect(
          xp.xpTotal - xpBefore,
          XpRules.forWorkout(
              const XpWorkout(clientId: '', reps: 20, durationSeconds: 120)));

      // Pushing the same row again changes nothing (idempotent, D-09).
      await sync.push([workout]);
      expect((await SupabaseXpApi(rpc).progress()).xpTotal, xp.xpTotal);

      final deleted = SyncWorkout(
          clientId: clientId,
          raw: workout.raw,
          clientUpdatedAt: at.add(const Duration(seconds: 1)),
          deletedAt: at.add(const Duration(seconds: 1)));
      final tomb = (await sync.push([deleted])).single;
      expect(tomb.isTombstone, isTrue);
      expect(tomb.serverSeq, greaterThan(stored.single.serverSeq));
      expect(await sync.clientIds(), isNot(contains(clientId)));
      // No XP revoke on delete (D-05).
      expect((await SupabaseXpApi(rpc).progress()).xpTotal, xp.xpTotal);
    });

    test('3. xp_progress', () async {
      needSession();
      if (!signedIn) return;
      final xp = await SupabaseXpApi(rpc).progress();
      expect(xp.xpTotal, greaterThanOrEqualTo(0));
      expect(xp.level, XpRules.levelFor(xp.xpTotal));
    });

    test('4. ai-request with the JWT charges one credit, once', () async {
      needSession();
      if (!signedIn) return;
      final ai = SupabaseAiCreditsApi(rpc);
      final before = await ai.balance();
      expect(before.weeklyAllowance, before.pro ? 60 : 10);
      if (before.balance == 0) {
        markTestSkipped('no credits left this week (top-up Monday UTC)');
        return;
      }
      final requestId = 'rcit-$runId';
      final answer = await ai.ask(
        requestId: requestId,
        kind: CreditedRequest.coachChat,
        locale: 'vi',
        messages: const [CoachMessage.user('Một câu: squat cần lưu ý gì?')],
      );
      expect(answer.requestId, requestId);
      expect(answer.text.trim(), isNotEmpty);
      expect(answer.balance, before.balance - 1);
      expect((await ai.balance()).balance, before.balance - 1);

      // The same request id is never charged twice (D-09).
      await expectLater(
          ai.ask(
            requestId: requestId,
            kind: CreditedRequest.coachChat,
            locale: 'vi',
            messages: const [CoachMessage.user('again')],
          ),
          throwsA(isA<DuplicateAiRequest>()));
      expect((await ai.balance()).balance, before.balance - 1);
    });

    test('5. delete-account removes the user', () async {
      needSession();
      if (!signedIn) return;
      await rpc.invoke('delete-account', {});
      signedIn = false;
      try {
        await client.auth.signOut();
      } on sb.AuthException {
        // The user is gone; the local session is cleared either way.
      }

      final fresh = newClient();
      addTearDown(fresh.dispose);
      await expectLater(
          fresh.auth.signInWithPassword(email: email, password: password),
          throwsA(isA<sb.AuthException>()
              .having((e) => e.code, 'code', 'invalid_credentials')));
    });
  });
}
