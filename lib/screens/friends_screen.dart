import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import 'chat_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  List<QueryDocumentSnapshot> _searchResults = [];
  bool _searching = false;
  Set<String> _sentRequests = {};

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

  Future<void> _search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      final me = FirebaseAuth.instance.currentUser?.uid;

      final results = snap.docs.where((d) {
        if (d.id == me) return false;
        final data = d.data();
        final name = (data['username'] as String?)?.toLowerCase() ?? '';
        final hasSet = data['hasSetUsername'] == true;
        return hasSet && name.isNotEmpty && name.contains(q);
      }).toList();

      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest(String toUid, String username) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;

    setState(() => _sentRequests.add(toUid));

    await FirebaseFirestore.instance.collection('friendRequests').add({
      'from': me,
      'to': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Send notification
    final myDoc = await FirebaseFirestore.instance.collection('users').doc(me).get();
    final myUsername = myDoc.data()?['username'] ?? 'Någon';
    await NotificationService.sendFriendRequestNotification(toUid, myUsername);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Förfrågan skickad till $username'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _acceptRequest(String requestId, String fromUid) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;

    try {
      await FirebaseFirestore.instance.collection('friendRequests').doc(requestId).update({
        'status': 'accepted',
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(me)
          .collection('friends')
          .doc(fromUid)
          .set({'addedAt': FieldValue.serverTimestamp()});

      await FirebaseFirestore.instance
          .collection('users')
          .doc(fromUid)
          .collection('friends')
          .doc(me)
          .set({'addedAt': FieldValue.serverTimestamp()});

      // Send accepted notification to the person who sent the request
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(me).get();
      final myUsername = myDoc.data()?['username'] ?? 'Någon';
      await NotificationService.sendFriendAcceptedNotification(fromUid, myUsername);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.people, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Ni är nu vänner!'),
              ],
            ),
            backgroundColor: Colors.cyan.shade700,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Accept error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Vänner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyan,
          indicatorWeight: 3,
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
          // Search tab remains the same as before
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.cyan),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white38),
                            onPressed: () {
                              _searchController.clear();
                              _search('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) {
                    setState(() {});
                    _search(v);
                  },
                ),
              ),
              Expanded(
                child: _searching
                    ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
                    : _searchController.text.trim().isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search, size: 64, color: Colors.white12),
                                SizedBox(height: 16),
                                Text('Sök efter användarnamn', style: TextStyle(color: Colors.white38, fontSize: 16)),
                              ],
                            ),
                          )
                        : _searchResults.isEmpty
                            ? const Center(
                                child: Text('Inga användare hittades', style: TextStyle(color: Colors.white38)),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                itemCount: _searchResults.length,
                                itemBuilder: (context, i) {
                                  final doc = _searchResults[i];
                                  final data = doc.data() as Map;
                                  final username = data['username'] as String? ?? 'Okänd';
                                  final photoUrl = data['photoUrl'] as String?;
                                  final alreadySent = _sentRequests.contains(doc.id);

                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1A1A),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.cyan,
                                        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                                            ? NetworkImage(photoUrl)
                                            : null,
                                        child: photoUrl == null || photoUrl.isEmpty
                                            ? const Icon(Icons.person, color: Colors.black)
                                            : null,
                                      ),
                                      title: Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                      trailing: alreadySent
                                          ? const Icon(Icons.check, color: Colors.green)
                                          : IconButton(
                                              icon: const Icon(Icons.person_add, color: Colors.cyan),
                                              onPressed: () => _sendRequest(doc.id, username),
                                            ),
                                    ),
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
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: Colors.cyan));
              }
              final requests = snap.data!.docs;
              if (requests.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.white12),
                      SizedBox(height: 16),
                      Text('Inga förfrågningar', style: TextStyle(color: Colors.white38, fontSize: 16)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: requests.length,
                itemBuilder: (context, i) {
                  final req = requests[i].data() as Map;
                  final fromUid = req['from'] as String;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(fromUid).get(),
                    builder: (context, userSnap) {
                      final userData = userSnap.data?.data() as Map? ?? {};
                      final name = userData['username'] ?? 'Okänd';
                      final photoUrl = userData['photoUrl'] as String?;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.cyan,
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl == null || photoUrl.isEmpty
                                ? const Icon(Icons.person, color: Colors.black)
                                : null,
                          ),
                          title: Text(name.toString(), style: const TextStyle(color: Colors.white)),
                          subtitle: const Text('Vill bli vän', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: ElevatedButton(
                            onPressed: () => _acceptRequest(requests[i].id, fromUid),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Acceptera', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),

          // Friends tab remains the same
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(me)
                .collection('friends')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.cyan));
              }
              if (snap.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Fel: ${snap.error}', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                    ],
                  ),
                );
              }

              final friends = snap.data?.docs ?? [];
              if (friends.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.white12),
                      SizedBox(height: 16),
                      Text('Inga vänner ännu', style: TextStyle(color: Colors.white38, fontSize: 16)),
                      SizedBox(height: 8),
                      Text('Sök efter användare och skicka förfrågningar', style: TextStyle(color: Colors.white24, fontSize: 13)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: friends.length,
                itemBuilder: (context, i) {
                  final friendId = friends[i].id;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData) {
                        return const ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.grey),
                          title: Text('Laddar...', style: TextStyle(color: Colors.white38)),
                        );
                      }

                      final data = userSnap.data?.data() as Map? ?? {};
                      final name = data['username'] ?? 'Okänd';
                      final photoUrl = data['photoUrl'] as String?;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.cyan,
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl == null || photoUrl.isEmpty
                                ? const Icon(Icons.person, color: Colors.black)
                                : null,
                          ),
                          title: Text(name.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                          trailing: IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, color: Colors.cyan),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(friendId: friendId, friendName: name.toString()),
                              ),
                            ),
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