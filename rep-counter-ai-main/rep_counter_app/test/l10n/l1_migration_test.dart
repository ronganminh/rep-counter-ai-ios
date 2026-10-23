import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/l10n.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';

/// L-1 progress guard: files already migrated to ARB keys must not regain
/// inline `context.tr('vi', 'en')` strings, except the listed dynamic ones
/// (interpolated values or line breaks) that need parameterised keys first.
const _migrated = {
  'lib/features/legal/settings_page.dart': 4,
  'lib/features/legal/onboarding_page.dart': 3,
  'lib/features/legal/voice_cadence_page.dart': 0,
  'lib/features/legal/legal_page.dart': 0,
  'lib/features/history/export/export_data_sheet.dart': 1,
  'lib/features/home/presentation/home_screen.dart': 2,
  'lib/features/workout/presentation/history_page.dart': 11,
  'lib/features/routine/presentation/routine_editor_page.dart': 0,
  'lib/features/routine/presentation/routine_list_page.dart': 0,
  'lib/features/routine/presentation/rest_overlay.dart': 3,
  'lib/features/achievements/presentation/achievement_earned_card.dart': 1,
  'lib/features/share/story_page.dart': 0,
  'lib/features/exercises/presentation/exercise_picker_screen.dart': 0,
  'lib/features/workout/presentation/goal_setup_page.dart': 7,
  'lib/features/ai/presentation/ai_consent.dart': 4,
};

void main() {
  for (final entry in _migrated.entries) {
    test('no new inline strings in ${entry.key}', () {
      final count = RegExp(r'context\.tr\(')
          .allMatches(File(entry.key).readAsStringSync())
          .length;
      expect(count, lessThanOrEqualTo(entry.value));
    });
  }

  for (final language in AppLanguage.values) {
    testWidgets('context.l10n follows LocaleScope · ${language.code}',
        (tester) async {
      final locale = LocaleController(language);
      addTearDown(locale.dispose);
      late String label;
      // No AppLocalizations delegate here: the fallback must still resolve
      // the same language as context.tr.
      await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(home: Builder(builder: (context) {
          label = context.l10n.navProgress;
          return const SizedBox();
        })),
      ));
      expect(label, language == AppLanguage.vi ? 'Tiến bộ' : 'Progress');
    });
  }
}
