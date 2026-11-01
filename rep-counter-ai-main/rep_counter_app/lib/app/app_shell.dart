import 'dart:async';

import 'package:flutter/material.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/exercises/presentation/exercise_picker_screen.dart';
import '../features/inbox/inbox_controller.dart';
import '../features/inbox/presentation/inbox_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/social/presentation/friends_page.dart';
import '../features/social/supabase_social_api.dart';
import '../features/workout/presentation/history_page.dart';
import '../exercise.dart';
import '../features/plan/application/reminder_service.dart';
import '../features/plan/presentation/plan_today_sheet.dart';
import '../features/plan/presentation/session_detail_page.dart';
import '../features/workout/presentation/result_page.dart';
import '../core/i18n/l10n.dart';
import '../features/workout/presentation/recovery_page.dart';
import '../widgets/app_feedback.dart';
import '../widgets/product_ui.dart';
import 'app_link.dart';
import 'os_links.dart';
import 'app_tab_bar.dart';
import 'route_observer.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.links, this.initialLink, this.linkRouter});

  /// N-2a: links that arrive while the app runs (reminder taps by default).
  final Stream<String>? links;

  /// The link that launched the app, if any (a tapped reminder by default).
  final Future<String?> Function()? initialLink;
  final AppLinkRouter? linkRouter;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with RouteAware {
  AppTab _tab = AppTab.home;
  int _revision = 0;
  StreamSubscription<String>? _linkSub, _inAppSub;
  late final _linkRouter = widget.linkRouter ??
      AppLinkRouter(
          socialEnabled: () =>
              context.getInheritedWidgetOfExactType<SocialScope>() != null,
          inboxEnabled: () =>
              context.getInheritedWidgetOfExactType<InboxScope>() != null);

  /// A link that arrived while something was over the shell (a workout,
  /// results, a sheet): delivered when the shell is back on top, never over
  /// a live workout (APP_NAVIGATION_MAP §5).
  AppLink? _pendingLink;

  @override
  void initState() {
    super.initState();
    // W-5: offer an unfinished workout once the shell is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
    // Reminder taps and `repcoach://` links from the OS (X-1).
    _linkSub = (widget.links ??
            mergeLinkStreams(
                [LocalNotificationsPlatform.opened, osRepcoachLinks()]))
        .listen((raw) => _openLink(AppLink.parse(raw)));
    // Links opened inside the app (inbox items).
    _inAppSub =
        InAppLinks.stream.listen((raw) => _openLink(AppLink.parse(raw)));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final raw = await (widget.initialLink ??
            () => LocalNotificationsPlatform().launchPayload())();
        if (mounted) await _openLink(AppLink.parse(raw));
      } catch (_) {
        // No notifications plugin (tests, unsupported platform): no link.
      }
    });
  }

  Future<void> _openLink(AppLink? link) async {
    if (link == null || !mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      _pendingLink = link;
      return;
    }
    final LinkTarget target;
    try {
      target = await _linkRouter.resolve(link);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    switch (target) {
      case OpenSession(:final sessionId):
        await navigator.push(MaterialPageRoute<void>(
            builder: (_) => SessionDetailPage(sessionId: sessionId)));
      case OpenWorkout(:final record):
        await navigator.push(MaterialPageRoute<void>(
            builder: (_) => ResultPage(record: record, readOnly: true)));
      case OpenFriends(:final inviteCode):
        await openFriends(context, inviteCode: inviteCode);
      case OpenInbox():
        await openInbox(context);
      case LinkFallback(:final tab, :final notice):
        setState(() => _tab = tab);
        final text = switch (notice) {
          LinkNotice.sessionDone => context.tr(
              'Buổi này đã xong. Không có buổi mới nào được bắt đầu.',
              'That session is already done. Nothing new was started.'),
          LinkNotice.sessionGone => context.tr(
              'Buổi này không còn trong kế hoạch của bạn.',
              'That session is no longer in your plan.'),
          LinkNotice.workoutGone =>
            context.tr('Buổi tập này đã bị xoá.', 'That workout was deleted.'),
          LinkNotice.needsAccount => context.tr(
              'Liên kết này cần tài khoản, hiện chưa có trong ứng dụng.',
              'This link needs an account, which the app does not have yet.'),
          null => null,
        };
        if (text != null) AppToast.show(context, text);
    }
  }

  Future<void> _recover() async {
    try {
      final outcome = await RecoveryPage.showIfPending(context);
      if (!mounted || outcome == null) return;
      if (outcome == RecoveryOutcome.savedPartial) {
        AppToast.show(context, context.l10n.resultsSavedPartial);
      }
      setState(() => _revision++);
    } catch (_) {
      // Recovery must never stop the app from opening; the draft stays.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _linkSub?.cancel();
    _inAppSub?.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    // History refreshes after its own detail route returns and owns Undo state.
    // Replacing that widget here could discard the pending delete/undo result.
    if (_tab == AppTab.home) setState(() => _revision++);
    final pending = _pendingLink;
    _pendingLink = null;
    if (pending != null) _openLink(pending);
  }

  // Train is the centre action (D-01): it opens the start sheet over the
  // current tab. The workout itself is pushed on the root navigator, so the
  // tab bar never shows over the camera or results (D-02).
  void _train() => showPlanTodaySheet(context, pushUp);

  @override
  Widget build(BuildContext context) => Scaffold(
        // Reopen stores on tab changes and after returning from workout/results.
        body: KeyedSubtree(
            key: ValueKey('${_tab.name}:$_revision'),
            child: switch (_tab) {
              AppTab.exercises => const ExercisePickerScreen(),
              AppTab.progress => ProgressPage(onTrain: _train),
              AppTab.profile => const ProfilePage(),
              AppTab.home || AppTab.train => const HomeScreen(),
            }),
        bottomNavigationBar: AppTabBar(
          current: _tab,
          onSelected: (tab) => setState(() => _tab = tab),
          onTrain: _train,
        ),
      );
}
