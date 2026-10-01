import 'package:flutter/material.dart';
import '../core/i18n/app_strings.dart';
import '../core/i18n/locale_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

extension ProductCopy on BuildContext {
  String tr(String vi, String en) => language == AppLanguage.vi ? vi : en;
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text.toUpperCase(),
            style:
                AppTypography.caption12.copyWith(color: context.palette.text3)),
      );
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionLabel(title),
          Card(
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(indent: 52, endIndent: 16),
                  children[i],
                ],
              ])),
        ]),
      );
}

class SettingsRow extends StatelessWidget {
  const SettingsRow(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle,
      this.trailing,
      this.onTap,
      this.destructive = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(builder: (context, constraints) {
      final stacked = trailing != null &&
          (MediaQuery.textScalerOf(context).scale(14) > 20 ||
              constraints.maxWidth < 320);
      final end = trailing ??
          (onTap == null
              ? null
              : Icon(Icons.chevron_right, color: p.textDisabled));
      return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(children: [
              Icon(icon, size: 22, color: destructive ? p.danger : p.text2),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: TextStyle(
                            color: destructive ? p.dangerText : p.text,
                            fontWeight: FontWeight.w600)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!,
                          style: TextStyle(color: p.text3, fontSize: 13)),
                    ],
                    if (stacked) ...[const SizedBox(height: 8), end!],
                  ])),
              if (end != null && !stacked) ...[const SizedBox(width: 12), end],
            ]),
          ));
    });
  }
}


/// Shared single-choice pill from the vNext design system.
///
/// The widget only renders selection state; callers keep the group mutually
/// exclusive in application state.
class SegmentChip extends StatelessWidget {
  const SegmentChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? p.surface2 : p.surface2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? p.accent : Colors.transparent,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.body14.copyWith(
                color: selected ? p.accentInk : p.text2,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared Progress summary card. Values are supplied by local analytics only.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.caption12.copyWith(color: p.text3),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTypography.metric40.copyWith(
              color: p.accentInk,
              fontSize: 30,
            ),
          ),
        ],
      ),
    );
  }
}
