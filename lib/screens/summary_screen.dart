import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SummaryScreen extends StatelessWidget {
  final String sessionId;
  const SummaryScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Sammanfattning', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('sessions').doc(sessionId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyan));
          final data = snap.data!.data() as Map<String, dynamic>? ?? {};
          final events = data['events'] as List? ?? [];
          final cashouts = data['cashouts'] as List? ?? [];
          final finishedUids = List<String>.from(data['finishedPlayers'] ?? []);
          final players = data['players'] as Map? ?? {};
          final start = (data['startTime'] as Timestamp?)?.toDate();
          final endedAt = (data['endedAt'] as Timestamp?)?.toDate();

          double total = 0;
          int rebuys = 0;
          final perPlayerBuyIns = <String, double>{};

          for (final e in events) {
            final m = e as Map;
            final amount = (m['amount'] as num?)?.toDouble() ?? 0;
            final name = m['playerName'] ?? 'Okänd';
            total += amount;
            if (m['type'] == 'rebuy') rebuys++;
            perPlayerBuyIns[name] = (perPlayerBuyIns[name] ?? 0) + amount;
          }

          final duration = (start != null && endedAt != null)
              ? endedAt.difference(start)
              : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text('TOTAL POTT', style: TextStyle(color: Colors.white54, letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text('${total.toStringAsFixed(0)} SEK', style: const TextStyle(fontSize: 36, color: Colors.cyan, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat('Buy-ins', '${events.length - rebuys}'),
                        _stat('Rebuys', '$rebuys'),
                        _stat('Spelare', '${players.length}'),
                      ],
                    ),
                    if (duration != null) ...[
                      const SizedBox(height: 12),
                      Text('Speltid: ${_formatDuration(duration)}', style: const TextStyle(color: Colors.white70)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Spelare', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...players.keys.map((uid) {
                final name = _getNameForUid(uid, events, cashouts);
                final buyIns = perPlayerBuyIns[name] ?? 0;
                final cashout = cashouts.cast<Map>().firstWhere(
                  (c) => c['userId'] == uid,
                  orElse: () => {},
                );
                final isFinished = finishedUids.contains(uid);
                final profit = (cashout['profit'] as num?)?.toDouble();

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                            Text('Buy-in: ${buyIns.toStringAsFixed(0)} SEK', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (!isFinished)
                        const Text('Spelar', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))
                      else if (profit != null)
                        Text(
                          profit > 0 ? '+${profit.toStringAsFixed(0)}' : profit.toStringAsFixed(0),
                          style: TextStyle(
                            color: profit > 0 ? Colors.green : (profit < 0 ? Colors.red : Colors.white),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      else
                        const Text('Klar', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              const Text('Alla händelser', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...events.reversed.map((e) {
                final m = e as Map;
                final type = m['type'] == 'rebuy' ? 'Rebuy' : 'Buy-in';
                return ListTile(
                  dense: true,
                  leading: Icon(m['type'] == 'rebuy' ? Icons.refresh : Icons.add_circle, color: Colors.cyan, size: 18),
                  title: Text('$type – ${m['amount']} SEK', style: const TextStyle(color: Colors.white)),
                  subtitle: Text(m['playerName'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  String _getNameForUid(String uid, List events, List cashouts) {
    for (final e in events) {
      if (e['userId'] == uid) return e['playerName'] ?? uid;
    }
    for (final c in cashouts) {
      if (c['userId'] == uid) return c['playerName'] ?? uid;
    }
    return uid;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
