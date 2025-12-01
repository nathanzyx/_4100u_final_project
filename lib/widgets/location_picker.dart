import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

/*
  Standardized location class
*/
class PickedLocation
{
  final LatLng point;
  final String? label;
  const PickedLocation(this.point, {this.label});
}

/// IMPORTANT:
/// Nominatim requires a proper, identifying User-Agent (and ideally a contact).
/// If you spam requests or use a generic UA, you'll often get 403/blocked.
///
/// Replace the email below with a real project contact (school email or repo URL).
const String kNominatimUserAgent = 'StudyConnect/1.0 (https://github.com/nathanzyx/_4100u_final_project)';

Future<String?> reverseGeocodeLabel(LatLng point) async
{
  final uri = Uri.https
  (
    'nominatim.openstreetmap.org',
    '/reverse',
    {
      'lat': point.latitude.toString(),
      'lon': point.longitude.toString(),
      'format': 'jsonv2',
    },
  );

  final response = await http.get
  (
    uri,
    headers: const {
      'User-Agent': kNominatimUserAgent,
      'Accept': 'application/json',
    },
  );

  if (response.statusCode != 200) return null;

  final data = jsonDecode(response.body);
  if (data is Map && data['display_name'] is String)
  {
    return data['display_name'] as String;
  }
  return null;
}

Future<PickedLocation?> showLocationPickerDialog({
  required BuildContext context,
  bool allowCancel = true, // if false, user must pick a location
  bool barrierDismissible = true,
  String title = 'Choose Your Location', // default title of widget
  LatLng? initialCenter,
  double initialZoom = 12,
})
{
  return showDialog<PickedLocation>(
    context: context,
    barrierDismissible: allowCancel,
    builder: (_) => LocationPickerDialog(
      title: title,
      initialCenter: initialCenter,
      initialZoom: initialZoom,
      allowCancel: allowCancel,
    ),
  );
}

class LocationPickerDialog extends StatefulWidget
{
  final String title;
  final LatLng? initialCenter;
  final double initialZoom;
  final bool allowCancel;

  const LocationPickerDialog({
    super.key,
    this.title = 'Choose Your Location',
    this.initialCenter,
    this.initialZoom = 12,
    this.allowCancel = true,
  });

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog>
{
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _selectedLocation;
  String? _selectedLabel;
  late double _zoom;

  @override
  void initState()
  {
    super.initState();
    _zoom = widget.initialZoom;
  }

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  void _cancel() {
    if (!widget.allowCancel) return;
    Navigator.of(context).pop(null);
  }

  Future<void> _searchAddress() async
  {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': query,
          'format': 'json',
          'limit': '1',
        },
      );

      final response = await http.get(
        uri,
        headers: const
        {
          'User-Agent': kNominatimUserAgent,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200)
      {
        throw Exception('Geocoding failed with status ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty)
      {
        final first = data[0];
        final lat = double.parse(first['lat']);
        final lon = double.parse(first['lon']);
        final displayName = (first['display_name'] as String?)?.trim();

        final newLocation = LatLng(lat, lon);

        setState((){
          _selectedLocation = newLocation;
          _selectedLabel = displayName;
          _zoom = 15;
        });

        _mapController.move(newLocation, _zoom);
      } else
      {
        if (mounted)
        {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No results found for that address.')),
          );
        }
      }
    } catch (e)
    {
      if (mounted)
      {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching address: $e')),
        );
      }
    }
  }

  Future<void> _confirm() async
  {
    final p = _selectedLocation;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a location first.')),
      );
      return;
    }

    // If user tapped on map (no label), do a one-time reverse lookup on confirm.
    String? label = _selectedLabel;
    label ??= await reverseGeocodeLabel(p);

    // Always have *something* nice to display.
    label ??= 'Pinned location (${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)})';

    if (!mounted) return;
    Navigator.of(context).pop(PickedLocation(p, label: label));
  }

  @override
  Widget build(BuildContext context)
  {
    final center = widget.initialCenter ?? const LatLng(43.6532, -79.3832); // Toronto fallback

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        height: 450,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Enter address or place…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _searchAddress(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _searchAddress,
                    child: const Icon(Icons.search, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Map
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: _zoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                  onTap: (tapPos, location) {
                    setState(() {
                      _selectedLocation = location;
                      _selectedLabel = null; // tapped point doesn't have a label yet
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png",
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      if (_selectedLocation != null)
                        Marker(
                          point: _selectedLocation!,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_pin,
                            size: 50,
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 5),

            // Bottom row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  // Zoom buttons
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(30, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() => _zoom += 1);
                      _mapController.move(_mapController.camera.center, _zoom);
                    },
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(30, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() => _zoom -= 1);
                      _mapController.move(_mapController.camera.center, _zoom);
                    },
                    child: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 8),

                  // Selected coords
                  Expanded(
                    child: Text(
                      _selectedLocation == null
                          ? 'Tap or search to select a location'
                          : 'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, '
                            'Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // cancel button appears only if allowed
                  if (widget.allowCancel) ...[
                    TextButton(
                      onPressed: _cancel,
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton(
                    onPressed: _confirm,
                    child: const Text("Confirm")
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
