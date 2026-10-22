import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Typed confirmation for destructive actions (COMPONENT_REGISTRY #9).
///
/// Accepted words are `DELETE` and `XÓA` in either language, case-insensitive
/// (PRODUCT_DECISIONS D-23; interim decision L-D09). The prompt shows the word
/// for the current language. [onChanged] reports whether the input matches;
/// callers keep the destructive button disabled until it does.
class TypeToConfirmField extends StatefulWidget {
  const TypeToConfirmField({
    super.key,
    required this.onChanged,
    this.enabled = true,
  });

  static const acceptedWords = {'DELETE', 'XÓA'};

  /// Word shown in the prompt for [languageCode].
  static String wordFor(String languageCode) =>
      languageCode == 'vi' ? 'XÓA' : 'DELETE';

  /// Whether [input] confirms. Also accepts the decomposed "XOÁ"/"XÓA"
  /// spellings Vietnamese keyboards may produce.
  static bool matches(String input) {
    final normalized = input
        .trim()
        .toUpperCase()
        .replaceAll('ÓA', 'ÓA')
        .replaceAll('OÁ', 'ÓA')
        .replaceAll('OÁ', 'ÓA');
    return acceptedWords.contains(normalized);
  }

  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  State<TypeToConfirmField> createState() => _TypeToConfirmFieldState();
}

class _TypeToConfirmFieldState extends State<TypeToConfirmField> {
  final _controller = TextEditingController();
  bool _matched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    final matched = TypeToConfirmField.matches(value);
    if (matched == _matched) return;
    setState(() => _matched = matched);
    widget.onChanged(matched);
  }

  @override
  Widget build(BuildContext context) {
    final word = TypeToConfirmField.wordFor(
        Localizations.localeOf(context).languageCode);
    final prompt =
        AppLocalizations.of(context).historyDeleteTypeToConfirm(word);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.r14),
          borderSide: BorderSide(color: c, width: 1.5),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt,
            style: AppTypography.body14.copyWith(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          onChanged: _changed,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          style: AppTypography.body16.copyWith(color: AppColors.text),
          decoration: InputDecoration(
            hintText: word,
            semanticCounterText: '',
            filled: true,
            fillColor: AppColors.surface,
            constraints: const BoxConstraints(minHeight: 52),
            enabledBorder: border(AppColors.borderStrong),
            focusedBorder:
                border(_matched ? AppColors.success : AppColors.accent),
            disabledBorder: border(AppColors.border),
          ),
        ),
      ],
    );
  }
}
