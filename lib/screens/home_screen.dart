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
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Mina pokerkvällar', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.people, color: Colors.cyan),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyan,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSessionScreen())),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: uid == null
          ? const Center(child: Text('Inte inloggad', style: TextStyle(color: Colors.white)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sessions')
                  .where('players.$uid', isNotEqualTo: null)
                  .orderBy('startTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.cyan));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.casino_outlined, size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('Inga sessioner ännu', style: TextStyle(color: Colors.white54, fontSize: 18)),
                        SizedBox(height: 8),
                        Text('Tryck + för att skapa din första pokerkväll', style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  );
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final start = (data['startTime'] as Timestamp?)?.toDate();
                    return Card(
                      color: const Color(0xFF1A1A1A),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: const Icon(Icons.style, color: Colors.cyan, size: 32),
                        title: Text(data['name'] ?? 'Session', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${data['address'] ?? ''} • ${data['type'] ?? ''}\n${start != null ? '${start.day}/${start.month} ${start.hour}:${start.minute.toString().padLeft(2, '0')}' : ''}',
                          style: const TextStyle(color: Colors.white54),
                        ),
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
