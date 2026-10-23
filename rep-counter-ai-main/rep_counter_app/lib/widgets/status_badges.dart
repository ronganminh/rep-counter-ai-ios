import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Per-workout / global sync state shown by [SyncStatusBadge]
/// (MASTER_DESIGN_HANDOFF §7). Today the app is local-only, so production
/// code can only show [guestOnly]; the others wait for sync (A-2).
enum SyncBadgeState { guestOnly, pending, offline, failed, synced }

/// Sync status chip (COMPONENT_REGISTRY #19). State is carried by text and
/// icon, never by colour alone.
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key, required this.state, this.count = 0});

  final SyncBadgeState state;

  /// Workouts waiting to sync (pending / offline).
  final int count;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (label, icon, color) = switch (state) {
      SyncBadgeState.guestOnly => (
          l.syncGuestOnly,
          LucideIcons.smartphone,
          AppColors.text2
        ),
      SyncBadgeState.pending => (
          l.syncPending(count),
          LucideIcons.cloud,
          AppColors.warningText
        ),
      SyncBadgeState.offline => (
          l.syncOffline(count),
          LucideIcons.cloudOff,
          AppColors.warningText
        ),
      SyncBadgeState.failed => (
          l.syncFailedTitle,
          LucideIcons.cloudAlert,
          AppColors.dangerText
        ),
      SyncBadgeState.synced => (
          l.syncSynced,
          LucideIcons.cloudCheck,
          AppColors.success
        ),
    };
    return _Chip(label: label, icon: icon, color: color);
  }
}

/// "On-device" privacy badge (COMPONENT_REGISTRY #23): camera frames are
/// processed on the phone and never uploaded.
class PrivacyBadge extends StatelessWidget {
  const PrivacyBadge({super.key});

  @override
  Widget build(BuildContext context) => _Chip(
        label: AppLocalizations.of(context).workoutOnDevice,
        icon: LucideIcons.shieldCheck,
        color: AppColors.success,
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        liveRegion: true,
        label: label,
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 26),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadius.r8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  style: AppTypography.body14.copyWith(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      );
}
