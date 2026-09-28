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
