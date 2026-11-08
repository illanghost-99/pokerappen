import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../widgets/countdown_widget.dart';
import '../widgets/poker_table_widget.dart';
import 'summary_screen.dart';
import '../services/notification_service.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic> data;
  const SessionDetailScreen({super.key, required this.sessionId, required this.data});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  List<String> _playerIds = [];
  List<String> _playerNames = [];
  List<String?> _playerPhotoUrls = [];
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  DateTime? _sessionStartedAt;

  bool get _hasStarted {
    final start = (widget.data['startTime'] as Timestamp?)?.toDate();
    if (start == null) return true;
    return DateTime.now().isAfter(start);
  }

  @override
  void initState() {
    super.initState();
    _loadPlayerDetails();
    _listenForSessionStart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _listenForSessionStart() {
    FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).snapshots().listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data()!;
      final events = data['events'] as List? ?? [];
      final ended = data['ended'] == true;

      if (!ended && events.isNotEmpty && _sessionStartedAt == null) {
        DateTime? earliest;
        for (final e in events) {
          final t = DateTime.tryParse(e['time'] ?? '');
          if (t != null && (earliest == null || t.isBefore(earliest))) {
            earliest = t;
          }
        }
        if (earliest != null) {
          setState(() {
            _sessionStartedAt = earliest;
            _elapsed = DateTime.now().difference(earliest!);
          });
          _startCountUp();
        }
      }
    });
  }

  void _startCountUp() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sessionStartedAt != null && mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_sessionStartedAt!);
        });
      }
    });
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _loadPlayerDetails() async {
    final session = await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).get();
    final playerIds = (session.data()?['players'] as Map?)?.keys.toList() ?? [];
    final names = <String>[];
    final photos = <String?>[];

    for (final id in playerIds) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
        if (doc.exists) {
          names.add(doc.data()?['username'] ?? id);
          photos.add(doc.data()?['photoUrl']);
        } else {
          names.add(id);
          photos.add(null);
        }
      } catch (_) {
        names.add(id);
        photos.add(null);
      }
    }

    if (mounted) {
      setState(() {
        _playerIds = playerIds.cast<String>();
        _playerNames = names;
        _playerPhotoUrls = photos;
      });
    }
  }

  Future<void> _addPlayerFromFriends() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;

    final friendsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(me)
        .collection('friends')
        .get();

    if (friendsSnap.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Du har inga vänner att lägga till'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final friends = <Map<String, dynamic>>[];
    for (final f in friendsSnap.docs) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(f.id).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        friends.add({
          'uid': f.id,
          'username': data['username'] ?? 'Okänd',
          'photoUrl': data['photoUrl'],
        });
      }
    }

    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Välj vän att lägga till', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: friends.length,
                itemBuilder: (context, i) {
                  final f = friends[i];
                  final alreadyAdded = _playerIds.contains(f['uid']);
                  final photoUrl = f['photoUrl'] as String?;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.cyan,
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null || photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.black) : null,
                    ),
                    title: Text(f['username'], style: const TextStyle(color: Colors.white)),
                    trailing: alreadyAdded
                        ? const Icon(Icons.check, color: Colors.green)
                        : const Icon(Icons.add, color: Colors.cyan),
                    onTap: alreadyAdded ? null : () => Navigator.pop(c, f['uid']),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );

    if (selected == null) return;

    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'players.$selected': true,
    });

    await _loadPlayerDetails();

    if (mounted) {
      final name = friends.firstWhere((f) => f['uid'] == selected)['username'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name tillagd'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _removePlayer(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Ta bort spelare?', style: TextStyle(color: Colors.white)),
        content: Text('$name tas bort och får inga notiser.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Avbryt')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'players.$uid': FieldValue.delete(),
    });

    await _loadPlayerDetails();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name borttagen'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _addBuyInForPlayer(String playerId, String playerName) async {
    if (!_hasStarted) return;

    final amountController = TextEditingController();
    String type = 'buyin';

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        Text('Lägg till för $playerName', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(c, false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 28),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: 'Belopp',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Color(0xFF2A2A2A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Buy-in'),
                          selected: type == 'buyin',
                          onSelected: (_) => setModalState(() => type = 'buyin'),
                          selectedColor: Colors.cyan,
                          labelStyle: TextStyle(color: type == 'buyin' ? Colors.black : Colors.white),
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Rebuy'),
                          selected: type == 'rebuy',
                          onSelected: (_) => setModalState(() => type = 'rebuy'),
                          selectedColor: Colors.cyan,
                          labelStyle: TextStyle(color: type == 'rebuy' ? Colors.black : Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Lägg till', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true) return;

    final amount = double.tryParse(amountController.text) ?? 0;
    if (amount <= 0) return;

    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'buyIns': FieldValue.arrayUnion([{'userId': playerId, 'playerName': playerName, 'amount': amount, 'timestamp': DateTime.now().toIso8601String(), 'type': type}]),
      'events': FieldValue.arrayUnion([{'type': type, 'userId': playerId, 'playerName': playerName, 'amount': amount, 'time': DateTime.now().toIso8601String()}]),
    });

    if (type == 'rebuy') {
      await NotificationService.notifyRebuy(
        sessionId: widget.sessionId,
        playerName: playerName,
        amount: amount,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('${type == 'rebuy' ? 'Rebuy' : 'Buy-in'} $amount SEK för $playerName')),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Avsluta session?', style: TextStyle(color: Colors.white)),
        content: const Text('Sessionen markeras som avslutad.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Avbryt')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Avsluta'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'ended': true,
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });

    _timer?.cancel();

    await NotificationService.notifySessionEnded(
      sessionId: widget.sessionId,
      sessionName: widget.data['name'] ?? 'Session',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session avslutad'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _deleteSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Radera session?', style: TextStyle(color: Colors.white)),
        content: const Text('Sessionen tas bort permanent.', style: TextStyle(color: Colors.white70)),
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

    FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [Icon(Icons.delete, color: Colors.white), SizedBox(width: 10), Text('Session raderad')]),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = (widget.data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isAdmin = widget.data['ownerId'] == FirebaseAuth.instance.currentUser?.uid;
    final started = _hasStarted;
    final isLive = _sessionStartedAt != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.data['name'] ?? 'Session', style: const TextStyle(color: Colors.white)),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.cyan),
              tooltip: 'Lägg till spelare',
              onPressed: _addPlayerFromFriends,
            ),
            if (isLive)
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined, color: Colors.orange),
                tooltip: 'Avsluta session',
                onPressed: _endSession,
              ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: _deleteSession,
            ),
            IconButton(
              icon: const Icon(Icons.summarize, color: Colors.cyan),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SummaryScreen(sessionId: widget.sessionId))),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.data['address'] ?? '', style: const TextStyle(fontSize: 16, color: Colors.white70)),
            const SizedBox(height: 8),
            Text('${widget.data['type'] ?? ''} • ${widget.data['currency'] ?? ''}', style: const TextStyle(color: Colors.cyan)),
            const SizedBox(height: 20),

            if (isAdmin && _playerIds.isNotEmpty) ...[
              const Text('Spelare', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...List.generate(_playerIds.length, (i) {
                final isOwner = _playerIds[i] == widget.data['ownerId'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Expanded(child: Text(_playerNames[i], style: const TextStyle(color: Colors.white))),
                      if (!isOwner)
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                          onPressed: () => _removePlayer(_playerIds[i], _playerNames[i]),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            if (isLive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    const Text('SPELTID', style: TextStyle(color: Colors.green, fontSize: 12, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text(
                      _formatElapsed(_elapsed),
                      style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData || !snap.data!.exists) return const SizedBox();
                        final events = (snap.data!.data() as Map<String, dynamic>?)?['events'] as List? ?? [];
                        double total = 0;
                        for (final e in events) {
                          total += (e['amount'] as num?)?.toDouble() ?? 0;
                        }
                        return Column(
                          children: [
                            const Divider(color: Colors.white12),
                            const SizedBox(height: 8),
                            const Text('VÄRDE I BORDET', style: TextStyle(color: Colors.cyan, fontSize: 12, letterSpacing: 2)),
                            const SizedBox(height: 4),
                            Text(
                              '${total.toStringAsFixed(0)} SEK',
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              )
            else
              CountdownWidget(target: start),

            const SizedBox(height: 24),

            Center(
              child: PokerTableWidget(
                playerCount: _playerIds.length,
                playerNames: _playerNames,
                playerPhotoUrls: _playerPhotoUrls,
                isAdmin: isAdmin && started,
                onPlayerTap: isAdmin && started ? (playerId, playerName) {
                  final index = _playerNames.indexOf(playerName);
                  if (index >= 0 && index < _playerIds.length) {
                    _addBuyInForPlayer(_playerIds[index], playerName);
                  }
                } : null,
              ),
            ),

            const SizedBox(height: 24),

            if (!started)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Sessionen har inte börjat än. Buy-ins låses upp när tiden är inne.',
                  style: TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
