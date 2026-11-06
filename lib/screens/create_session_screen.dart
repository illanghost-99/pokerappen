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
  DateTime _date = DateTime.now().add(const Duration(hours: 1));

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Ny pokersession', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Namn på session',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyan)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Adress',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyan)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currency,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Valuta', labelStyle: TextStyle(color: Colors.white54)),
              items: ['SEK', 'EUR', 'USD'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _currency = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _type,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Typ', labelStyle: TextStyle(color: Colors.white54)),
              items: ['Cash Game', 'Turnering'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Skapa session', style: TextStyle(color: Colors.black, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
