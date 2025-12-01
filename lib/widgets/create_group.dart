import 'package:flutter/material.dart';
import 'package:study_connect_shared/models/group.dart';
import '../services/address_convert.dart';

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
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _country = TextEditingController();
  final _tags = TextEditingController();

  /// Validates input and saves the new StudyGroup
  void _save() async {
    // Ensure required fields are filled
    if (_name.text.isEmpty ||
        _subject.text.isEmpty ||
        // _time.text.isEmpty ||
        _address.text.isEmpty ||
        _city.text.isEmpty ||
        _country.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    // Combine address fields
    String fullAddress = [
      _address.text.trim(),
      _city.text.trim(),
      _state.text.trim(),
      _country.text.trim()
    ].where((s) => s.isNotEmpty).join(", ");

    // Convert address to coordinates
    Map<String, double>? coordinates = await AddressConvert.addressToCoordinates(fullAddress);

    double latitude;
    double longitude;
    if (coordinates != null) {
      latitude = coordinates['latitude']!;
      longitude = coordinates['longitude']!;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid address')),
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
      location: fullAddress,
      latitude: latitude,
      longitude: longitude,
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

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _address,
                      decoration: const InputDecoration(
                        labelText: 'Address *',
                        hintText: 'e.g., 2000 Simcoe St N',
                        hintStyle: TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _city,
                      decoration: const InputDecoration(
                        labelText: 'City *',
                        hintText: 'e.g., Oshawa',
                      ),
                    ),
                  ),
                ],
              ),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _state,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        hintText: 'e.g., Ontario',
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _country,
                      decoration: const InputDecoration(
                        labelText: 'Country *',
                        hintText: 'e.g., Canada',
                      ),
                    ),
                  ),
                ],
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
