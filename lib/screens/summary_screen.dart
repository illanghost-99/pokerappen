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
          final buyIns = data['buyIns'] as List? ?? [];
          final total = buyIns.fold<double>(0, (sum, b) => sum + ((b as Map)['amount'] as num? ?? 0));
          final rebuys = buyIns.where((b) => (b as Map)['type'] == 'rebuy').length;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text('Total pott', style: TextStyle(color: Colors.white54)),
                      Text('$total ${data['currency'] ?? ''}', style: const TextStyle(fontSize: 32, color: Colors.cyan, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _stat('Buy-ins', '${buyIns.length - rebuys}'),
                          _stat('Rebuys', '$rebuys'),
                          _stat('Spelare', '${(data['players'] as Map?)?.length ?? 0}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Alla inköp', style: TextStyle(fontSize: 18, color: Colors.white)),
                Expanded(
                  child: ListView.builder(
                    itemCount: buyIns.length,
                    itemBuilder: (_, i) {
                      final b = buyIns[i] as Map;
                      return ListTile(
                        title: Text('${b['amount']} • ${b['type']}', style: const TextStyle(color: Colors.white)),
                        subtitle: Text(b['userId']?.toString() ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: () {}, child: const Text('PDF'))),
                    const SizedBox(width: 8),
                    Expanded(child: ElevatedButton(onPressed: () {}, child: const Text('CSV'))),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
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
