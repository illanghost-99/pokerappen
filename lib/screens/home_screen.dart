import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    if (!doc.exists || doc.data()?['username'] == null || (doc.data()?['username'] as String).isEmpty) {
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
        elevation: 0,
        title: const Text('Poker Night', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline, color: Colors.cyan),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.cyan),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
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

                if (snapshot.hasError) {
                  return Center(child: Text('Fel: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }

                final docs = snapshot.data?.docs ?? [];

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Välkommen tillbaka', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          SizedBox(height: 4),
                          Text('Dina pokerkvällar', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Inkommande sessioner', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    if (docs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.event_busy, size: 48, color: Colors.white38),
                            SizedBox(height: 12),
                            Text('Du har tyvärr inga sessioner just nu', style: TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                            SizedBox(height: 8),
                            Text('Skapa en ny eller bli inbjuden', style: TextStyle(color: Colors.white38), textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    else
                      ...docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final start = (data['startTime'] as Timestamp?)?.toDate();
                        return Card(
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
                              MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: doc.id, data: data)),
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
    );
  }
}
