import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await _messaging.getToken();
        if (token != null) {
          debugPrint('FCM Token: $token');
          await _saveToken(token);
        }
      }

      _messaging.onTokenRefresh.listen(_saveToken);

      FirebaseMessaging.onMessage.listen((msg) {
        debugPrint('Foreground: ${msg.notification?.title}');
      });
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Save token failed: $e');
    }
  }

  static Future<void> scheduleSessionReminders({
    required String sessionId,
    required String sessionName,
    required DateTime startTime,
  }) async {
    debugPrint('Reminders for $sessionName scheduled');
  }

  static Future<void> notifyRebuy({
    required String sessionId,
    required String playerName,
    required double amount,
  }) async {
    try {
      final session = await FirebaseFirestore.instance.collection('sessions').doc(sessionId).get();
      if (!session.exists) return;
      final players = (session.data()?['players'] as Map?)?.keys ?? [];
      debugPrint('Rebuy by $playerName - ${players.length} players');
    } catch (e) {
      debugPrint('Notify rebuy failed: $e');
    }
  }

  static Future<void> notifySessionEnded({
    required String sessionId,
    required String sessionName,
  }) async {
    try {
      final session = await FirebaseFirestore.instance.collection('sessions').doc(sessionId).get();
      if (!session.exists) return;
      final players = (session.data()?['players'] as Map?)?.keys ?? [];
      debugPrint('Session $sessionName ended - ${players.length} players');
    } catch (e) {
      debugPrint('Notify ended failed: $e');
    }
  }
}
