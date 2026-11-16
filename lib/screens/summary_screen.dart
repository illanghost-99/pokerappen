import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
          int buyins = 0;
          final perPlayerBuyIns = <String, double>{};
          final perPlayerRebuys = <String, int>{};

          for (final e in events) {
            final m = e as Map;
            final amount = (m['amount'] as num?)?.toDouble() ?? 0;
            final name = m['playerName'] ?? 'Okänd';
            total += amount;
            if (m['type'] == 'rebuy') {
              rebuys++;
              perPlayerRebuys[name] = (perPlayerRebuys[name] ?? 0) + 1;
            } else {
              buyins++;
            }
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
                  gradient: LinearGradient(
                    colors: [Colors.cyan.withOpacity(0.15), Colors.black],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyan.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    const Text('TOTAL POTT', style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('${total.toStringAsFixed(0)} SEK', style: const TextStyle(fontSize: 40, color: Colors.cyan, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat('Buy-ins', '$buyins'),
                        _stat('Rebuys', '$rebuys'),
                        _stat('Spelare', '${players.length}'),
                      ],
                    ),
                    if (duration != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.cyan, size: 18),
                          const SizedBox(width: 6),
                          Text('Speltid: ${_formatDuration(duration)}', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text('Spelare', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...players.keys.map((uid) {
                final name = _getNameForUid(uid, events, cashouts);
                final buyIns = perPlayerBuyIns[name] ?? 0;
                final rebuyCount = perPlayerRebuys[name] ?? 0;
                final cashout = cashouts.cast<Map>().firstWhere(
                  (c) => c['userId'] == uid,
                  orElse: () => {},
                );
                final isFinished = finishedUids.contains(uid);
                final profit = (cashout['profit'] as num?)?.toDouble();

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Totalt in: ${buyIns.toStringAsFixed(0)} SEK  •  $rebuyCount rebuy${rebuyCount == 1 ? '' : 's'}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (!isFinished)
                        const Text('Spelar', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))
                      else if (profit != null)
                        Text(
                          profit > 0 ? '+${profit.toStringAsFixed(0)}' : profit.toStringAsFixed(0),
                          style: TextStyle(
                            color: profit > 0 ? Colors.greenAccent : (profit < 0 ? Colors.redAccent : Colors.white),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      else
                        const Text('Klar', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 28),
              const Text('Tidslinje', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...events.reversed.map((e) {
                final m = e as Map;
                final type = m['type'] == 'rebuy' ? 'Rebuy' : 'Buy-in';
                final timeStr = m['time'] as String?;
                String timeDisplay = '';
                if (timeStr != null) {
                  final t = DateTime.tryParse(timeStr);
                  if (t != null) {
                    timeDisplay = DateFormat('d MMM HH:mm').format(t);
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(m['type'] == 'rebuy' ? Icons.refresh : Icons.add_circle_outline, color: Colors.cyan, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$type  ${m['amount']} SEK', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                            Text(m['playerName'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (timeDisplay.isNotEmpty)
                        Text(timeDisplay, style: const TextStyle(color: Colors.white38, fontSize: 13)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 32),
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
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
