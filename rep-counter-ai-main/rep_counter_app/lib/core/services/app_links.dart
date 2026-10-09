import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../legal/legal_config.dart';

class AppLinks {
  static const appStoreId = String.fromEnvironment('APP_STORE_ID');
  static bool get hasAppStoreListing => RegExp(r'^\d+$').hasMatch(appStoreId);
  static Uri get email => Uri(
      scheme: 'mailto',
      path: LegalConfig.contactEmail,
      query: 'subject=${Uri.encodeComponent('RepCoach AI feedback')}');
  static Uri? reviewUrl({required bool ios}) => ios
      ? (hasAppStoreListing
          ? Uri.parse(
              'https://apps.apple.com/app/id$appStoreId?action=write-review')
          : null)
      : Uri.https('play.google.com', '/store/apps/details',
          {'id': 'com.ronganminh.repcoach'});
  static Future<bool> feedback() =>
      launchUrl(email, mode: LaunchMode.externalApplication);
  static Future<bool> review() async {
    final url = reviewUrl(ios: Platform.isIOS);
    return url != null &&
        await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
