/// App Store Guideline 5.1.1(iv): Photos permission on Results → Share → Save.
///
/// After "Don't Allow" the app only says "Image not saved." (no Settings, no
/// retry, no second prompt). A later Save with access off shows the neutral
/// Back / Open Settings notice, as for the camera (L-D38).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/widgets/permission_off_notice.dart';
import 'package:rep_counter_app/features/share/story_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'phase7_test.dart' show record;
import 'support/l10n.dart';

class FakePhotos extends PhotoLibrary {
  FakePhotos({this.access = false, this.grant = false});
  bool access;
  bool grant;
  int requests = 0, puts = 0;
  @override
  Future<bool> hasAccess() async => access;
  @override
  Future<bool> requestAccess() async {
    requests++;
    if (grant) access = true;
    return grant;
  }

  @override
  Future<void> put(Uint8List bytes) async => puts++;
}

class SpyExporter extends StoryExporter {
  SpyExporter(FakePhotos photos) : super(photos: photos);
  int shares = 0;
  @override
  Future<ShareResultStatus> share(Uint8List bytes, Rect origin) async {
    shares++;
    return ShareResultStatus.dismissed;
  }
}

const _banned = [
  'Settings',
  'Cài đặt',
  'Allow',
  'Cho phép',
  'cho phép',
  'retry',
  'thử lại',
  'denied',
  'từ chối',
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, StoryExporter exporter,
      {AppLanguage language = AppLanguage.vi}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = LocaleController(language);
    addTearDown(locale.dispose);
    await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(
            theme: RepCoachTheme.dark(),
            locale: language.locale,
            supportedLocales: testSupportedLocales,
            localizationsDelegates: testLocalizationsDelegates,
            home: StoryPage(record: record(), exporter: exporter))));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  String snackText(WidgetTester tester) => tester
      .widget<Text>(find.descendant(
          of: find.byType(SnackBar), matching: find.byType(Text)))
      .data!;

  for (final (lang, notSaved) in [
    (AppLanguage.vi, 'Chưa lưu ảnh.'),
    (AppLanguage.en, 'Image not saved.'),
  ]) {
    testWidgets('Don\'t Allow: only "$notSaved", no Settings, no retry',
        (tester) async {
      final photos = FakePhotos();
      await pump(tester, SpyExporter(photos), language: lang);
      await tap(tester, 'save-story');
      expect(photos.requests, 1);
      expect(photos.puts, 0);
      final text = snackText(tester);
      expect(text, notSaved);
      for (final word in _banned) {
        expect(text.contains(word), isFalse, reason: word);
      }
      expect(find.byType(PermissionOffNotice), findsNothing);
      expect(find.byType(SnackBarAction), findsNothing);
    });
  }

  testWidgets('denied: Share through the share sheet still works',
      (tester) async {
    final photos = FakePhotos();
    final exporter = SpyExporter(photos);
    await pump(tester, exporter);
    await tap(tester, 'save-story');
    await tap(tester, 'share-story');
    expect(exporter.shares, 1);
    expect(photos.requests, 1);
  });

  for (final (lang, message, back, settings) in [
    (
      AppLanguage.vi,
      'Quyền thêm ảnh của RepCoach đang tắt. Lưu ảnh cần quyền này.',
      'Quay lại',
      'Mở Cài đặt'
    ),
    (
      AppLanguage.en,
      'Photos access is off for RepCoach. Saving the image needs it.',
      'Back',
      'Open Settings'
    ),
  ]) {
    testWidgets('next Save with access off: neutral notice ($lang), no prompt',
        (tester) async {
      final photos = FakePhotos();
      await pump(tester, SpyExporter(photos), language: lang);
      await tap(tester, 'save-story'); // "Don't Allow"
      ScaffoldMessenger.of(tester.element(find.byType(StoryPage)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();

      await tap(tester, 'save-story');
      expect(photos.requests, 1, reason: 'the system prompt is never repeated');
      expect(find.byType(PermissionOffNotice), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.text(back), findsOneWidget);
      expect(find.text(settings), findsOneWidget);
      // Two equal, same-style buttons: Settings is not promoted.
      final b = tester.getSize(find.byKey(const Key('photos-off-back')));
      final s = tester.getSize(find.byKey(const Key('photos-off-settings')));
      expect(b, s);
      expect(tester.widget(find.byKey(const Key('photos-off-settings'))),
          isA<OutlinedButton>());
      expect(tester.widget(find.byKey(const Key('photos-off-back'))),
          isA<OutlinedButton>());
      for (final word in ['denied', 'từ chối', 'retry', 'thử lại', 'Allow']) {
        expect(message.contains(word), isFalse, reason: word);
      }

      await tester.tap(find.byKey(const Key('photos-off-back')));
      await tester.pumpAndSettle();
      expect(find.byType(PermissionOffNotice), findsNothing);
      expect(find.byType(StoryPage), findsOneWidget);
      expect(photos.puts, 0);
    });
  }

  testWidgets('Allow: saves and confirms', (tester) async {
    final photos = FakePhotos(grant: true);
    await pump(tester, SpyExporter(photos));
    await tap(tester, 'save-story');
    expect(photos.requests, 1);
    expect(photos.puts, 1);
    expect(snackText(tester), 'Đã lưu ảnh vào thư viện.');
  });

  testWidgets('access enabled later in Settings: Save works, no prompt',
      (tester) async {
    SharedPreferences.setMockInitialValues({StoryExporter.askedKey: true});
    final photos = FakePhotos(access: true);
    await pump(tester, SpyExporter(photos));
    await tap(tester, 'save-story');
    expect(photos.requests, 0);
    expect(photos.puts, 1);
    expect(find.byType(PermissionOffNotice), findsNothing);
  });

  test('exporter: first refusal declines, later Save is accessOff', () async {
    final photos = FakePhotos();
    final exporter = StoryExporter(photos: photos);
    final bytes = Uint8List(4);
    expect(await exporter.save(bytes), PhotoSaveResult.declined);
    expect(await exporter.save(bytes), PhotoSaveResult.accessOff);
    expect(photos.requests, 1);
  });
}
