import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<void> initialize() async {
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    _messaging.onTokenRefresh.listen(_saveToken);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Handle foreground messages if needed
    });
  }

  static Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _supabase.from('user_tokens').upsert({
      'user_id': user.uid,
      'fcm_token': token,
      'updated_at': DateTime.now().toIso8601String(),
    });
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
}