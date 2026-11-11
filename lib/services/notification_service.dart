import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<void> init() async {
    await initialize();
  }

  static Future<void> initialize() async {
    try {
      debugPrint('NotificationService: Requesting permission...');
      final settings = await _messaging.requestPermission();
      debugPrint('NotificationService: Permission status: ${settings.authorizationStatus}');

      final token = await _messaging.getToken();
      debugPrint('NotificationService: FCM Token: $token');

      if (token != null) {
        await _saveToken(token);
      } else {
        debugPrint('NotificationService: Token is null');
      }

      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('NotificationService: Token refreshed');
        _saveToken(newToken);
      });
    } catch (e) {
      debugPrint('NotificationService initialize error: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('NotificationService: No user logged in, cannot save token');
        return;
      }

      debugPrint('NotificationService: Saving token for user ${user.uid}');

      await _supabase.from('user_tokens').upsert({
        'user_id': user.uid,
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('NotificationService: Token saved successfully');
    } catch (e) {
      debugPrint('NotificationService: Failed to save token: $e');
    }
  }

  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final response = await _supabase
          .from('user_tokens')
          .select('fcm_token')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null || response['fcm_token'] == null) {
        debugPrint('No FCM token found for user $userId');
        return;
      }

      final token = response['fcm_token'] as String;

      final result = await _supabase.functions.invoke('send-notification', body: {
        'title': title,
        'body': body,
        'tokens': [token],
        'data': data ?? {},
      });

      debugPrint('Notification sent, response: ${result.data}');
    } catch (e) {
      debugPrint('Failed to send notification: $e');
    }
  }

  static Future<void> sendFriendRequestNotification(String toUserId, String fromUsername) async {
    await sendNotificationToUser(
      userId: toUserId,
      title: 'Ny vänförfrågan',
      body: '$fromUsername vill bli din vän',
      data: {'type': 'friend_request'},
    );
  }

  static Future<void> sendMessageNotification(String toUserId, String fromUsername, String message) async {
    await sendNotificationToUser(
      userId: toUserId,
      title: 'Nytt meddelande från $fromUsername',
      body: message.length > 50 ? '${message.substring(0, 50)}...' : message,
      data: {'type': 'message'},
    );
  }

  static Future<void> scheduleSessionReminders({
    required String sessionId,
    required String sessionName,
    required DateTime startTime,
  }) async {
    debugPrint('scheduleSessionReminders called for $sessionName');
  }

  static Future<void> notifyRebuy({
    required String sessionId,
    required String playerName,
    required double amount,
  }) async {
    debugPrint('notifyRebuy called');
  }

  static Future<void> notifySessionEnded({
    required String sessionId,
    required String sessionName,
  }) async {
    debugPrint('notifySessionEnded called');
  }
}