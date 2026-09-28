import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/i18n/app_strings.dart';
import 'core/i18n/locale_controller.dart';
import 'core/legal/legal_config.dart';
import 'theme/app_theme.dart';
import 'app/app_shell.dart';
import 'app/route_observer.dart';
import 'features/legal/onboarding_page.dart';

void main() => runApp(const RepCounterApp());

class RepCounterApp extends StatefulWidget {
  const RepCounterApp({super.key});
  @override
  State<RepCounterApp> createState() => _RepCounterAppState();
}

class _RepCounterAppState extends State<RepCounterApp> {
  bool? _onboarded;
  final _locale = LocaleController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Ngôn ngữ hệ thống chỉ dùng làm mặc định LẦN ĐẦU; sau đó tôn trọng lựa
    // chọn đã lưu của người dùng.
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LocaleScope(
        controller: _locale,
        child: ValueListenableBuilder<AppLanguage>(
          valueListenable: _locale,
          builder: (context, _, __) => MaterialApp(
            title: LegalConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: RepCoachTheme.light(),
            darkTheme: RepCoachTheme.dark(),
            themeMode: ThemeMode.dark,
            navigatorObservers: [appRouteObserver],
            home: _onboarded == null
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()))
                : _onboarded!
                    ? const AppShell()
                    : OnboardingPage(
                        onDone: () => setState(() => _onboarded = true)),
          ),
        ),
      );
}
