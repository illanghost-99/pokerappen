import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest(String toUid) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;
    await FirebaseFirestore.instance.collection('friendRequests').add({
      'from': me,
      'to': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vänförfrågan skickad'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _acceptRequest(String requestId, String fromUid) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance.collection('friendRequests').doc(requestId), {'status': 'accepted'});
    batch.set(FirebaseFirestore.instance.collection('users').doc(me).collection('friends').doc(fromUid), {'addedAt': FieldValue.serverTimestamp()});
    batch.set(FirebaseFirestore.instance.collection('users').doc(fromUid).collection('friends').doc(me), {'addedAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Vänner', style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyan,
          labelColor: Colors.cyan,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Sök'),
            Tab(text: 'Förfrågningar'),
            Tab(text: 'Vänner'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Search tab
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Sök användarnamn',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.search, color: Colors.cyan),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyan));
                    final query = _searchController.text.toLowerCase();
                    final users = snap.data!.docs.where((d) {
                      final name = (d.data() as Map)['username']?.toString().toLowerCase() ?? '';
                      return name.contains(query) && d.id != me;
                    }).toList();

                    if (users.isEmpty) return const Center(child: Text('Inga användare', style: TextStyle(color: Colors.white38)));

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, i) {
                        final data = users[i].data() as Map;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.cyan, child: Icon(Icons.person, color: Colors.black)),
                            title: Text(data['username'] ?? 'Okänd', style: const TextStyle(color: Colors.white)),
                            trailing: IconButton(
                              icon: const Icon(Icons.person_add, color: Colors.cyan),
                              onPressed: () => _sendRequest(users[i].id),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // Requests tab
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('friendRequests')
                .where('to', isEqualTo: me)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyan));
              final requests = snap.data!.docs;
              if (requests.isEmpty) return const Center(child: Text('Inga förfrågningar', style: TextStyle(color: Colors.white38)));

              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, i) {
                  final req = requests[i].data() as Map;
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(req['from']).get(),
                    builder: (context, userSnap) {
                      final name = userSnap.data?.data() != null ? (userSnap.data!.data() as Map)['username'] : 'Okänd';
                      return ListTile(
                        title: Text(name.toString(), style: const TextStyle(color: Colors.white)),
                        trailing: ElevatedButton(
                          onPressed: () => _acceptRequest(requests[i].id, req['from']),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                          child: const Text('Acceptera', style: TextStyle(color: Colors.black)),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),

          // Friends tab
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(me).collection('friends').snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyan));
              final friends = snap.data!.docs;
              if (friends.isEmpty) return const Center(child: Text('Inga vänner ännu', style: TextStyle(color: Colors.white38)));

              return ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, i) {
                  final friendId = friends[i].id;
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                    builder: (context, userSnap) {
                      final data = userSnap.data?.data() as Map? ?? {};
                      final name = data['username'] ?? 'Okänd';
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.cyan, child: Icon(Icons.person, color: Colors.black)),
                        title: Text(name.toString(), style: const TextStyle(color: Colors.white)),
                        trailing: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, color: Colors.cyan),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ChatScreen(friendId: friendId, friendName: name.toString())),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
