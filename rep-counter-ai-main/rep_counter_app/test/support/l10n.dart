import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:rep_counter_app/l10n/app_localizations.dart';

/// Same delegates as `RepCounterApp`, for tests that pump a bare MaterialApp
/// around screens using `AppLocalizations`.
const testLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const testSupportedLocales = AppLocalizations.supportedLocales;
