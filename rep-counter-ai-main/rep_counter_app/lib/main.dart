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
import 'features/auth/data/auth_bootstrap.dart';
import 'features/auth/presentation/password_reset_pages.dart';
import 'features/credits/credits_controller.dart';
import 'features/legal/onboarding_page.dart';
import 'features/sync/sync_controller.dart';
import 'features/sync/sync_scope.dart';
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

  /// Accounts (A-1, D-12 Supabase) exist only behind `ENABLE_ACCOUNTS`.
  /// Without Supabase configuration sign-in reports "not available"; the app
  /// never waits for this before showing training.
  AuthController? _auth;

  /// Cloud sync (A-2) behind `ENABLE_CLOUD_SYNC`; needs accounts.
  SyncController? _sync;

  /// AI credits and the AI Coach (AI-1) behind `ENABLE_AI_CREDITS`.
  CreditsController? _credits;

  @override
  void initState() {
    super.initState();
    _load();
    if (FeatureFlags.enableAccounts && _ciVideoAsset.isEmpty) _initAuth();
  }

  Future<void> _initAuth() async {
    final repository = await createAuthRepository();
    if (repository == null || !mounted) return;
    final auth = AuthController(repository);
    final sync = createSyncController(auth)?..start();
    final credits = createCreditsController(auth);
    setState(() {
      _auth = auth;
      _sync = sync;
      _credits = credits;
    });
    await auth.restore();
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
    _sync?.dispose();
    _credits?.dispose();
    _auth?.dispose();
    super.dispose();
  }

  Widget _withSync(Widget child) {
    var out = child;
    if (_credits != null) {
      out = CreditsScope(controller: _credits!, child: out);
    }
    return _sync == null ? out : SyncScope(controller: _sync!, child: out);
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
                        : AuthScope(
                            controller: _auth!,
                            child: _withSync(const AuthRecoveryListener(
                                child: AppShell()))))
                    : OnboardingPage(
                        onDone: () => setState(() => _onboarded = true)),
          ),
        ),
      );
}
