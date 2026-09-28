import 'package:flutter/material.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/legal/settings_page.dart';
import '../features/workout/presentation/history_page.dart';
import '../theme/app_colors.dart';
import '../core/i18n/locale_controller.dart';
import '../widgets/product_ui.dart';
import '../exercise.dart';
import '../features/plan/presentation/plan_today_sheet.dart';
import 'route_observer.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with RouteAware {
  int _index = 0;
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
    if (_index == 0) setState(() => _revision++);
  }

  void _train() {
    setState(() => _index = 0);
    showPlanTodaySheet(context, pushUp);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        // Reopen stores on tab changes and after returning from workout/results.
        body: KeyedSubtree(
            key: ValueKey('$_index:$_revision'),
            child: switch (_index) {
              1 => HistoryPage(onTrain: _train),
              2 => const SettingsPage(),
              _ => const HomeScreen(),
            }),
        bottomNavigationBar: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            indicatorColor: AppColors.accentTint,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.fitness_center_outlined),
                selectedIcon:
                    const Icon(Icons.fitness_center, color: AppColors.accent),
                label: context.tr('Tập', 'Train'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.history_outlined),
                selectedIcon:
                    const Icon(Icons.history, color: AppColors.accent),
                label: context.s.historyTitle,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon:
                    const Icon(Icons.settings, color: AppColors.accent),
                label: context.s.settings,
              ),
            ],
          ),
        ),
      );
}
