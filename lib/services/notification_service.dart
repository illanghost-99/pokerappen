import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;
  static final _supabase = Supabase.instance.client;

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

      // Save to Firestore (existing)
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also save to Supabase
      await _supabase.from('user_tokens').upsert({
        'user_id': uid,
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Save token failed: $e');
    }
  }

  static Future<void> _sendNotification({
    required String title,
    required String body,
    required List<String> tokens,
    Map<String, dynamic>? data,
  }) async {
    if (tokens.isEmpty) return;

    try {
      final response = await _supabase.functions.invoke(
        'send-notification',
        body: {
          'title': title,
          'body': body,
          'tokens': tokens,
          'data': data ?? {},
        },
      );

      debugPrint('Notification sent: ${response.data}');
    } catch (e) {
      debugPrint('Send notification failed: $e');
    }
  }

  static Future<List<String>> _getTokensForUsers(List<String> userIds) async {
    try {
      final response = await _supabase
          .from('user_tokens')
          .select('fcm_token')
          .inFilter('user_id', userIds);

      return (response as List).map((e) => e['fcm_token'] as String).where((t) => t.isNotEmpty).toList();
    } catch (e) {
      debugPrint('Get tokens failed: $e');
      return [];
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

      final players = (session.data()?['players'] as Map?)?.keys.cast<String>().toList() ?? [];
      final tokens = await _getTokensForUsers(players);

      await _sendNotification(
        title: 'Ny rebuy',
        body: '$playerName lade till $amount',
        tokens: tokens,
        data: {'type': 'rebuy', 'sessionId': sessionId},
      );
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

      final players = (session.data()?['players'] as Map?)?.keys.cast<String>().toList() ?? [];
      final tokens = await _getTokensForUsers(players);

      await _sendNotification(
        title: 'Session avslutad',
        body: '$sessionName är avslutad',
        tokens: tokens,
        data: {'type': 'session_ended', 'sessionId': sessionId},
      );
    } catch (e) {
      debugPrint('Notify ended failed: $e');
    }
  }

  static Future<void> notifyNewSession({
    required String sessionId,
    required String sessionName,
    required List<String> invitedUserIds,
  }) async {
    try {
      final tokens = await _getTokensForUsers(invitedUserIds);

      await _sendNotification(
        title: 'Ny pokersession',
        body: 'Du är inbjuden till $sessionName',
        tokens: tokens,
        data: {'type': 'new_session', 'sessionId': sessionId},
      );
    } catch (e) {
      debugPrint('Notify new session failed: $e');
    }
  }
}
