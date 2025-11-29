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
  LatLng? selectedLocation;

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
                options: MapOptions(
                  initialCenter: LatLng(43.6532, -79.3832),
                  initialZoom: 12,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all,    // Enables all interaction options
                  ),
                  onTap: (tapPos, location) {
                    setState(() {
                      selectedLocation = location;
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
                      if (selectedLocation != null)
                        Marker(
                          point: selectedLocation!, 
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
            ElevatedButton(
              child: Text("Confirm"),
              onPressed: () => Navigator.of(context).pop(selectedLocation),
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}