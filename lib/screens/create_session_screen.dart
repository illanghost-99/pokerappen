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

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (time == null || !mounted) return;
    setState(() {
      _date = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _create() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fyll i namn')));
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('sessions').add({
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
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

    if (!mounted) return;

    final invite = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Bjud in vänner?', style: TextStyle(color: Colors.white)),
        content: const Text('Vill du bjuda in vänner till sessionen nu?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Senare')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ja, bjud in')),
        ],
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Skapa pokersession', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text('Namn på kvällen', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 't.ex. Fredagspoker',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Adress', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _addressController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Var spelar ni?',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Datum och tid', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.calendar_today, color: Colors.cyan),
              label: Text(
                '${_date.day}/${_date.month} ${_date.hour}:${_date.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.cyan),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _currency,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Valuta',
                labelStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Color(0xFF1A1A1A),
              ),
              items: ['SEK', 'EUR', 'USD'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _currency = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _type,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Typ',
                labelStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Color(0xFF1A1A1A),
              ),
              items: ['Cash Game', 'Turnering'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Skapa session', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
