import 'package:flutter/material.dart';

/// Simple data object we return from the dialog.
/// GroupDetailsPage uses this to show the session.
class SessionInfo {
  final String title;
  final String? location;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final int? maxAttendees;
  final String? description;

  SessionInfo({
    required this.title,
    this.location,
    this.startDateTime,
    this.endDateTime,
    this.maxAttendees,
    this.description,
  });
}

/// Dialog to create a new study session for a group.
class CreateSessionDialog extends StatefulWidget {
  const CreateSessionDialog({super.key});

  @override
  State<CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends State<CreateSessionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _maxAttendeesCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  DateTime? _pickedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int? _maxAttendees;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _maxAttendeesCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final wd = weekdays[d.weekday - 1];
    final m = months[d.month - 1];
    return '$wd, $m ${d.day}, ${d.year}';
  }

  DateTime _combine(DateTime date, TimeOfDay tod) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      tod.hour,
      tod.minute,
    );
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? today,
      firstDate: today.subtract(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (result != null) {
      setState(() => _pickedDate = result);
    }
  }

  Future<void> _pickStartTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (result != null) {
      setState(() => _startTime = result);
    }
  }

  Future<void> _pickEndTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _endTime ?? (_startTime ?? TimeOfDay.now()),
    );
    if (result != null) {
      setState(() => _endTime = result);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    DateTime? start;
    DateTime? end;

    if (_pickedDate != null && _startTime != null) {
      start = _combine(_pickedDate!, _startTime!);
    }
    if (_pickedDate != null && _endTime != null) {
      end = _combine(_pickedDate!, _endTime!);
    }

    final maxText = _maxAttendeesCtrl.text.trim();
    if (maxText.isNotEmpty)
    {
      _maxAttendees = int.tryParse(maxText);
    }
    else
    {
      _maxAttendees = null;
    }

    final info = SessionInfo(
      title: _titleCtrl.text.trim(),
      location: _locationCtrl.text.trim().isEmpty
          ? null
          : _locationCtrl.text.trim(),
      startDateTime: start,
      endDateTime: end,
      maxAttendees: _maxAttendees,
      description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
    );

    Navigator.of(context).pop(info);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create session'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Session title
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Session title',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Location / room
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Location (e.g. building, floor, room)',
                ),
              ),
              const SizedBox(height: 16),


              // Max Atendees
              TextFormField(
                controller: _maxAttendeesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Maximum Attendees',
                ),
              ),
              const SizedBox(height: 16),

              // Date button – full width
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _pickedDate == null
                      ? 'Pick date'
                      : _formatDate(_pickedDate!),
                ),
              ),
              const SizedBox(height: 8),

              // Start / End time aligned in one row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStartTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        _startTime == null
                            ? 'Start time'
                            : _startTime!.format(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEndTime,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(
                        _endTime == null
                            ? 'End time'
                            : _endTime!.format(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
