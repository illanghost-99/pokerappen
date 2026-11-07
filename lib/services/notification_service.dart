import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _local.initialize(const InitializationSettings(android: android, iOS: ios));

    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Push authorized');
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    _messaging.onTokenRefresh.listen(_saveToken);

    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('Foreground: ${msg.notification?.title}');
    });
  }

  static Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> scheduleSessionReminders({
    required String sessionId,
    required String sessionName,
    required DateTime startTime,
  }) async {
    final now = DateTime.now();

    final reminders = [
      {'offset': const Duration(days: 2), 'title': '2 dagar kvar', 'body': '2 dagar kvar tills $sessionName!'},
      {'offset': const Duration(days: 1), 'title': '1 dag kvar', 'body': 'Imorgon spelar du $sessionName. Glöm inte att träna på din poker face.'},
      {'offset': const Duration(hours: 5), 'title': '5 timmar kvar', 'body': '5 timmar kvar till $sessionName. KÖR HÅRT!'},
      {'offset': Duration.zero, 'title': 'KÖR HÅRT!', 'body': '$sessionName startar nu. Glöm inte att träna på din poker face.'},
    ];

    for (final r in reminders) {
      final when = startTime.subtract(r['offset'] as Duration);
      if (when.isAfter(now)) {
        await _scheduleLocal(
          id: sessionId.hashCode + r['title'].hashCode,
          title: r['title'] as String,
          body: r['body'] as String,
          when: when,
        );
      }
    }
  }

  static Future<void> _scheduleLocal({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    await _local.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('poker_reminders', 'Påminnelser', importance: Importance.high),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> notifyRebuy({
    required String sessionId,
    required String playerName,
    required double amount,
  }) async {
    final session = await FirebaseFirestore.instance.collection('sessions').doc(sessionId).get();
    if (!session.exists) return;

    final players = (session.data()?['players'] as Map?)?.keys ?? [];
    final tokens = <String>[];

    for (final uid in players) {
      final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final token = user.data()?['fcmToken'] as String?;
      if (token != null) tokens.add(token);
    }

    if (tokens.isEmpty) return;

    // Note: In production, send via Cloud Function. This is a placeholder for structure.
    debugPrint('Would notify ${tokens.length} players about rebuy by $playerName');
  }

  static Future<void> notifySessionEnded({
    required String sessionId,
    required String sessionName,
  }) async {
    final session = await FirebaseFirestore.instance.collection('sessions').doc(sessionId).get();
    if (!session.exists) return;

    final players = (session.data()?['players'] as Map?)?.keys ?? [];
    for (final uid in players) {
      final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final token = user.data()?['fcmToken'] as String?;
      if (token != null) {
        debugPrint('Would notify $uid that $sessionName ended');
      }
    }
  }
}
