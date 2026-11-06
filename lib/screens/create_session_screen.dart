import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  String _currency = 'SEK';
  String _type = 'Cash Game';
  bool _isCreating = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('sv', 'SE'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _create() async {
    if (_isCreating) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Du är inte inloggad')));
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ange ett namn på sessionen')));
      return;
    }

    setState(() => _isCreating = true);

    try {
      final start = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await FirebaseFirestore.instance.collection('sessions').add({
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'currency': _currency,
        'type': _type,
        'startTime': Timestamp.fromDate(start),
        'ownerId': uid,
        'players': {uid: true},
        'buyIns': [],
        'events': [],
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      // Show success and go back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session skapad!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fel: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE d MMMM y', 'sv');
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Skapa session', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Namn på session',
                labelStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Adress',
                labelStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Datum', style: TextStyle(color: Colors.white70)),
              subtitle: Text(dateFormat.format(_selectedDate), style: const TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.calendar_today, color: Colors.cyan),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Starttid', style: TextStyle(color: Colors.white70)),
              subtitle: Text(timeFormat.format(DateTime(0, 0, 0, _selectedTime.hour, _selectedTime.minute)), style: const TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.access_time, color: Colors.cyan),
              onTap: _pickTime,
            ),
            const SizedBox(height: 16),
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
              items: const [
                DropdownMenuItem(value: 'SEK', child: Text('SEK')),
                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                DropdownMenuItem(value: 'USD', child: Text('USD')),
              ],
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
              items: const [
                DropdownMenuItem(value: 'Cash Game', child: Text('Cash Game')),
                DropdownMenuItem(value: 'Turnering', child: Text('Turnering')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isCreating
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Skapa session', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
