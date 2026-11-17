import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/poker_table_widget.dart';
import '../widgets/countdown_widget.dart';
import 'summary_screen.dart';
import 'dart:async';

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
  List<Map<String, dynamic>> _events = [];
  bool _isEnded = false;
  bool _hasStarted = false;
  bool _isPrivate = false;
  bool _isPaused = false;
  bool _showStartAnim = false;
  DateTime? _startedAt;
  DateTime? _sessionDate;
  double _totalPot = 0;
  Timer? _playTimer;
  Duration _playDuration = Duration.zero;
  bool _timerRunning = false;
  String? _originalAdminId;
  String? _currentControllerId;
  String? _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _loadPlayerDetails();
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  bool get _isOriginalAdmin => _myUid != null && _myUid == _originalAdminId;
  bool get _isController => _myUid != null && (_myUid == _originalAdminId || _myUid == _currentControllerId);

  bool get _timeHasPassed {
    if (_sessionDate == null) return false;
    return DateTime.now().isAfter(_sessionDate!) || DateTime.now().isAtSameMomentAs(_sessionDate!);
  }

  void _startPlayTimer() {
    if (_timerRunning) return;
    _timerRunning = true;
    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isPaused && !_isEnded) {
        setState(() {
          _playDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  Future<void> _loadPlayerDetails() async {
    final doc = await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final players = data['players'] as Map? ?? {};
    final finished = List<String>.from(data['finishedPlayers'] ?? []);
    final cashouts = data['cashouts'] as List? ?? [];
    final events = List<Map<String, dynamic>>.from(data['events'] ?? []);
    final wasStarted = _hasStarted;
    _isEnded = data['ended'] == true;
    _isPaused = data['paused'] == true;
    _isPrivate = data['isPrivate'] == true || data['private'] == true || data['type'] == 'private';
    _startedAt = (data['startedAt'] as Timestamp?)?.toDate();
    _sessionDate = (data['date'] as Timestamp?)?.toDate() ?? (data['startTime'] as Timestamp?)?.toDate();
    _hasStarted = _startedAt != null || _isPrivate || _timeHasPassed;
    _originalAdminId = data['adminId'] ?? data['createdBy'] ?? data['ownerId'];
    _currentControllerId = data['controllerId'];

    final ids = players.keys.cast<String>().toList();
    final names = <String>[];
    final photos = <String?>[];
    final chips = <double>[];
    final results = <String?>[];
    final finishedFlags = <bool>[];
    double pot = 0;

    for (final id in ids) {
      String name = 'Spelare';
      String? photo;
      if (id.startsWith('manual_')) {
        final manuals = data['manualPlayers'] as List? ?? [];
        final m = manuals.cast<Map>().firstWhere((e) => e['id'] == id, orElse: () => {});
        name = m['name'] ?? 'Spelare';
      } else {
        final u = await FirebaseFirestore.instance.collection('users').doc(id).get();
        name = u.data()?['username'] ?? u.data()?['displayName'] ?? 'Spelare';
        photo = u.data()?['photoUrl'];
      }
      names.add(name);
      photos.add(photo);

      double total = 0;
      for (final e in events) {
        if (e['userId'] == id) total += (e['amount'] as num?)?.toDouble() ?? 0;
      }
      chips.add(total);
      pot += total;

      final co = cashouts.cast<Map>().firstWhere((c) => c['userId'] == id, orElse: () => {});
      results.add(co['result']);
      finishedFlags.add(finished.contains(id));
    }

    final hasBuyIn = events.any((e) => e['type'] == 'buyin' || e['type'] == 'rebuy');

    if (mounted) {
      setState(() {
        _playerIds = ids;
        _playerNames = names;
        _playerPhotoUrls = photos;
        _playerChipValues = chips;
        _playerCashoutResults = results;
        _isFinished = finishedFlags;
        _events = events;
        _totalPot = pot;
      });

      if (_hasStarted && !wasStarted && !_isPrivate) {
        setState(() => _showStartAnim = true);
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) setState(() => _showStartAnim = false);
        });
      }

      if (hasBuyIn && !_timerRunning && !_isEnded) {
        _startPlayTimer();
      }
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
            if (_isOriginalAdmin)
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

  Future<void> _transferControl() async {
    if (!_isOriginalAdmin) return;
    final options = <String>[];
    final names = <String>[];
    for (int i = 0; i < _playerIds.length; i++) {
      if (_playerIds[i] != _originalAdminId && !_playerIds[i].startsWith('manual_')) {
        options.add(_playerIds[i]);
        names.add(_playerNames[i]);
      }
    }
    if (options.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inga andra spelare att ge kontroll till')),
        );
      }
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ge kontroll till', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...List.generate(options.length, (i) => ListTile(
              title: Text(names[i], style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(c, options[i]),
            )),
            ListTile(
              title: const Text('Ta tillbaka kontroll', style: TextStyle(color: Colors.cyan)),
              onTap: () => Navigator.pop(c, 'revoke'),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;
    final newController = selected == 'revoke' ? null : selected;
    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'controllerId': newController,
    });
    await _loadPlayerDetails();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newController == null ? 'Kontroll tillbakatagen' : 'Kontroll överförd'), backgroundColor: Colors.cyan),
      );
    }
  }

  Future<void> _addPlayer() async {
    if (_isPrivate) {
      await _addManualPlayer();
    } else {
      await _inviteFriends();
    }
  }

  Future<void> _inviteFriends() async {
    if (_myUid == null) return;

    final friendsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_myUid)
        .collection('friends')
        .get();

    final friendIds = friendsSnap.docs.map((d) => d.id).where((id) => !_playerIds.contains(id)).toList();

    if (friendIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inga fler vänner att bjuda in')),
        );
      }
      return;
    }

    final friendDocs = await Future.wait(
      friendIds.map((id) => FirebaseFirestore.instance.collection('users').doc(id).get()),
    );

    final friends = friendDocs.where((d) => d.exists).toList();

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) {
        final chosen = <String>{};
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Bjud in vänner', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: friends.length,
                      itemBuilder: (_, i) {
                        final f = friends[i];
                        final data = f.data() ?? {};
                        final name = data['username'] ?? data['displayName'] ?? 'Vän';
                        final photo = data['photoUrl'] as String?;
                        final selected = chosen.contains(f.id);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                            child: photo == null || photo.isEmpty ? Text(name[0].toUpperCase()) : null,
                          ),
                          title: Text(name.toString(), style: const TextStyle(color: Colors.white)),
                          trailing: Icon(selected ? Icons.check_circle : Icons.add_circle_outline, color: selected ? Colors.cyan : Colors.white54),
                          onTap: () {
                            setModalState(() {
                              if (selected) chosen.remove(f.id); else chosen.add(f.id);
                            });
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: chosen.isEmpty ? null : () => Navigator.pop(c, chosen.toList()),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                        child: const Text('Lägg till', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected == null || selected.isEmpty) return;

    final updates = <String, dynamic>{};
    for (final id in selected) {
      updates['players.$id'] = true;
    }
    updates['participants'] = FieldValue.arrayUnion(selected);
    updates['events'] = FieldValue.arrayUnion(selected.map((id) => {
      'type': 'add_player',
      'userId': id,
      'time': DateTime.now().toIso8601String(),
    }).toList());

    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update(updates);
    await _loadPlayerDetails();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selected.length} vänner tillagda'), backgroundColor: Colors.cyan),
      );
    }
  }

  Future<void> _addBuyInForPlayer(String playerId, String playerName) async {
    if ((!_hasStarted && !_isPrivate) || _isEnded || _isPaused) return;

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
      'events': FieldValue.arrayUnion([{
        'type': 'cashout',
        'userId': playerId,
        'playerName': playerName,
        'amount': cashoutAmount,
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
    if (!_isOriginalAdmin) return;
    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'players.$uid': FieldValue.delete(),
      'participants': FieldValue.arrayRemove([uid]),
      'events': FieldValue.arrayUnion([{
        'type': 'remove_player',
        'userId': uid,
        'playerName': name,
        'time': DateTime.now().toIso8601String(),
      }]),
    });
    await _loadPlayerDetails();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name borttagen'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _addManualPlayer() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Lägg till spelare', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Namn', hintStyle: TextStyle(color: Colors.white38)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Avbryt')),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Lägg till', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final id = 'manual_${DateTime.now().millisecondsSinceEpoch}';
    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'players.$id': true,
      'manualPlayers': FieldValue.arrayUnion([{'id': id, 'name': name}]),
      'participants': FieldValue.arrayUnion([id]),
      'events': FieldValue.arrayUnion([{
        'type': 'add_player',
        'userId': id,
        'playerName': name,
        'time': DateTime.now().toIso8601String(),
      }]),
    });
    await _loadPlayerDetails();
  }

  Future<void> _togglePause() async {
    final newPaused = !_isPaused;
    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'paused': newPaused,
      'events': FieldValue.arrayUnion([{
        'type': newPaused ? 'pause' : 'resume',
        'time': DateTime.now().toIso8601String(),
      }]),
    });
    await _loadPlayerDetails();
  }

  Future<void> _deleteSession() async {
    if (!_isOriginalAdmin) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Radera session?', style: TextStyle(color: Colors.white)),
        content: const Text('Detta tar bort sessionen för alla.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Avbryt')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Radera', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).delete();
    if (mounted) Navigator.pop(context);
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
      'events': FieldValue.arrayUnion([{
        'type': 'end',
        'time': DateTime.now().toIso8601String(),
      }]),
    });
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SummaryScreen(sessionId: widget.sessionId)));
    }
  }

  Widget _actionButton(IconData icon, Color color, String tooltip, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 22),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  String _formatPlayTime() {
    final h = _playDuration.inHours;
    final m = _playDuration.inMinutes % 60;
    final s = _playDuration.inSeconds % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _eventRow(Map<String, dynamic> e) {
    final type = e['type'] ?? '';
    final name = e['playerName'] ?? '';
    final amount = e['amount'];
    IconData icon = Icons.circle;
    Color color = Colors.white54;
    String label = '';

    if (type == 'buyin') {
      icon = Icons.add_circle_outline;
      color = Colors.cyan;
      label = '$name  ·  ${amount?.toStringAsFixed(0) ?? ''} kr';
    } else if (type == 'rebuy') {
      icon = Icons.refresh;
      color = Colors.cyan;
      label = '$name  ·  ${amount?.toStringAsFixed(0) ?? ''} kr';
    } else if (type == 'cashout') {
      icon = Icons.flag;
      color = Colors.green;
      label = '$name klar';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final started = _hasStarted || _isPrivate;
    final canControl = _isController;

    final relevantEvents = _events.where((e) {
      final t = e['type'];
      return t == 'buyin' || t == 'rebuy' || t == 'cashout';
    }).toList().reversed.toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (canControl && !_isEnded) ...[
            _actionButton(_isPaused ? Icons.play_arrow : Icons.pause, Colors.amber, _isPaused ? 'Fortsätt' : 'Pausa', _togglePause),
            if (_isOriginalAdmin)
              _actionButton(Icons.person_add, Colors.cyan, 'Lägg till spelare', _addPlayer),
            _actionButton(Icons.stop, Colors.red, 'Avsluta session', _endSession),
          ],
          if (_isOriginalAdmin && !_isEnded)
            _actionButton(Icons.delete_outline, Colors.redAccent, 'Radera session', _deleteSession),
          if (_isOriginalAdmin && !_isEnded)
            _actionButton(Icons.swap_horiz, Colors.purpleAccent, 'Ge kontroll', _transferControl),
          _actionButton(Icons.summarize, Colors.cyan, 'Sammanfattning', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => SummaryScreen(sessionId: widget.sessionId)));
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (!_hasStarted && !_isPrivate && _sessionDate != null)
                  CountdownWidget(target: _sessionDate!),
                if (!_hasStarted && !_isPrivate) const SizedBox(height: 16),
                if (started) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_totalPot > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.cyan.withOpacity(0.25), Colors.cyan.withOpacity(0.05)]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.cyan.withOpacity(0.7), width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.3), blurRadius: 14)],
                          ),
                          child: Text(
                            'POTT  ${_totalPot.toStringAsFixed(0)} kr',
                            style: const TextStyle(color: Colors.cyan, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                      if (_timerRunning)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            _formatPlayTime(),
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (_isPaused)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.6)),
                    ),
                    child: const Text('PAUSAD', style: TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                Center(
                  child: PokerTableWidget(
                    playerCount: _playerIds.length,
                    playerIds: _playerIds,
                    playerNames: _playerNames,
                    playerPhotoUrls: _playerPhotoUrls,
                    playerChipValues: _playerChipValues,
                    playerCashoutResults: _playerCashoutResults,
                    isAdmin: canControl && started && !_isEnded && !_isPaused,
                    isEnded: _isEnded,
                    onPlayerTap: canControl && started && !_isEnded && !_isPaused ? (playerId, playerName) {
                      final index = _playerIds.indexOf(playerId);
                      if (index >= 0) {
                        _showPlayerOptions(playerId, playerName, index);
                      }
                    } : null,
                    onContinue: canControl && started && !_isEnded ? (playerId, playerName) async {
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
                const SizedBox(height: 28),
                if (relevantEvents.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('HÄNDELSER', style: TextStyle(color: Colors.cyan, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const SizedBox(height: 12),
                        ...relevantEvents.take(15).map(_eventRow),
                      ],
                    ),
                  ),
                ],
                if (!started && !_isEnded && !_isPrivate)
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
          if (_showStartAnim)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: scale.clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.cyan, width: 2),
                          boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.5), blurRadius: 24)],
                        ),
                        child: const Text(
                          'SPELET STARTAR',
                          style: TextStyle(color: Colors.cyan, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                      ),
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
