import 'package:flutter/material.dart';
import 'package:study_connect_shared/models/group.dart';

// Dialog for editing an existing StudyGroup
// Returns the updated StudyGroup via Navigator.pop(...)
class EditGroupDialog extends StatefulWidget {
  final StudyGroup group;
  const EditGroupDialog({super.key, required this.group});

  @override
  State<EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<EditGroupDialog> {
  // Controllers prefilled with current group values
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _subject;
  // late final TextEditingController _time;
  late final TextEditingController _location;
  late final TextEditingController _tags;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.group.name);
    _description = TextEditingController(text: widget.group.description);
    _subject = TextEditingController(text: widget.group.subject);
    // _time = TextEditingController(text: widget.group.meetingTime);
    _location = TextEditingController(text: widget.group.location);
    _tags = TextEditingController(text: widget.group.tags.join(', '));
  }

  @override
  void dispose() {
    // Clean up controllers to avoid memory leaks
    _name.dispose();
    _description.dispose();
    _subject.dispose();
    // _time.dispose();
    _location.dispose();
    _tags.dispose();
    super.dispose();
  }

  /// Validates inputs, builds an updated StudyGroup, and returns it
  void _save() {
    // Basic required fields check
    if (_name.text.isEmpty ||
        _subject.text.isEmpty ||
        // _time.text.isEmpty ||
        _location.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    // Parse tags (comma-separated → trimmed list)
    final tags = _tags.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Build updated group (preserve id and joined state)
    final g = StudyGroup(
      id: widget.group.id,
      name: _name.text.trim(),
      description: _description.text.trim(),
      subject: _subject.text.trim(),
      // meetingTime: _time.text.trim(),
      location: _location.text.trim(),
      tags: tags,
    );

    Navigator.pop(context, g); // send updated group back to caller
  }

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
                'Edit Group',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Fields
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Group Name *'),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _subject,
                decoration: const InputDecoration(labelText: 'Subject *'),
              ),
              const SizedBox(height: 8),

              // TextField(
              //   controller: _time,
              //   decoration: const InputDecoration(labelText: 'Meeting Time *'),
              // ),
              // const SizedBox(height: 8),

              TextField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location *'),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
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
                    label: const Text('Save'),
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
