import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_session_screen.dart';
import 'session_detail_screen.dart';
import 'friends_screen.dart';
import 'username_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUsername());
  }

  Future<void> _checkUsername() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && (doc.data()?['username'] == null || (doc.data()?['username'] as String?)?.isEmpty == true)) {
      if (mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const UsernameSetupScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Poker Night', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline, color: Colors.cyan),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.cyan,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSessionScreen())),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Ny session', style: TextStyle(color: Colors.black)),
      ),
      body: uid == null
          ? const Center(child: Text('Inte inloggad'))
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
                        Text('♠ ♥ ♣ ♦', style: TextStyle(fontSize: 48, color: Colors.white24)),
                        SizedBox(height: 16),
                        Text('Inga sessioner ännu', style: TextStyle(color: Colors.white54, fontSize: 18)),
                        SizedBox(height: 8),
                        Text('Tryck på knappen nedan', style: TextStyle(color: Colors.white38)),
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
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 300 + index * 50),
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
                      ),
                      child: Card(
                        color: const Color(0xFF1A1A1A),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: const CircleAvatar(backgroundColor: Colors.cyan, child: Icon(Icons.style, color: Colors.black)),
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
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
