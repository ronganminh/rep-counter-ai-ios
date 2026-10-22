import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Tabs of the v2 shell (PRODUCT_DECISIONS D-01). [train] is an action, not
/// a page: it opens the start-workout sheet.
enum AppTab { home, exercises, train, progress, profile }

/// Five-item bottom bar with the raised Train action (COMPONENT_REGISTRY #1,
/// DESIGN_SYSTEM_TOKENS `layout.bottomTabs`).
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.current,
    required this.onSelected,
    required this.onTrain,
  });

  static const barHeight = 49.0;
  static const trainDiameter = 52.0;
  static const trainOffset = 22.0;
  static const trainRing = 5.0;

  final AppTab current;
  final ValueChanged<AppTab> onSelected;
  final VoidCallback onTrain;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget item(AppTab tab, IconData icon, String label) => Expanded(
          child: _TabItem(
            icon: icon,
            label: label,
            selected: current == tab,
            onTap: () => onSelected(tab),
          ),
        );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l.navTabsLabel,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: barHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                item(AppTab.home, LucideIcons.house, l.navHome),
                item(AppTab.exercises, LucideIcons.dumbbell, l.navExercises),
                Expanded(
                    child: _TrainButton(label: l.navTrain, onTap: onTrain)),
                item(AppTab.progress, LucideIcons.chartNoAxesColumn,
                    l.navProgress),
                item(AppTab.profile, LucideIcons.circleUser, l.navProfile),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.text3;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.3),
                  style: AppTypography.tab11.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Raised lime disc in the centre of the bar.
class _TrainButton extends StatelessWidget {
  const _TrainButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          key: const Key('tab-train'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: -AppTabBar.trainOffset,
                child: Container(
                  width: AppTabBar.trainDiameter + 2 * AppTabBar.trainRing,
                  height: AppTabBar.trainDiameter + 2 * AppTabBar.trainRing,
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: AppTabBar.trainDiameter,
                    height: AppTabBar.trainDiameter,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.camera,
                        size: 24, color: AppColors.onAccent),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 1.3),
                    style: AppTypography.tab11.copyWith(color: AppColors.text)),
              ),
            ],
          ),
        ),
      );
}
