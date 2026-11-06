import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Vänner', style: TextStyle(color: Colors.white)),
      ),
      body: uid == null
          ? const Center(child: Text('Logga in', style: TextStyle(color: Colors.white)))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyan));
                final data = snap.data!.data() as Map<String, dynamic>?;
                final friends = (data?['friends'] as List?) ?? [];
                if (friends.isEmpty) {
                  return const Center(
                    child: Text('Inga vänner ännu', style: TextStyle(color: Colors.white54, fontSize: 18)),
                  );
                }
                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(friends[i].toString(), style: const TextStyle(color: Colors.white)),
                    trailing: IconButton(
                      icon: const Icon(Icons.block, color: Colors.red),
                      onPressed: () {},
                    ),
                  ),
                );
              },
            ),
    );
  }
}
