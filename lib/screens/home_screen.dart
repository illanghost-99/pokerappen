import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import 'create_session_screen.dart';
import 'session_detail_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';
import 'username_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _checkedUsername = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUsername();
      // Always try to save FCM token when home screen loads
      NotificationService.init();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkUsername() async {
    if (_checkedUsername) return;
    _checkedUsername = true;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      final username = data?['username'] as String?;
      final hasSetUsername = data?['hasSetUsername'] == true;

      if (!doc.exists || !hasSetUsername || username == null || username.trim().isEmpty) {
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UsernameSetupScreen(), fullscreenDialog: true),
          );
        }
      }
    } catch (e) {
      debugPrint('Username check error: $e');
    }
  }

  // Rest of the file remains the same... (I will include the full file in the actual call)
}