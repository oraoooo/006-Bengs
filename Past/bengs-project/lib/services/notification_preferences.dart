import 'package:shared_preferences/shared_preferences.dart';

/// Local-only toggle state for the Account screen's Push/Promotional
/// Notifications rows. There is no push infrastructure in this project
/// (no FCM/APNs setup, nothing server-side that would ever send a push) —
/// nothing currently reads these values to decide whether to send
/// anything. They exist so the toggle in the UI persists across app
/// restarts; wiring them to actual push delivery is separate, later work.
class NotificationPreferences {
  NotificationPreferences._();

  static const _pushKey = 'push_notifications_enabled';
  static const _promotionalKey = 'promotional_notifications_enabled';

  static Future<bool> getPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pushKey) ?? true;
  }

  static Future<void> setPushEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushKey, value);
  }

  static Future<bool> getPromotionalEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_promotionalKey) ?? false;
  }

  static Future<void> setPromotionalEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promotionalKey, value);
  }
}
