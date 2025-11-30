import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Location picker dialog
class LocationPickerDialog extends StatefulWidget {
  const LocationPickerDialog({super.key});

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final MapController _mapController = MapController();

  LatLng? _selectedLocation;
  double _zoom = 12;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(20),
      child: SizedBox(
        height: 400,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "Choose Your Location",
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            ),
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(43.6532, -79.3832),    // Default location (Toronto)
                  initialZoom: _zoom,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all,    // Enables all interaction options
                  ),
                  onTap: (tapPos, location) {
                    setState(() {
                      _selectedLocation = location;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png",
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      if (_selectedLocation != null)
                        Marker(
                          point: _selectedLocation!, 
                          child: const Icon(
                            Icons.location_pin,
                            size: 50,
                            color: Colors.red,
                          )
                        ),
                    ]
                  )
                ],
              ),
            ),
            SizedBox(height: 5),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Zoom buttons
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: CircleBorder(),
                      padding: EdgeInsets.all(6),
                      minimumSize: Size(30, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Icon(Icons.add),
                    onPressed: () {
                      setState(() => _zoom += 1);
                      _mapController.move(_mapController.camera.center, _zoom);
                    },
                  ),
                  SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: CircleBorder(),
                      padding: EdgeInsets.all(6),
                      minimumSize: Size(30, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Icon(Icons.remove),
                    onPressed: () {
                      setState(() => _zoom -= 1);
                      _mapController.move(_mapController.camera.center, _zoom);
                    },
                  ),
                  Spacer(),   // Pushes button to the right

                  // Confirm button
                  ElevatedButton(
                    child: Text("Confirm"),
                    onPressed: () => Navigator.of(context).pop(_selectedLocation),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}