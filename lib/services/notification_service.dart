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
      final settings = await _messaging.requestPermission();
      debugPrint('NotificationService: Permission: ${settings.authorizationStatus}');

      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      }

      _messaging.onTokenRefresh.listen(_saveToken);
    } catch (e) {
      debugPrint('NotificationService initialize error: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _supabase.from('user_tokens').upsert({
        'user_id': user.uid,
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to save token: $e');
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

      if (response == null || response['fcm_token'] == null) return;

      final token = response['fcm_token'] as String;

      await _supabase.functions.invoke('send-notification', body: {
        'title': title,
        'body': body,
        'tokens': [token],
        'data': data ?? {},
      });
    } catch (e) {
      debugPrint('Failed to send notification: $e');
    }
  }

  static Future<void> sendNotificationToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    for (final uid in userIds) {
      await sendNotificationToUser(userId: uid, title: title, body: body, data: data);
    }
  }

  // Friend request
  static Future<void> sendFriendRequestNotification(String toUserId, String fromUsername) async {
    await sendNotificationToUser(
      userId: toUserId,
      title: 'Ny vänförfrågan',
      body: '$fromUsername vill bli din vän',
      data: {'type': 'friend_request'},
    );
  }

  // Friend accepted
  static Future<void> sendFriendAcceptedNotification(String toUserId, String fromUsername) async {
    await sendNotificationToUser(
      userId: toUserId,
      title: 'Ny vän!',
      body: '$fromUsername accepterade din vänförfrågan',
      data: {'type': 'friend_accepted'},
    );
  }

  // Session invite
  static Future<void> sendSessionInviteNotification(String toUserId, String sessionName, String fromUsername) async {
    await sendNotificationToUser(
      userId: toUserId,
      title: 'Inbjuden till session',
      body: '$fromUsername bjöd in dig till "$sessionName"',
      data: {'type': 'session_invite'},
    );
  }

  // Rebuy notification to all participants
  static Future<void> notifyRebuy({
    required String sessionId,
    required String playerName,
    required double amount,
    required List<String> participantIds,
  }) async {
    final amountStr = amount.toStringAsFixed(0);
    await sendNotificationToUsers(
      userIds: participantIds,
      title: 'Ny rebuy 💰',
      body: '$playerName köpte in sig för $amountStr kr',
      data: {'type': 'rebuy', 'sessionId': sessionId},
    );
  }

  // Message (already exists)
  static Future<void> sendMessageNotification(String toUserId, String fromUsername, String message) async {
    await sendNotificationToUser(
      userId: toUserId,
      title: 'Nytt meddelande från $fromUsername',
      body: message.length > 50 ? '${message.substring(0, 50)}...' : message,
      data: {'type': 'message'},
    );
  }
}