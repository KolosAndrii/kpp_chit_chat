import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  // Getter для observer (потрібен для MaterialApp)
  static FirebaseAnalyticsObserver get observer => 
      FirebaseAnalyticsObserver(analytics: _analytics);

  // Логування перегляду екрану
  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenName,
    );
  }

  // Логування входу
  static Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  // Логування реєстрації
  static Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  // Логування зміни режиму авторизації (вхід/реєстрація)
  static Future<void> logAuthModeChange(bool isLogin) async {
    await _analytics.logEvent(
      name: 'auth_mode_changed',
      parameters: {
        'mode': isLogin ? 'login' : 'register',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Логування спроби входу/реєстрації
  static Future<void> logAuthAttempt(bool isLogin) async {
    await _analytics.logEvent(
      name: isLogin ? 'login_attempt' : 'register_attempt',
      parameters: {
        'method': 'email',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Логування вибору пункту меню
  static Future<void> logMenuItemSelected(int index, String menuName) async {
    await _analytics.logEvent(
      name: 'menu_item_selected',
      parameters: {
        'menu_index': index,
        'menu_name': menuName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Логування вибору чату
  static Future<void> logChatSelected(int chatId) async {
    await _analytics.logEvent(
      name: 'chat_selected',
      parameters: {
        'chat_id': chatId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Універсальний метод для кастомних подій
  static Future<void> logCustomEvent(
    String eventName, 
    Map<String, Object>? parameters,
  ) async {
    await _analytics.logEvent(
      name: eventName,
      parameters: parameters,
    );
  }
}