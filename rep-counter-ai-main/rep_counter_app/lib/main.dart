import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/feature_flags.dart';
import 'core/i18n/app_strings.dart';
import 'core/i18n/locale_controller.dart';
import 'core/legal/legal_config.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'app/app_shell.dart';
import 'app/route_observer.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/application/auth_scope.dart';
import 'features/auth/domain/auth_repository.dart';
import 'features/legal/onboarding_page.dart';
import 'camera_page.dart';
import 'exercise.dart';

const _ciVideoAsset = String.fromEnvironment('REPCOACH_CI_VIDEO_ASSET');

void main() => runApp(const RepCounterApp());

class RepCounterApp extends StatefulWidget {
  const RepCounterApp({super.key});
  @override
  State<RepCounterApp> createState() => _RepCounterAppState();
}

class _RepCounterAppState extends State<RepCounterApp> {
  bool? _onboarded;
  // English until the saved choice loads, so a fresh install never flashes
  // Vietnamese (decision log L-D15).
  final _locale = LocaleController(AppLanguage.en);

  /// Accounts (A-1) exist only behind `ENABLE_ACCOUNTS`; no backend is
  /// configured yet, so even then sign-in reports "not available".
  final _auth = FeatureFlags.enableAccounts
      ? (AuthController(const UnconfiguredAuthRepository())..restore())
      : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Cài mới mặc định tiếng Anh; lựa chọn đã lưu luôn được tôn trọng (xem
    // LocaleController.load).
    await _locale
        .load(WidgetsBinding.instance.platformDispatcher.locale.languageCode);
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _onboarded = prefs.getBool('onboarding_v1') ?? false);
    }
  }

  @override
  void dispose() {
    _locale.dispose();
    _auth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LocaleScope(
        controller: _locale,
        child: ValueListenableBuilder<AppLanguage>(
          valueListenable: _locale,
          builder: (context, language, __) => MaterialApp(
            title: LegalConfig.appName,
            // The persisted LocaleController stays the single source of the
            // language; gen-l10n and Material/Cupertino strings follow it.
            locale: language.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            debugShowCheckedModeBanner: false,
            theme: RepCoachTheme.light(),
            darkTheme: RepCoachTheme.dark(),
            themeMode: ThemeMode.dark,
            navigatorObservers: [appRouteObserver],
            home: _ciVideoAsset.isNotEmpty
                ? CameraPage(
                    profile: pushUp,
                    ciVideoPath:
                        '${Directory.systemTemp.path}/$_ciVideoAsset',
                  )
                : _onboarded == null
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()))
                : _onboarded!
                    ? (_auth == null
                        ? const AppShell()
                        : AuthScope(controller: _auth, child: const AppShell()))
                    : OnboardingPage(
                        onDone: () => setState(() => _onboarded = true)),
          ),
        ),
      );
}
