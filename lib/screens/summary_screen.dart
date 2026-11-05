import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SummaryScreen extends StatelessWidget {
  final String sessionId;
  const SummaryScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sammanfattning')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('sessions').doc(sessionId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!.data() as Map<String, dynamic>? ?? {};
          final buyIns = data['buyIns'] as List? ?? [];
          final total = buyIns.fold<double>(0, (sum, b) => sum + ((b as Map)['amount'] as num? ?? 0));

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total pott: $total ${data['currency'] ?? ''}', style: const TextStyle(fontSize: 22, color: Colors.cyan)),
                const SizedBox(height: 12),
                Text('Antal buy-ins: ${buyIns.length}'),
                const SizedBox(height: 12),
                const Text('Tidslinje', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: ListView.builder(
                    itemCount: buyIns.length,
                    itemBuilder: (_, i) {
                      final b = buyIns[i] as Map;
                      return ListTile(title: Text('${b['amount']} – ${b['userId']}'));
                    },
                  ),
                ),
                ElevatedButton(onPressed: () {}, child: const Text('Exportera PDF')),
              ],
            ),
          );
        },
      ),
    );
  }
}
