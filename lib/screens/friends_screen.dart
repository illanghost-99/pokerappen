import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _results = [];
  bool _searching = false;

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: q)
        .where('username', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(10)
        .get();
    setState(() {
      _results = snap.docs;
      _searching = false;
    });
  }

  Future<void> _sendRequest(String toUid) async {
    final fromUid = FirebaseAuth.instance.currentUser?.uid;
    if (fromUid == null) return;
    await FirebaseFirestore.instance.collection('friendRequests').add({
      'from': fromUid,
      'to': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Förfrågan skickad')));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Vänner', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Sök användarnamn',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.search, color: Colors.cyan), onPressed: _search),
              ],
            ),
          ),
          if (_searching) const LinearProgressIndicator(color: Colors.cyan),
          if (_results.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final d = _results[i].data() as Map<String, dynamic>;
                  return Card(
                    color: const Color(0xFF1A1A1A),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Text(d['username'] ?? '', style: const TextStyle(color: Colors.white)),
                          TextButton(onPressed: () => _sendRequest(_results[i].id), child: const Text('Lägg till')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const Divider(color: Colors.white12),
          const Padding(padding: EdgeInsets.all(8), child: Text('Dina vänner', style: TextStyle(color: Colors.white54))),
          Expanded(
            child: uid == null
                ? const SizedBox()
                : StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final friends = (snap.data!.data() as Map?)?['friends'] as List? ?? [];
                      if (friends.isEmpty) return const Center(child: Text('Inga vänner ännu', style: TextStyle(color: Colors.white38)));
                      return ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(friends[i].toString(), style: const TextStyle(color: Colors.white)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
