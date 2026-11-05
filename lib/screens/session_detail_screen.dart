import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionDetailScreen extends StatelessWidget {
  final String sessionId;
  final Map<String, dynamic> data;

  const SessionDetailScreen({super.key, required this.sessionId, required this.data});

  @override
  Widget build(BuildContext context) {
    final start = (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(data['name'] ?? 'Session')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adress: ${data['address'] ?? ''}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            const Text('Countdown', style: TextStyle(fontSize: 20, color: Colors.cyan)),
            Text(start.toString()),
            const SizedBox(height: 20),
            const Text('Pott & Spelare', style: TextStyle(fontSize: 20)),
            const Expanded(child: Center(child: Text('Pokerbord-vy kommer här'))),
          ],
        ),
      ),
    );
  }
}
