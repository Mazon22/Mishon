import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  static Future<void> setupFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Push notifications authorized');

      final token = await messaging.getToken();
      debugPrint('FCM Token: $token');

      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
      });

      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('Foreground message: ${message.notification?.title}');
      });
    } else {
      debugPrint('Push notifications not authorized');
    }
  }

  static Future<void> _backgroundMessageHandler(RemoteMessage message) async {
    debugPrint('Background message: ${message.messageId}');
    debugPrint('Message data: ${message.data}');
  }

  static Future<void> sendTokenToServer(String token, int userId) async {
    debugPrint('Sending FCM token to server for user $userId');
  }
}
