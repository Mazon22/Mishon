import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  static Future<void> setupFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    // Запрос разрешения
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Push notifications authorized');

      // Получение токена
      final token = await messaging.getToken();
      print('FCM Token: $token');

      // Обработка изменений токена
      messaging.onTokenRefresh.listen((newToken) {
        print('FCM Token refreshed: $newToken');
        // TODO: Отправить новый токен на сервер
      });

      // Обработка сообщений в фоне
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

      // Обработка сообщений когда приложение в foreground
      FirebaseMessaging.onMessage.listen((message) {
        print('Foreground message: ${message.notification?.title}');
        // TODO: Показать notification
      });
    } else {
      print('Push notifications not authorized');
    }
  }

  static Future<void> _backgroundMessageHandler(RemoteMessage message) async {
    print('Background message: ${message.messageId}');
    print('Message data: ${message.data}');
  }

  // Метод для отправки токена на сервер
  static Future<void> sendTokenToServer(String token, int userId) async {
    // TODO: Реализовать отправку токена на backend
    print('Sending FCM token to server for user $userId');
  }
}
