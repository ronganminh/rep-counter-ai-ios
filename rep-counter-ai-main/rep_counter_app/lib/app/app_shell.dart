import 'package:flutter/material.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/exercises/presentation/exercise_picker_screen.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/workout/presentation/history_page.dart';
import '../exercise.dart';
import '../features/plan/presentation/plan_today_sheet.dart';
import 'app_tab_bar.dart';
import 'route_observer.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with RouteAware {
  AppTab _tab = AppTab.home;
  int _revision = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // History refreshes after its own detail route returns and owns Undo state.
    // Replacing that widget here could discard the pending delete/undo result.
    if (_tab == AppTab.home) setState(() => _revision++);
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
              AppTab.progress => HistoryPage(onTrain: _train),
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
