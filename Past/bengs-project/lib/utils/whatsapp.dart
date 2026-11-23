import 'package:url_launcher/url_launcher.dart';

/// BR-11 — "settlement happens via WhatsApp after matching" is the whole
/// in-app-chat replacement for MVP, so this is load-bearing, not a nicety.
/// wa.me needs digits only, in international format with no leading '+'
/// or '0' — Indonesian numbers are typically entered locally as
/// "08123456789", so a bare local 0-prefixed number is assumed Indonesian
/// (country code 62) unless the user already typed a country code.
class WhatsAppLauncher {
  WhatsAppLauncher._();

  static String normalizePhoneNumber(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    }
    return digits;
  }

  static Future<bool> openChat(String phoneNumber, {String? message}) {
    final digits = normalizePhoneNumber(phoneNumber);
    final uri = Uri.https('wa.me', '/$digits', message == null ? null : {'text': message});
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
