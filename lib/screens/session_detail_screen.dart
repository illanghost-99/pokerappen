import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/poker_table_widget.dart';
import 'summary_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic> data;
  const SessionDetailScreen({super.key, required this.sessionId, required this.data});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  String _type = 'buyin';
  bool _isDeleting = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _addTransaction() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'buyIns': FieldValue.arrayUnion([{'userId': uid, 'amount': amount, 'timestamp': DateTime.now().toIso8601String(), 'type': _type}]),
      'events': FieldValue.arrayUnion([{'type': _type, 'userId': uid, 'amount': amount, 'time': DateTime.now().toIso8601String()}]),
    });
    _amountController.clear();
  }

  Future<void> _deleteSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Radera session?', style: TextStyle(color: Colors.white)),
        content: const Text('Sessionen tas bort permanent och försvinner för alla.', style: TextStyle(color: Colors.white70)),
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

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    await _animController.forward();

    try {
      await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isDeleting = false);
      _animController.reverse();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fel: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = (widget.data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isAdmin = widget.data['ownerId'] == FirebaseAuth.instance.currentUser?.uid;
    final players = (widget.data['players'] as Map?)?.keys.toList() ?? [];

    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(widget.data['name'] ?? 'Session', style: const TextStyle(color: Colors.white)),
          actions: [
            if (isAdmin && !_isDeleting) ...[
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
              const SizedBox(height: 16),
              CountdownWidget(target: start),
              const SizedBox(height: 16),
              PokerTableWidget(playerCount: players.length, playerNames: players.cast<String>()),
              const SizedBox(height: 24),
              if (isAdmin) ...[
                const Text('Lägg till inköp / rebuy', style: TextStyle(fontSize: 16, color: Colors.white)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Belopp',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF1A1A1A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _type,
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'buyin', child: Text('Buy-in')),
                        DropdownMenuItem(value: 'rebuy', child: Text('Rebuy')),
                      ],
                      onChanged: (v) => setState(() => _type = v!),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addTransaction,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                      child: const Text('Lägg till', style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text('Tidslinje', style: TextStyle(fontSize: 18, color: Colors.white)),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData || !snap.data!.exists) {
                    return const Text('Sessionen finns inte längre', style: TextStyle(color: Colors.white38));
                  }
                  final events = (snap.data!.data() as Map<String, dynamic>?)?['events'] as List? ?? [];
                  if (events.isEmpty) return const Text('Inga händelser ännu', style: TextStyle(color: Colors.white38));
                  return Column(
                    children: events.map<Widget>((e) {
                      final m = e as Map;
                      return ListTile(
                        leading: Icon(m['type'] == 'rebuy' ? Icons.refresh : Icons.add_circle, color: Colors.cyan, size: 20),
                        title: Text('${m['type']?.toString().toUpperCase()} – ${m['amount'] ?? ''}', style: const TextStyle(color: Colors.white)),
                        subtitle: Text(m['time'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
