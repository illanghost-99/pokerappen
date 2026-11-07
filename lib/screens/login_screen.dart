import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _signInWithApple() async {
    setState(() => _error = null);
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: hashedNonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      await FirebaseAuth.instance.signInWithCredential(oauthCredential);
    } on SignInWithAppleAuthorizationException catch (e) {
      setState(() => _error = 'Apple-fel: ${e.code.name}');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = 'Firebase-fel: ${e.code}');
    } catch (e) {
      setState(() => _error = 'Fel: $e');
    }
  }

  Future<void> _emailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Fyll i email och lösenord');
      return;
    }

    if (_isSignUp && username.isEmpty) {
      setState(() => _error = 'Ange ett användarnamn');
      return;
    }

    if (password.length < 6) {
      setState(() => _error = 'Lösenord måste vara minst 6 tecken');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      UserCredential cred;
      if (_isSignUp) {
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Spara användarnamn direkt
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'username': username,
          'email': email,
          'hasSetUsername': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Fel: ${e.code}';
      if (e.code == 'email-already-in-use') msg = 'Email används redan';
      if (e.code == 'user-not-found') msg = 'Användare finns inte';
      if (e.code == 'wrong-password') msg = 'Fel lösenord';
      if (e.code == 'invalid-email') msg = 'Ogiltig email';
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = 'Fel: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                'Poker Night',
                style: TextStyle(color: Colors.cyan, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp ? 'Skapa konto' : 'Logga in',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),

              // Email
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email, color: Colors.cyan),
                ),
              ),
              const SizedBox(height: 12),

              // Password
              TextField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Lösenord',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock, color: Colors.cyan),
                ),
              ),

              // Username (only for signup)
              if (_isSignUp) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Användarnamn',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person, color: Colors.cyan),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _emailAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text(
                          _isSignUp ? 'Skapa konto' : 'Logga in',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Toggle signup/login
              TextButton(
                onPressed: () => setState(() {
                  _isSignUp = !_isSignUp;
                  _error = null;
                }),
                child: Text(
                  _isSignUp ? 'Har redan konto? Logga in' : 'Inget konto? Skapa ett',
                  style: const TextStyle(color: Colors.cyan),
                ),
              ),

              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider(color: Colors.white24)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('eller', style: TextStyle(color: Colors.white38)),
                  ),
                  Expanded(child: Divider(color: Colors.white24)),
                ],
              ),
              const SizedBox(height: 24),

              // Apple login
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _signInWithApple,
                  icon: const Icon(Icons.apple, color: Colors.black),
                  label: const Text('Logga in med Apple', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
