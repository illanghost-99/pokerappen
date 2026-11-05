import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_session_screen.dart';
import 'session_detail_screen.dart';
import 'friends_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mina pokerkvällar'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyan,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSessionScreen())),
        child: const Icon(Icons.add),
      ),
      body: uid == null
          ? const Center(child: Text('Inte inloggad'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sessions')
                  .where('players.$uid', isNotEqualTo: null)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Inga sessioner ännu'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return Card(
                      color: Colors.grey[900],
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(data['name'] ?? 'Session'),
                        subtitle: Text(data['address'] ?? ''),
                        trailing: const Icon(Icons.chevron_right, color: Colors.cyan),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: docs[index].id, data: data)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
