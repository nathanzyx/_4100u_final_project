import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

// Location picker dialog
class LocationPickerDialog extends StatefulWidget {
  const LocationPickerDialog({super.key});

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _selectedLocation;
  double _zoom = 12;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchAddress() async {
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
      headers: {
        // IMPORTANT: must be a real app name + real contact
        // Use your actual school email or GitHub repo URL here.
        'User-Agent': 'StudyConnect/1.0 (nathan.tandory@ontariotechu.ca)',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Geocoding failed with status ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data is List && data.isNotEmpty) {
      final first = data[0];
      final lat = double.parse(first['lat']);
      final lon = double.parse(first['lon']);
      final newLocation = LatLng(lat, lon);

      setState(() {
        _selectedLocation = newLocation;
        _zoom = 15;
      });

      _mapController.move(newLocation, _zoom);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No results found for that address.')),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching address: $e')),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        height: 450,
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              "Choose Your Location",
              style: TextStyle(
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
                  initialCenter:
                      const LatLng(43.6532, -79.3832), // Default: Toronto
                  initialZoom: _zoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                  onTap: (tapPos, location) {
                    setState(() {
                      _selectedLocation = location;
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

            // Bottom row: selected coords + zoom + confirm
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
                      _mapController.move(
                          _mapController.camera.center, _zoom);
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
                      _mapController.move(
                          _mapController.camera.center, _zoom);
                    },
                    child: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 8),

                  // Show coords (shortened)
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

                  // Confirm button
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_selectedLocation),
                    child: const Text("Confirm"),
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