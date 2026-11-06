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
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E), Color(0xFF16213E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Poker theme icons instead of dice
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite, size: 48, color: Colors.red[400]),
                  const SizedBox(width: 12),
                  Icon(Icons.diamond, size: 48, color: Colors.red[300]),
                  const SizedBox(width: 12),
                  Icon(Icons.spa, size: 48, color: Colors.green[400]),
                  const SizedBox(width: 12),
                  Icon(Icons.local_florist, size: 48, color: Colors.blue[300]),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '♠ ♥ ♣ ♦',
                style: TextStyle(fontSize: 32, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              const Text(
                'Poker Night',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pocket Aces • Premium Session Tracker',
                style: TextStyle(fontSize: 14, color: Colors.cyan),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
