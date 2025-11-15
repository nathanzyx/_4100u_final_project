import 'package:flutter/material.dart';
import 'package:study_connect_shared/models/session.dart';

// Dialog for creating a new StudySession
// - Collects title, date, start/end times, location, and capacity
// - Returns a StudySession to the caller via Navigator.pop(...)
class CreateSessionDialog extends StatefulWidget {
  final int groupId;
  const CreateSessionDialog({super.key, required this.groupId});

  @override
  State<CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends State<CreateSessionDialog> {
  // Text controllers for inputs
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _max = TextEditingController(text: '12');

  // Date/Time selections (picked with material pickers)
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;

  // ----------------------- pickers -----------------------

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (t != null) setState(() => _start = t);
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
    );
    if (t != null) setState(() => _end = t);
  }

  // ----------------------- helpers -----------------------

  /// Combines selected date and time into a DateTime
  DateTime _merge(DateTime d, TimeOfDay t) =>
      DateTime(d.year, d.month, d.day, t.hour, t.minute);

  /// Formats the chosen date as YYYY-MM-DD for the button label
  String _dateLabel() => _date == null
      ? 'Select date *'
      : _date!.toLocal().toString().split(' ').first;

  /// Returns a label for a time button, or placeholder if null
  String _timeLabel(TimeOfDay? t, String placeholder) =>
      t == null ? placeholder : t.format(context);

  // ----------------------- save -----------------------

  void _save() {
    // Basic required-field validation
    if (_title.text.isEmpty ||
        _date == null ||
        _start == null ||
        _end == null ||
        _location.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    // Construct start/end DateTime from date + time
    final start = _merge(_date!, _start!);
    final end = _merge(_date!, _end!);

    // Ensure end is after start (simple sanity check)
    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    // Parse capacity (fallback to 12 if invalid)
    final capacity = int.tryParse(_max.text.trim()) ?? 12;

    // Build the StudySession and return it to the caller
    final s = StudySession(
      groupId: widget.groupId,
      title: _title.text.trim(),
      start: start,
      end: end,
      location: _location.text.trim(),
      maxAttendees: capacity,
    );
    Navigator.pop(context, s);
  }

  // ----------------------- UI -----------------------

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Text(
                'Create New Study Session',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Session title
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Session Title *'),
              ),
              const SizedBox(height: 8),

              // Date picker
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event),
                      label: Text(_dateLabel()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Start/End time pickers
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStart,
                      icon: const Icon(Icons.schedule),
                      label: Text(_timeLabel(_start, 'Start time *')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEnd,
                      icon: const Icon(Icons.schedule),
                      label: Text(_timeLabel(_end, 'End time *')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Location + capacity
              TextField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  hintText: 'e.g., Library Room 204',
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _max,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum Attendees',
                ),
              ),
              const SizedBox(height: 12),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: const Text('Create Session'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
