import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Push notifications authorized');
    }

    // Get token
    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message: ${message.notification?.title}');
    });

    // Background / terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Message opened app: ${message.data}');
    });
  }

  static Future<String?> getToken() => _messaging.getToken();
}
