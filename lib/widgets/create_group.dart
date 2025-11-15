import 'package:flutter/material.dart';
import 'package:study_connect_shared/models/group.dart';

// Dialog for creating a new StudyGroup
// Appears as a popup form where users can enter group details
class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  // Controllers for form fields
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _subject = TextEditingController();
  // final _time = TextEditingController();
  final _location = TextEditingController();
  final _tags = TextEditingController();

  /// Validates input and saves the new StudyGroup
  void _save() {
    // Ensure required fields are filled
    if (_name.text.isEmpty ||
        _subject.text.isEmpty ||
        // _time.text.isEmpty ||
        _location.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    // Split comma-separated tags into a clean list
    final tags = _tags.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Create a new StudyGroup object
    final g = StudyGroup(
      name: _name.text.trim(),
      description: _description.text.trim(),
      subject: _subject.text.trim(),
      location: _location.text.trim(),
      tags: tags,
    );

    // Return the created group to the parent widget
    Navigator.pop(context, g);
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
                'Create New Group',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Input fields for group info
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Group Name *'),
              ),
              const SizedBox(height: 8),

              // Input fields for group info
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
              //   decoration: const InputDecoration(
              //     labelText: 'Meeting Time *',
              //     hintText: 'e.g., Tuesdays 6:00 PM',
              //   ),
              // ),
              // const SizedBox(height: 8),

              TextField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  hintText: 'e.g., 2000 Simcoe St. N',
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                  hintText: 'Math, Calculus',
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons
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
