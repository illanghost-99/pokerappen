import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/poker_table_widget.dart';
import '../widgets/countdown_widget.dart';
import 'summary_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic>? data;
  const SessionDetailScreen({super.key, required this.sessionId, this.data});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  List<String> _playerIds = [];
  List<String> _playerNames = [];
  List<String?> _playerPhotoUrls = [];
  List<double> _playerChipValues = [];
  List<String?> _playerCashoutResults = [];
  List<bool> _isFinished = [];
  bool _isEnded = false;
  bool _hasStarted = false;
  DateTime? _startedAt;
  DateTime? _sessionDate;

  @override
  void initState() {
    super.initState();
    _loadPlayerDetails();
  }

  Future<void> _loadPlayerDetails() async {
    final doc = await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final players = data['players'] as Map? ?? {};
    final finished = List<String>.from(data['finishedPlayers'] ?? []);
    final cashouts = data['cashouts'] as List? ?? [];
    final events = data['events'] as List? ?? [];
    _isEnded = data['ended'] == true;
    _startedAt = (data['startedAt'] as Timestamp?)?.toDate();
    _sessionDate = (data['date'] as Timestamp?)?.toDate() ?? (data['startTime'] as Timestamp?)?.toDate();
    _hasStarted = _startedAt != null;

    final ids = players.keys.cast<String>().toList();
    final names = <String>[];
    final photos = <String?>[];
    final chips = <double>[];
    final results = <String?>[];
    final finishedFlags = <bool>[];

    for (final id in ids) {
      String name = 'Spelare';
      String? photo;
      if (id.startsWith('manual_')) {
        final manuals = data['manualPlayers'] as List? ?? [];
        final m = manuals.cast<Map>().firstWhere((e) => e['id'] == id, orElse: () => {});
        name = m['name'] ?? 'Spelare';
      } else {
        final u = await FirebaseFirestore.instance.collection('users').doc(id).get();
        name = u.data()?['displayName'] ?? 'Spelare';
        photo = u.data()?['photoUrl'];
      }
      names.add(name);
      photos.add(photo);

      double total = 0;
      for (final e in events) {
        if (e['userId'] == id) total += (e['amount'] as num?)?.toDouble() ?? 0;
      }
      chips.add(total);

      final co = cashouts.cast<Map>().firstWhere((c) => c['userId'] == id, orElse: () => {});
      results.add(co['result']);
      finishedFlags.add(finished.contains(id));
    }

    if (mounted) {
      setState(() {
        _playerIds = ids;
        _playerNames = names;
        _playerPhotoUrls = photos;
        _playerChipValues = chips;
        _playerCashoutResults = results;
        _isFinished = finishedFlags;
      });
    }
  }

  void _showPlayerOptions(String playerId, String playerName, int index) {
    if (_isFinished[index]) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add, color: Colors.cyan),
              title: const Text('Lägg till buy-in / rebuy', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(c);
                _addBuyInForPlayer(playerId, playerName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.green),
              title: const Text('Spelare klar (cash out)', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(c);
                _cashOutPlayer(playerId, playerName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.orange),
              title: const Text('Ta bort spelare', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(c);
                _removePlayer(playerId, playerName);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addBuyInForPlayer(String playerId, String playerName) async {
    if (!_hasStarted || _isEnded) return;

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

    await _loadPlayerDetails();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type == 'rebuy' ? 'Rebuy' : 'Buy-in'} tillagd'), backgroundColor: Colors.cyan),
      );
    }
  }

  Future<void> _cashOutPlayer(String playerId, String playerName) async {
    final amountController = TextEditingController();
    String resultType = 'plus';

    final confirmed = await showModalBottomSheet<bool>(
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
                    Text('Cash out – $playerName', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _cashOption('Plus', Colors.green, resultType == 'plus', () => setModalState(() => resultType = 'plus')),
                        _cashOption('Minus', Colors.red, resultType == 'minus', () => setModalState(() => resultType = 'minus')),
                        _cashOption('±0', Colors.black, resultType == 'even', () => setModalState(() => resultType = 'even')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (resultType != 'even')
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 24),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: resultType == 'plus' ? 'Cashade ut (kr)' : 'Kvar / minus (kr)',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Spara', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

    if (confirmed != true) return;

    double cashoutAmount = 0;
    if (resultType != 'even') {
      cashoutAmount = double.tryParse(amountController.text) ?? 0;
    }

    final sessionDoc = await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).get();
    final events = sessionDoc.data()?['events'] as List? ?? [];
    double totalBuyIns = 0;
    for (final e in events) {
      if (e['userId'] == playerId) {
        totalBuyIns += (e['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    double profit = 0;
    if (resultType == 'plus') profit = cashoutAmount - totalBuyIns;
    else if (resultType == 'minus') profit = -cashoutAmount;

    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'finishedPlayers': FieldValue.arrayUnion([playerId]),
      'cashouts': FieldValue.arrayUnion([{
        'userId': playerId,
        'playerName': playerName,
        'cashoutAmount': cashoutAmount,
        'totalBuyIns': totalBuyIns,
        'profit': profit,
        'result': resultType,
        'time': DateTime.now().toIso8601String(),
      }]),
    });

    await _loadPlayerDetails();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$playerName är klar'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _removePlayer(String uid, String name) async {
    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'players.$uid': FieldValue.delete(),
      'participants': FieldValue.arrayRemove([uid]),
    });
    await _loadPlayerDetails();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name borttagen'), backgroundColor: Colors.orange),
      );
    }
  }

  Widget _cashOption(String label, Color color, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: selected ? 2 : 1),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _endSession() async {
    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'ended': true,
      'endedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SummaryScreen(sessionId: widget.sessionId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = true;
    final started = _hasStarted;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Session', style: TextStyle(color: Colors.white)),
        actions: [
          if (isAdmin && !_isEnded)
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.red),
              onPressed: _endSession,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Always show countdown / date
            if (_sessionDate != null)
              CountdownWidget(target: _sessionDate!),
            const SizedBox(height: 16),
            Center(
              child: PokerTableWidget(
                playerCount: _playerIds.length,
                playerNames: _playerNames,
                playerPhotoUrls: _playerPhotoUrls,
                playerChipValues: _playerChipValues,
                playerCashoutResults: _playerCashoutResults,
                isAdmin: isAdmin && started && !_isEnded,
                isEnded: _isEnded,
                onPlayerTap: isAdmin && started && !_isEnded ? (playerId, playerName) {
                  final index = _playerNames.indexOf(playerName);
                  if (index >= 0 && index < _playerIds.length) {
                    _showPlayerOptions(_playerIds[index], playerName, index);
                  }
                } : null,
                onContinue: isAdmin && started && !_isEnded ? (playerId, playerName) async {
                  await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
                    'finishedPlayers': FieldValue.arrayRemove([playerId]),
                  });
                  await _loadPlayerDetails();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$playerName fortsätter'), backgroundColor: Colors.cyan),
                    );
                  }
                } : null,
                onViewPhoto: (photoUrl, name) {
                  if (photoUrl == null || photoUrl.isEmpty) return;
                  showDialog(
                    context: context,
                    barrierColor: Colors.black54,
                    builder: (c) => GestureDetector(
                      onTap: () => Navigator.pop(c),
                      child: Center(
                        child: CircleAvatar(
                          radius: 90,
                          backgroundImage: NetworkImage(photoUrl),
                          backgroundColor: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  );
                },
                isFinished: _isFinished,
              ),
            ),
            const SizedBox(height: 24),
            if (!started && !_isEnded)
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
