import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final user = userCredential.user;

      if (user != null) {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final doc = await userDoc.get();

        if (!doc.exists) {
          await userDoc.set({
            'uid': user.uid,
            'email': user.email ?? appleCredential.email,
            'displayName': user.displayName ?? '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim(),
            'username': null,
            'photoURL': user.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
            'friends': [],
            'blocked': [],
          });
        }
      }
    } catch (e) {
      debugPrint('Apple Sign In error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E), Color(0xFF0F0F23)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pocket Aces visual
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _pokerCard('♠', 'A', Colors.black),
                  const SizedBox(width: 16),
                  _pokerCard('♥', 'A', Colors.red),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'POKER NIGHT',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pocket Aces Session Tracker',
                style: TextStyle(fontSize: 14, color: Colors.cyan, letterSpacing: 1),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _signInWithApple,
                icon: const Icon(Icons.apple),
                label: const Text('Logga in med Apple'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pokerCard(String suit, String rank, Color color) {
    return Container(
      width: 70,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(2, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(rank, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          Text(suit, style: TextStyle(fontSize: 32, color: color)),
        ],
      ),
    );
  }
}
