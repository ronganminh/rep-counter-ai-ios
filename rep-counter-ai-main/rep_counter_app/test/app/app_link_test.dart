import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_link.dart';
import 'package:rep_counter_app/app/app_shell.dart';
import 'package:rep_counter_app/app/app_tab_bar.dart';
import 'package:rep_counter_app/app/os_links.dart';
import 'package:rep_counter_app/app/route_observer.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/domain/workout_plan.dart';
import 'package:rep_counter_app/features/plan/presentation/session_detail_page.dart';
import 'package:rep_counter_app/features/profile/presentation/profile_page.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/presentation/result_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/l10n.dart';

/// N-2a: `repcoach://` links and reminder taps resolve to in-app
/// destinations or to the APP_NAVIGATION_MAP §5 fallbacks.

final monday = LocalDate(2026, 11, 2);

void main() {
  group('parse', () {
    test('reminder payloads and every §5 link', () {
      expect(AppLink.parse('plan-session:s1'),
          const AppLink(AppLinkKind.planSession, 's1'));
      expect(AppLink.parse('repcoach://plan/session/s1'),
          const AppLink(AppLinkKind.planSession, 's1'));
      expect(AppLink.parse('repcoach://workouts/w9/feedback'),
          const AppLink(AppLinkKind.workoutFeedback, 'w9'));
      expect(
          AppLink.parse('repcoach://inbox'), const AppLink(AppLinkKind.inbox));
      expect(AppLink.parse('repcoach://membership'),
          const AppLink(AppLinkKind.membership));
      expect(AppLink.parse('repcoach://friends/requests'),
          const AppLink(AppLinkKind.friendRequests));
      expect(AppLink.parse('repcoach://races/r1'),
          const AppLink(AppLinkKind.race, 'r1'));
      expect(AppLink.parse('repcoach://invites/i1'),
          const AppLink(AppLinkKind.invite, 'i1'));
      expect(AppLink.parse('repcoach://challenges/c1'),
          const AppLink(AppLinkKind.challenge, 'c1'));
    });

    test('anything else is ignored, never guessed', () {
      for (final raw in [
        null,
        '',
        'plan-session:',
        'https://repcoach-ai.duckdns.org/plan/session/s1',
        'com.ronganminh.repcoach://login-callback',
        'repcoach://plan/session',
        'repcoach://plan/session/s1/extra',
        'repcoach://workouts/w1',
        'repcoach://unknown',
      ]) {
        expect(AppLink.parse(raw), isNull, reason: raw);
      }
    });
  });

  late DateTime now;
  late List<WorkoutRecord> history;
  late PlanRepository repo;
  late AppLinkRouter router;
  var n = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 11, 2, 9);
    history = [];
    repo = PlanRepository(
        loadWorkouts: () async => history,
        now: () => now,
        newId: () => 'id${++n}');
    router = AppLinkRouter(plans: repo, loadWorkouts: () async => history);
  });

  Future<String> todayId() async {
    await repo.activate(PlanTemplates.beginnerPlan(
        id: 'plan', startDate: monday, timezone: 'UTC', now: now));
    return (await repo.load())!.todaySession!.id;
  }

  group('resolve', () {
    test('a planned session opens; done or gone falls back home', () async {
      final id = await todayId();
      final open = await router.resolve(AppLink(AppLinkKind.planSession, id));
      expect((open as OpenSession).sessionId, id);
      final gone =
          await router.resolve(const AppLink(AppLinkKind.planSession, 'nope'));
      expect((gone as LinkFallback).notice, LinkNotice.sessionGone);
      expect(gone.tab, AppTab.home);
      history.addAll([
        _record('w1', now, 'push_up', 18),
        _record('w2', now, 'curl', 30),
        _record('w3', now, 'overhead_extension', 20),
      ]);
      final done = await router.resolve(AppLink(AppLinkKind.planSession, id));
      expect((done as LinkFallback).notice, LinkNotice.sessionDone);
    });

    test('a paused plan does not open its sessions', () async {
      final id = await todayId();
      await repo.setStatus(PlanStatus.paused);
      final r = await router.resolve(AppLink(AppLinkKind.planSession, id));
      expect((r as LinkFallback).notice, LinkNotice.sessionGone);
    });

    test('workout feedback opens the saved workout or Progress', () async {
      history.add(_record('w1', now, 'push_up', 12));
      final r = await router
          .resolve(const AppLink(AppLinkKind.workoutFeedback, 'w1'));
      expect((r as OpenWorkout).record.id, 'w1');
      final gone =
          await router.resolve(const AppLink(AppLinkKind.workoutFeedback, 'x'));
      expect((gone as LinkFallback).tab, AppTab.progress);
      expect(gone.notice, LinkNotice.workoutGone);
    });

    test('inbox, membership and account-only links fall back', () async {
      final inbox = await router.resolve(const AppLink(AppLinkKind.inbox));
      expect((inbox as LinkFallback).tab, AppTab.home);
      expect(inbox.notice, isNull);
      final m = await router.resolve(const AppLink(AppLinkKind.membership));
      expect((m as LinkFallback).tab, AppTab.profile);
      for (final kind in [
        AppLinkKind.friendRequests,
        AppLinkKind.race,
        AppLinkKind.invite,
        AppLinkKind.challenge,
      ]) {
        final r = await router.resolve(AppLink(kind, 'x'));
        expect((r as LinkFallback).notice, LinkNotice.needsAccount);
      }
    });
  });

  group('shell', () {
    late StreamController<String> links;
    setUp(() => links = StreamController<String>.broadcast());
    tearDown(() => links.close());

    Future<void> pumpShell(WidgetTester tester,
        {Future<String?> Function()? initial, Stream<String>? stream}) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final locale = LocaleController(AppLanguage.en);
      addTearDown(locale.dispose);
      await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(
          theme: RepCoachTheme.dark(),
          locale: AppLanguage.en.locale,
          supportedLocales: testSupportedLocales,
          localizationsDelegates: testLocalizationsDelegates,
          navigatorObservers: [appRouteObserver],
          home: AppShell(
              links: stream ?? links.stream,
              initialLink: initial ?? () async => null,
              linkRouter: router),
        ),
      ));
      await settle(tester);
    }

    testWidgets('a reminder that launched the app opens its session',
        (tester) async {
      final id = (await tester.runAsync(todayId))!;
      await pumpShell(tester, initial: () async => 'plan-session:$id');
      await settle(tester);
      expect(find.byType(SessionDetailPage), findsOneWidget);
    });

    testWidgets('a tap while a page is on top waits until the shell is back',
        (tester) async {
      final id = (await tester.runAsync(todayId))!;
      history.add(_record('w1', now, 'push_up', 12));
      await pumpShell(tester);
      final shell = tester.element(find.byType(AppShell));
      Navigator.of(shell).push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('live workout'))));
      await settle(tester);
      links.add('plan-session:$id');
      await settle(tester);
      expect(find.byType(SessionDetailPage), findsNothing,
          reason: 'never over a workout');
      Navigator.of(tester.element(find.text('live workout'))).pop();
      await settle(tester);
      expect(find.byType(SessionDetailPage), findsOneWidget);
    });

    testWidgets('fallbacks switch tab and say why', (tester) async {
      await pumpShell(tester);
      links.add('repcoach://membership');
      await settle(tester);
      expect(find.byType(ProfilePage), findsOneWidget);
      links.add('repcoach://plan/session/nope');
      await settle(tester);
      expect(
          find.text('That session is no longer in your plan.'), findsOneWidget);
    });

    testWidgets(
        'X-1: OS links reach the router; missing entities fall back; '
        'the auth callback is left alone', (tester) async {
      final os = StreamController<String>.broadcast();
      addTearDown(os.close);
      final id = (await tester.runAsync(todayId))!;
      await pumpShell(tester,
          stream: mergeLinkStreams(
              [links.stream, osRepcoachLinks(source: os.stream)]));
      os.add('com.ronganminh.repcoach://login-callback?code=abc');
      os.add('https://repcoach-ai.duckdns.org/plan/session/$id');
      await settle(tester);
      expect(find.byType(SessionDetailPage), findsNothing);
      os.add('repcoach://plan/session/missing');
      await settle(tester);
      expect(
          find.text('That session is no longer in your plan.'), findsOneWidget);
      os.add('repcoach://plan/session/$id');
      await settle(tester);
      expect(find.byType(SessionDetailPage), findsOneWidget);
    });

    testWidgets('workout feedback opens the saved result read-only',
        (tester) async {
      history.add(_record('w1', now, 'push_up', 12));
      await pumpShell(tester);
      links.add('repcoach://workouts/w1/feedback');
      await settle(tester);
      expect(find.byType(ResultPage), findsOneWidget);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

WorkoutRecord _record(String id, DateTime at, String exercise, int reps) =>
    WorkoutRecord(
      id: id,
      exerciseId: exercise,
      exerciseName: exercise,
      startedAt: at,
      durationSeconds: 60,
      reps: reps,
      sets: 1,
      targetReps: null,
      poseFrames: 0,
      readyFrames: 0,
      lostFrames: 0,
    );
