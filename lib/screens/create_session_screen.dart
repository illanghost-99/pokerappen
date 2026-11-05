import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  String _currency = 'SEK';
  String _type = 'Cash Game';
  DateTime _date = DateTime.now();

  Future<void> _create() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _nameController.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('sessions').add({
      'name': _nameController.text,
      'address': _addressController.text,
      'currency': _currency,
      'type': _type,
      'startTime': Timestamp.fromDate(_date),
      'ownerId': uid,
      'players': {uid: 'admin'},
      'buyIns': [],
      'events': [],
      'status': 'upcoming',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ny pokersession')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Namn')),
            TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Adress')),
            DropdownButton<String>(
              value: _currency,
              items: ['SEK', 'EUR', 'USD'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _currency = v!),
            ),
            DropdownButton<String>(
              value: _type,
              items: ['Cash Game', 'Turnering'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            ElevatedButton(onPressed: _create, child: const Text('Skapa')),
          ],
        ),
      ),
    );
  }
}
