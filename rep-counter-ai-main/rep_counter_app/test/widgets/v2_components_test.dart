import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rep_counter_app/l10n/app_localizations.dart';
import 'package:rep_counter_app/theme/app_colors.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:rep_counter_app/widgets/app_button.dart';
import 'package:rep_counter_app/widgets/app_feedback.dart';
import 'package:rep_counter_app/widgets/metric_widgets.dart';
import 'package:rep_counter_app/widgets/product_ui.dart';
import 'package:rep_counter_app/widgets/status_badges.dart';
import 'package:rep_counter_app/widgets/tap_target.dart';
import 'package:rep_counter_app/widgets/type_to_confirm_field.dart';

/// Every DS-2 component on one scrollable page. Strings that the components
/// take as parameters are neutral test copy, not product sample data.
class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppButton(label: 'Primary action', onPressed: () {}),
              const SizedBox(height: 8),
              AppButton(
                  label: 'Secondary',
                  onPressed: () {},
                  variant: AppButtonVariant.secondary),
              const SizedBox(height: 8),
              const AppButton(label: 'Disabled', onPressed: null),
              const SizedBox(height: 8),
              AppButton(
                  label: 'Danger',
                  onPressed: () {},
                  variant: AppButtonVariant.danger,
                  icon: LucideIcons.trash2),
              const SizedBox(height: 12),
              const AppBanner(
                  title: 'Banner title',
                  body: 'Banner body text',
                  tone: AppBannerTone.warn),
              const SizedBox(height: 12),
              const Wrap(spacing: 8, runSpacing: 8, children: [
                SyncStatusBadge(state: SyncBadgeState.guestOnly),
                SyncStatusBadge(state: SyncBadgeState.pending, count: 2),
                SyncStatusBadge(state: SyncBadgeState.synced),
                PrivacyBadge(),
              ]),
              const SizedBox(height: 12),
              const Row(children: [
                Expanded(child: StatTile(label: 'Workouts', value: '12')),
                SizedBox(width: 12),
                Expanded(child: StatTile(label: 'Loading', value: null)),
              ]),
              const SizedBox(height: 12),
              const ChallengeMeter(
                  title: 'Monthly goal',
                  value: 40,
                  target: 100,
                  valueLabel: '40 / 100',
                  pace: 'Pace text'),
              const SizedBox(height: 12),
              TypeToConfirmField(onChanged: (_) {}),
              const SizedBox(height: 24),
              const StatusHero(
                  icon: LucideIcons.dumbbell,
                  title: 'Status title',
                  body: 'Status body text'),
            ],
          ),
        ),
      );
}

Future<void> _loadFonts() async {
  for (final font in {
    'Inter': ['assets/fonts/Inter.ttf'],
    'Barlow Condensed': [
      'assets/fonts/BarlowCondensed-SemiBold.ttf',
      'assets/fonts/BarlowCondensed-Bold.ttf',
      'assets/fonts/BarlowCondensed-ExtraBold.ttf',
    ],
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
    'packages/lucide_icons_flutter/Lucide': [
      'packages/lucide_icons_flutter/assets/lucide.ttf'
    ],
  }.entries) {
    final loader = FontLoader(font.key);
    for (final asset in font.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

Future<void> _pump(WidgetTester tester, Widget child,
    {Locale locale = const Locale('en'),
    Size size = const Size(393, 852),
    double scale = 1,
    bool settle = true}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: RepCoachTheme.dark(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: child,
  ));
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

void main() {
  setUpAll(_loadFonts);

  for (final locale in const [Locale('en'), Locale('vi')]) {
    for (final size in const [Size(393, 852), Size(375, 667)]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        testWidgets(
            'gallery has no overflow · ${locale.languageCode} '
            '${size.width.toInt()}x${size.height.toInt()} @$scale',
            (tester) async {
          await _pump(tester, const _Gallery(),
              locale: locale, size: size, scale: scale);
          expect(tester.takeException(), isNull);
          // Scroll to the end so every component is laid out.
          await tester.drag(find.byType(ListView), const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
    testWidgets('golden · ${locale.languageCode} 393x852', (tester) async {
      await _pump(tester, const _Gallery(), locale: locale);
      await expectLater(
          find.byType(_Gallery),
          matchesGoldenFile(
              'goldens/v2_components_${locale.languageCode}.png'));
    });
  }

  testWidgets('localized labels follow the glossary', (tester) async {
    await _pump(tester, const _Gallery(), locale: const Locale('vi'));
    expect(find.text('Chỉ trên máy này'), findsOneWidget);
    expect(find.text('2 chờ đồng bộ'), findsOneWidget);
    expect(find.text('Trên máy'), findsOneWidget);
    expect(find.text('Nhập XÓA để xác nhận'), findsOneWidget);
  });

  testWidgets('small controls meet the 48 dp tap-target guideline',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
        tester,
        Scaffold(
          body: Center(
            child: Wrap(spacing: 8, children: [
              SegmentChip(label: '7D', selected: true, onTap: () {}),
              SegmentChip(label: '30D', selected: false, onTap: () {}),
              AppButton(
                  label: 'Ghost',
                  onPressed: () {},
                  variant: AppButtonVariant.ghost,
                  expand: false),
            ]),
          ),
        ));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    expect(tester.getSize(find.byType(TapTarget).first).height,
        greaterThanOrEqualTo(48));
    handle.dispose();
  });

  testWidgets('TapTarget margin receives taps', (tester) async {
    var taps = 0;
    await _pump(
        tester,
        Scaffold(
          body: Center(
            child: TapTarget(
                onTap: () => taps++,
                child: const SizedBox(width: 20, height: 20)),
          ),
        ));
    final box = tester.getRect(find.byType(TapTarget));
    await tester.tapAt(box.topLeft + const Offset(2, 2));
    expect(taps, 1);
  });

  testWidgets('AppButton: disabled and loading never fire', (tester) async {
    var taps = 0;
    await _pump(
        tester,
        Scaffold(
          body: Column(children: [
            const AppButton(label: 'Off', onPressed: null),
            AppButton(label: 'Busy', onPressed: () => taps++, loading: true),
            AppButton(label: 'On', onPressed: () => taps++),
          ]),
        ),
        settle: false);
    await tester.tap(find.text('Off'));
    await tester.tap(find.text('Busy'), warnIfMissed: false);
    await tester.tap(find.text('On'));
    expect(taps, 1);
    expect(tester.getSemantics(find.text('Off')),
        matchesSemantics(label: 'Off', isButton: true, hasEnabledState: true));
  });

  testWidgets('AppToast shows a message with a labelled close button',
      (tester) async {
    await _pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
                onPressed: () => AppToast.show(context, 'Saved'),
                child: const Text('go')),
          ),
        ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });

  test('TypeToConfirmField accepts DELETE and XÓA only', () {
    for (final ok in [
      'DELETE',
      'delete',
      ' Delete ',
      'XÓA',
      'xóa',
      'XOÁ',
      'xóa'
    ]) {
      expect(TypeToConfirmField.matches(ok), isTrue, reason: ok);
    }
    for (final bad in ['', 'DEL', 'XOA', 'DELETE!', 'XÓA XÓA']) {
      expect(TypeToConfirmField.matches(bad), isFalse, reason: bad);
    }
  });

  testWidgets('TypeToConfirmField reports matches once per change',
      (tester) async {
    final reports = <bool>[];
    await _pump(
        tester, Scaffold(body: TypeToConfirmField(onChanged: reports.add)));
    await tester.enterText(find.byType(TextField), 'DEL');
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.enterText(find.byType(TextField), 'DELET');
    expect(reports, [true, false]);
  });

  test('ChallengeMeter clamps its fill', () {
    const over = ChallengeMeter(
        title: 't', value: 700, target: 500, valueLabel: '700 / 500');
    const under = ChallengeMeter(
        title: 't', value: -3, target: 500, valueLabel: '0 / 500');
    expect(over.fraction, 1);
    expect(under.fraction, 0);
  });

  testWidgets('AppBanner and status badges are live regions', (tester) async {
    await _pump(
        tester,
        const Scaffold(
          body: Column(children: [
            AppBanner(title: 'Status'),
            SyncStatusBadge(state: SyncBadgeState.failed),
          ]),
        ));
    final banner = tester.getSemantics(find.byType(AppBanner));
    expect(banner.flagsCollection.isLiveRegion, isTrue);
    expect(find.text('Couldn’t sync'), findsOneWidget);
    expect(AppColors.dangerText, isNotNull);
  });
}
