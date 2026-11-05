import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/countdown_widget.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic> data;
  const SessionDetailScreen({super.key, required this.sessionId, required this.data});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _amountController = TextEditingController();

  Future<void> _addBuyIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'buyIns': FieldValue.arrayUnion([
        {
          'userId': uid,
          'amount': amount,
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'buyin',
        }
      ]),
      'events': FieldValue.arrayUnion([
        {
          'type': 'buyin',
          'userId': uid,
          'amount': amount,
          'time': DateTime.now().toIso8601String(),
        }
      ]),
    });
    _amountController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final start = (widget.data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isAdmin = widget.data['ownerId'] == FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(widget.data['name'] ?? 'Session')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.data['address'] ?? '', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            CountdownWidget(target: start),
            const SizedBox(height: 24),
            const Text('Pokerbord', style: TextStyle(fontSize: 20, color: Colors.cyan)),
            Container(
              height: 180,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green[900],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyan, width: 2),
              ),
              child: const Center(child: Text('3D-bord kommer här', style: TextStyle(color: Colors.white70))),
            ),
            if (isAdmin) ...[
              const Text('Lägg till buy-in', style: TextStyle(fontSize: 16)),
              Row(
                children: [
                  Expanded(child: TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Belopp'))),
                  ElevatedButton(onPressed: _addBuyIn, child: const Text('Lägg till')),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text('Tidslinje', style: TextStyle(fontSize: 18)),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox();
                  final events = (snap.data!.data() as Map<String, dynamic>?)?['events'] as List? ?? [];
                  return ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (_, i) {
                      final e = events[i] as Map;
                      return ListTile(
                        leading: const Icon(Icons.circle, size: 8, color: Colors.cyan),
                        title: Text('${e['type']} – ${e['amount'] ?? ''}'),
                        subtitle: Text(e['time'] ?? ''),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
