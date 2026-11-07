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
    final playerIds = (widget.data['players'] as Map?)?.keys.toList() ?? [];
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
        _playerNames = names;
        _playerPhotoUrls = photos;
      });
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
                            const Text('VÄRDE I BORDET', style: TextStyle(color: Colors.amber, fontSize: 12, letterSpacing: 1.5)),
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

            const SizedBox(height: 28),

            Opacity(
              opacity: started ? 1.0 : 0.35,
              child: IgnorePointer(
                ignoring: !started,
                child: Column(
                  children: [
                    Center(
                      child: PokerTableWidget(
                        playerCount: _playerNames.length,
                        playerNames: _playerNames,
                        playerPhotoUrls: _playerPhotoUrls,
                        isAdmin: isAdmin && started,
                        onPlayerTap: _addBuyInForPlayer,
                      ),
                    ),
                    const SizedBox(height: 28),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Historik', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData || !snap.data!.exists) {
                          return const Text('Sessionen finns inte längre', style: TextStyle(color: Colors.white38));
                        }
                        final events = (snap.data!.data() as Map<String, dynamic>?)?['events'] as List? ?? [];
                        if (events.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('Inga inköp ännu', style: TextStyle(color: Colors.white38)),
                          );
                        }
                        return Column(
                          children: events.reversed.map<Widget>((e) {
                            final m = e as Map;
                            final name = m['playerName'] ?? 'Okänd';
                            final amount = m['amount'] ?? 0;
                            final type = m['type'] == 'rebuy' ? 'Rebuy' : 'Buy-in';
                            final time = m['time'] ?? '';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(type == 'Rebuy' ? Icons.refresh : Icons.add_circle, color: Colors.cyan, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('$type – $amount SEK', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                        Text(name, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  Text(time.length > 16 ? time.substring(11, 16) : time, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
