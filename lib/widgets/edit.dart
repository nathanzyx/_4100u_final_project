import 'package:flutter/material.dart';
import 'package:study_connect_shared/models/group.dart';
import '../services/address_convert.dart';

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
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _country;
  late final TextEditingController _tags;

  @override
  void initState() {
    super.initState();

    List<String> locationSegments = widget.group.location.split(",").map((s) => s.trim()).toList();

    _name = TextEditingController(text: widget.group.name);
    _description = TextEditingController(text: widget.group.description);
    _subject = TextEditingController(text: widget.group.subject);
    _address = TextEditingController(text: locationSegments[0]);
    _city = TextEditingController(text: locationSegments[1]);
    
    // Determine whether or not location included province/state (only optional address field)
    if (locationSegments.length > 3) {
      _state = TextEditingController(text: locationSegments[2]);
      _country = TextEditingController(text: locationSegments[3]);
    } else {
      _state = TextEditingController(text: "");
      _country = TextEditingController(text: locationSegments[2]);
    }

    _tags = TextEditingController(text: widget.group.tags.join(', '));
  }

  @override
  void dispose() {
    // Clean up controllers to avoid memory leaks
    _name.dispose();
    _description.dispose();
    _subject.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _country.dispose();
    _tags.dispose();
    super.dispose();
  }

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
              const Text(
                'Edit Group',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

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
