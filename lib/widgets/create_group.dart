import 'package:flutter/material.dart';
import 'package:study_connect_shared/models/group.dart';
import 'package:latlong2/latlong.dart';
import '../services/client/client_services.dart';
import 'location_picker.dart';


enum _LocationMode { myLocation, pickOnMap }

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
  final _tags = TextEditingController();

  _LocationMode _locationMode = _LocationMode.myLocation; // default
  PickedLocation? _pickedLocation;

  bool _gettingLocation = false;

  // to initially grab the users location for the group location
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_locationMode == _LocationMode.myLocation && _pickedLocation == null) {
        _useMyLocation();
      }
    });
  }

  /*
    Helper for locations
  */
  Future<void> _useMyLocation() async {
    setState(() => _gettingLocation = true);

    try {
      final cs = ClientService();

      // Make sure currentUser is loaded (in case dialog is opened early)
      final u = cs.currentUser ?? await cs.ensureUser();

      final point = LatLng(u.latitude, u.longitude);

      // If you used 0,0 as “unset”, guard it
      if (point.latitude == 0.0 && point.longitude == 0.0) {
        throw Exception('Your profile location is not set yet.');
      }

      final label = await reverseGeocodeLabel(point) ?? 'My profile location';

      if (!mounted) return;
      setState(() {
        _locationMode = _LocationMode.myLocation;
        _pickedLocation = PickedLocation(point, label: label);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not use saved profile location: $e')),
      );
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _pickOnMap() async {
    LatLng? initialCenter = _pickedLocation?.point;

    final u = ClientService().currentUser;
    initialCenter ??= (u == null) ? null : LatLng(u.latitude, u.longitude);

    final picked = await showLocationPickerDialog(
      context: context,
      barrierDismissible: false,
      title: 'Choose your location',
    );

    if (picked == null || !mounted) return;
    setState(() {
      _locationMode = _LocationMode.pickOnMap;
      _pickedLocation = picked;
    });
  }

  void _clearLocation() {
    setState(() => _pickedLocation = null);
  }



  // Validates input and saves the new StudyGroup
  void _save() async {
    // Ensure required fields are filled
    if (_name.text.trim().isEmpty || _subject.text.trim().isEmpty)
    {
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

    if (_pickedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a location for the group.')),
      );
      return;
    }
    final p = _pickedLocation!;
    final g = StudyGroup(
      name: _name.text.trim(),
      description: _description.text.trim(),
      subject: _subject.text.trim(),
      location: (p.label ?? 'Pinned location').trim(),
      latitude: p.point.latitude,
      longitude: p.point.longitude,
      tags: tags,
    );

    // Return the created group to the parent widget
    Navigator.pop(context, g);
  }

  @override
  Widget build(BuildContext context) {
    final p = _pickedLocation;
    final locationPreview = (p == null)
        ? 'No location selected'
        : '${(p.label ?? 'Pinned location')}\n'
          '(${p.point.latitude.toStringAsFixed(5)}, ${p.point.longitude.toStringAsFixed(5)})';

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Text(
                'Create a Study Group',
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

              // Location picker (new)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Location *',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),

              SegmentedButton<_LocationMode>(
                segments: const [
                  ButtonSegment(
                    value: _LocationMode.myLocation,
                    label: Text('Use my location'),
                    icon: Icon(Icons.my_location),
                  ),
                  ButtonSegment(
                    value: _LocationMode.pickOnMap,
                    label: Text('Pick on map'),
                    icon: Icon(Icons.map),
                  ),
                ],
                selected: {_locationMode},
                onSelectionChanged: (s) async {
                  final mode = s.first;

                  // Optimistically update the UI selection
                  setState(() => _locationMode = mode);

                  if (mode == _LocationMode.myLocation) {
                    await _useMyLocation();
                    return;
                  }

                  // mode == pickOnMap
                  await _pickOnMap();

                  // if user cancels the map picker, revert to user location
                  if (!mounted) return;
                  if (_pickedLocation == null) {
                    setState(() => _locationMode = _LocationMode.myLocation);
                    await _useMyLocation();
                  }
                },
              ),
              const SizedBox(height: 10),
              if (_locationMode == _LocationMode.myLocation) 
                Text(
                  'Using your saved profile location.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      locationPreview,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                  hintText: 'Math, Calculus',
                ),
              ),
              const SizedBox(height: 12),

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
