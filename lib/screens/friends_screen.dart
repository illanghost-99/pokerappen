import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Vänner')),
      body: uid == null
          ? const Center(child: Text('Logga in'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final friends = (snap.data!.data() as Map?)?['friends'] as List? ?? [];
                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (_, i) => ListTile(title: Text(friends[i].toString())),
                );
              },
            ),
    );
  }
}
