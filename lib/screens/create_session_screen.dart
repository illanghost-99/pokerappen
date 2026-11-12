import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';

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
  bool _isPrivate = false;
  bool _creating = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    if (_creating) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inte inloggad')));
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ange ett namn')));
      return;
    }

    setState(() => _creating = true);

    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      final sessionData = {
        'name': _nameController.text.trim(),
        'currency': _currency,
        'type': _type,
        'ownerId': uid,
        'players': {uid: true},
        'participants': [uid],
        'buyIns': [],
        'events': [],
        'createdAt': FieldValue.serverTimestamp(),
        'isPrivate': _isPrivate,
      };

      if (!_isPrivate) {
        sessionData['address'] = _addressController.text.trim();
        sessionData['startTime'] = Timestamp.fromDate(start);
      }

      final ref = await FirebaseFirestore.instance.collection('sessions').add(sessionData);

      // Mirror to Supabase only for online sessions
      if (!_isPrivate) {
        try {
          await Supabase.instance.client.from('sessions_reminders').upsert({
            'id': ref.id,
            'name': _nameController.text.trim(),
            'start_time': start.toIso8601String(),
            'owner_id': uid,
            'participants': [uid],
            'reminders_sent': [],
          });
        } catch (e) {
          debugPrint('Failed to mirror session to Supabase: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Create session error: $e');
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kunde inte skapa session'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE d MMMM y');
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
            // Session type selector
            const Text('Typ av session', style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Online'),
                    selected: !_isPrivate,
                    onSelected: (_) => setState(() => _isPrivate = false),
                    selectedColor: Colors.cyan,
                    labelStyle: TextStyle(color: !_isPrivate ? Colors.black : Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Privat'),
                    selected: _isPrivate,
                    onSelected: (_) => setState(() => _isPrivate = true),
                    selectedColor: Colors.cyan,
                    labelStyle: TextStyle(color: _isPrivate ? Colors.black : Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isPrivate
                  ? 'Privat session: Endast du ser den. Du lägger till spelare manuellt med namn.'
                  : 'Online session: Bjud in vänner via appen.',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),

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

            if (!_isPrivate) ...[
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
            ],

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
                onPressed: _creating ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _creating
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
