/// Giữ ngôn ngữ đang chọn, lưu lại giữa các lần mở app, và phát cho cây widget.
///
/// Dùng `ValueNotifier` + `InheritedNotifier` thay vì thêm package quản lý trạng
/// thái: IMPLEMENTATION_PLAN §18 yêu cầu không thêm package khi SDK đã đủ.
library;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

class LocaleController extends ValueNotifier<AppLanguage> {
  LocaleController([super.initial = AppLanguage.vi]);

  static const _key = 'app_language';

  /// Đọc ngôn ngữ đã lưu. Chưa từng chọn -> theo ngôn ngữ hệ thống nếu là tiếng
  /// Anh, còn lại mặc định tiếng Việt.
  Future<void> load(String systemLocale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      value = saved != null
          ? AppLanguage.fromCode(saved)
          : (systemLocale.startsWith('en') ? AppLanguage.en : AppLanguage.vi);
    } catch (_) {
      // Không đọc được thì vẫn chạy với mặc định — ngôn ngữ không đáng để làm
      // app không mở lên được.
      value = AppLanguage.vi;
    }
  }

  Future<void> set(AppLanguage lang) async {
    if (lang == value) return;
    value = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, lang.code);
    } catch (_) {
      // Đổi được trong phiên này là đủ; lần sau mở lại sẽ về mặc định.
    }
  }
}

/// Cho phép mọi widget lấy chuỗi bằng `context.s`.
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController controllerOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'Thiếu LocaleScope phía trên widget này');
    return scope!.notifier!;
  }
}

extension LocaleContext on BuildContext {
  /// Chuỗi theo ngôn ngữ hiện tại.
  S get s => S.of(LocaleScope.controllerOf(this).value);

  AppLanguage get language => LocaleScope.controllerOf(this).value;

  Future<void> setLanguage(AppLanguage lang) =>
      LocaleScope.controllerOf(this).set(lang);
}
