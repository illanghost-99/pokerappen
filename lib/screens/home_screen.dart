import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _checkedUsername = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUsername();
      NotificationService.init();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkUsername() async {
    if (_checkedUsername) return;
    _checkedUsername = true;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      final username = data?['username'] as String?;
      final hasSetUsername = data?['hasSetUsername'] == true;

      if (!doc.exists || !hasSetUsername || username == null || username.trim().isEmpty) {
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UsernameSetupScreen(), fullscreenDialog: true),
          );
        }
      }
    } catch (e) {
      debugPrint('Username check error: $e');
    }
  }

  List<QueryDocumentSnapshot> _sortSessions(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final live = <QueryDocumentSnapshot>[];
    final upcoming = <QueryDocumentSnapshot>[];
    final finished = <QueryDocumentSnapshot>[];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final start = (data['startTime'] as Timestamp?)?.toDate();
      final ended = data['ended'] == true || data['status'] == 'ended';
      final hasEvents = (data['events'] as List?)?.isNotEmpty == true;

      if (ended) {
        finished.add(doc);
      } else if (hasEvents || (start != null && start.isBefore(now))) {
        live.add(doc);
      } else {
        upcoming.add(doc);
      }
    }

    live.sort((a, b) {
      final aStart = (a.data() as Map)['startTime'] as Timestamp?;
      final bStart = (b.data() as Map)['startTime'] as Timestamp?;
      return (bStart?.toDate() ?? DateTime.now()).compareTo(aStart?.toDate() ?? DateTime.now());
    });

    upcoming.sort((a, b) {
      final aStart = (a.data() as Map)['startTime'] as Timestamp?;
      final bStart = (b.data() as Map)['startTime'] as Timestamp?;
      return (aStart?.toDate() ?? DateTime.now()).compareTo(bStart?.toDate() ?? DateTime.now());
    });

    finished.sort((a, b) {
      final aStart = (a.data() as Map)['startTime'] as Timestamp?;
      final bStart = (b.data() as Map)['startTime'] as Timestamp?;
      return (bStart?.toDate() ?? DateTime.now()).compareTo(aStart?.toDate() ?? DateTime.now());
    });

    return [...live, ...upcoming, ...finished];
  }

  Future<void> _confirmDeleteEndedSession(String sessionId, String sessionName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Radera session?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Är du säker på att du vill radera "$sessionName"?\n\nDen försvinner för alla deltagare.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Avbryt')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Radera'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await FirebaseFirestore.instance.collection('sessions').doc(sessionId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session raderad'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kunde inte radera sessionen'), backgroundColor: Colors.red),
        );
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
        title: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Text(
              'Poker Night',
              style: TextStyle(
                color: Colors.cyan,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                shadows: [
                  Shadow(
                    color: Colors.cyan.withOpacity(0.6 + _animController.value * 0.4),
                    blurRadius: 12 + _animController.value * 8,
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('friendRequests')
                .where('to', isEqualTo: uid)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.people_outline, color: Colors.cyan),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen())),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
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
        label: const Text('Ny session', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: uid == null
          ? const Center(child: Text('Inte inloggad'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sessions')
                  .where('participants', arrayContains: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.cyan));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Fel: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }

                final docs = _sortSessions(snapshot.data?.docs ?? []);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF1A1A1A), Colors.cyan.withOpacity(0.08)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
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
                    const Text('Sessioner', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    if (docs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
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
                      ...docs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final doc = entry.value;
                        final data = doc.data() as Map<String, dynamic>;
                        final start = (data['startTime'] as Timestamp?)?.toDate();
                        final ended = data['ended'] == true || data['status'] == 'ended';
                        final hasEvents = (data['events'] as List?)?.isNotEmpty == true;
                        final isLive = !ended && (hasEvents || (start != null && start.isBefore(DateTime.now())));
                        final isAdmin = data['ownerId'] == uid;

                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 400 + index * 80),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isLive ? Colors.amber.withOpacity(0.7) : (ended ? Colors.white12 : Colors.cyan.withOpacity(0.25)),
                                width: isLive ? 2 : 1,
                              ),
                              boxShadow: [
                                if (isLive)
                                  BoxShadow(color: Colors.amber.withOpacity(0.25), blurRadius: 16, spreadRadius: 1),
                                if (!ended && !isLive)
                                  BoxShadow(color: Colors.cyan.withOpacity(0.08), blurRadius: 12, spreadRadius: 1),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              leading: _TwoAcesIcon(),
                              title: Text(
                                data['name'] ?? 'Session',
                                style: TextStyle(
                                  color: ended ? Colors.white54 : Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${data['address'] ?? ''} • ${data['type'] ?? ''}\n${start != null ? '${start.day}/${start.month} ${start.hour}:${start.minute.toString().padLeft(2, '0')}' : ''}${ended ? ' • Avslutad' : isLive ? ' • Pågående' : ''}',
                                style: TextStyle(color: ended ? Colors.white38 : Colors.white54),
                              ),
                              trailing: const Icon(Icons.chevron_right, color: Colors.cyan),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: doc.id, data: data)),
                              ),
                              onLongPress: (ended && isAdmin)
                                  ? () => _confirmDeleteEndedSession(doc.id, data['name'] ?? 'Session')
                                  : null,
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

class _TwoAcesIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          Positioned(
            left: 4,
            top: 6,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                width: 28,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
                ),
                child: const Center(
                  child: Text('♠', style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 2,
            child: Transform.rotate(
              angle: 0.1,
              child: Container(
                width: 28,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Center(
                  child: Text('A', style: TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}