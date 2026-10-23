import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import 'locale_controller.dart';

/// gen-l10n strings for the current language (roadmap L-1).
///
/// Uses the `AppLocalizations` from the widget tree when present and falls
/// back to the same lookup for the [LocaleScope] language otherwise, so
/// migrated screens show exactly what `context.tr` showed in any subtree.
extension L10nContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(language.locale);
}
