import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';

/// Shared pieces of the AI Coach screens (handoff §3: built from the
/// COMPONENT_REGISTRY, no new tokens). Every control is ≥ 48 × 48 dp and
/// every icon is paired with text (handoff §6).

/// The "COACH" chip that labels AI text (registry #29 family).
class CoachChip extends StatelessWidget {
  const CoachChip({super.key});

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.ptAiChip;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accentTint,
          borderRadius: BorderRadius.circular(AppRadius.r6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.sparkles, size: 12, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(label.toUpperCase(),
              style: AppTypography.caption12.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .4)),
        ]),
      ),
    );
  }
}

/// Remaining AI credits as "{n} of {max} left" (AC-03b). Grey at zero,
/// never red (registry #29).
class CoachCreditsChip extends StatelessWidget {
  const CoachCreditsChip(
      {super.key, required this.remaining, required this.allowance});
  final int remaining, allowance;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.ptCreditsLeft(remaining, allowance);
    final color = remaining > 0 ? AppColors.text : AppColors.text2;
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        key: const Key('coach-credits-chip'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.zap,
              size: 14, color: remaining > 0 ? AppColors.accent : color),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.caption12
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// Uppercase section caption ("COACH'S PICK · TODAY", "WHAT WENT WELL").
class CoachCaption extends StatelessWidget {
  const CoachCaption(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text.toUpperCase(),
                style: AppTypography.caption12.copyWith(
                    color: AppColors.text2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6)),
          ),
        ),
        if (trailing != null) trailing!,
      ]);
}

/// A card (registry #3, r16). [accent] draws the accent border used for
/// coach suggestions that can be applied.
class CoachCard extends StatelessWidget {
  const CoachCard(
      {super.key,
      required this.child,
      this.accent = false,
      this.padding = const EdgeInsets.all(16),
      this.semanticsLabel});
  final Widget child;
  final bool accent;
  final EdgeInsetsGeometry padding;

  /// Region name for screen readers (e.g. "Coach's pick for today").
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: accent ? AppColors.accentBorder : AppColors.border),
      ),
      child: child,
    );
    return semanticsLabel == null
        ? box
        : Semantics(container: true, label: semanticsLabel, child: box);
  }
}

/// "General fitness guidance, not medical advice. AI can be wrong."
class CoachDisclaimer extends StatelessWidget {
  const CoachDisclaimer({super.key});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.info, size: 14, color: AppColors.text2),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(context.l10n.coachGeneralFitnessGuidanceNot,
                style:
                    AppTypography.caption12.copyWith(color: AppColors.text2)),
          ),
        ],
      );
}

/// A one-line note with a small icon ("1 AI credit used", "Each message
/// uses 1 AI credit"). Text stays `text2` (D-25 contrast).
class CoachNote extends StatelessWidget {
  const CoachNote(this.text,
      {super.key, this.icon = LucideIcons.zap, this.center = false});
  final String text;
  final IconData icon;
  final bool center;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment:
            center ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.text2),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                textAlign: center ? TextAlign.center : TextAlign.start,
                style:
                    AppTypography.caption12.copyWith(color: AppColors.text2)),
          ),
        ],
      );
}

/// Generating / thinking (AC-01c, AC-02b, AC-03c): a static skeleton and a
/// ring. The ring does not turn when the system asks for reduced motion;
/// the status is announced once (live region).
class CoachBusy extends StatelessWidget {
  const CoachBusy({super.key, required this.title, this.body, this.lines = 3});
  final String title;
  final String? body;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          container: true,
          label: [title, if (body != null) body!].join('. '),
          excludeSemantics: true,
          child: Row(children: [
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                key: const Key('coach-busy-ring'),
                strokeWidth: 2.5,
                color: AppColors.accent,
                backgroundColor: AppColors.track,
                // A fixed arc instead of a spinner under Reduce Motion.
                value: still ? .3 : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppTypography.row15)),
          ]),
        ),
        if (body != null) ...[
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Text(body!,
                style: AppTypography.body14.copyWith(color: AppColors.text2)),
          ),
        ],
        const SizedBox(height: 16),
        for (var i = 0; i < lines; i++) ...[
          Container(
            height: 14,
            margin: EdgeInsets.only(right: i.isOdd ? 64 : 0),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.r6),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// A status hero (registry #14): icon tile, title, body, and actions below
/// (failure, no credits, not enough data, offline).
class CoachStatus extends StatelessWidget {
  const CoachStatus(
      {super.key,
      required this.icon,
      required this.title,
      this.body,
      this.children = const []});
  final IconData icon;
  final String title;
  final String? body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadius.r12),
              ),
              child: Icon(icon, color: AppColors.text2, size: 24),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
              header: true, child: Text(title, style: AppTypography.title20)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!,
                style: AppTypography.body14.copyWith(color: AppColors.text2)),
          ],
          if (children.isNotEmpty) const SizedBox(height: 16),
          ...children,
        ],
      );
}

/// A text link with a 48 dp target ("See options", "Undo", "New suggestion").
class CoachLink extends StatelessWidget {
  const CoachLink(
      {super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null ? AppColors.text2 : AppColors.text;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: color,
        disabledForegroundColor: AppColors.text2,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(label,
              textAlign: TextAlign.center,
              style: AppTypography.body14
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
