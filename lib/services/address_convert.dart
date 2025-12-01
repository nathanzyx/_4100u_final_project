import 'package:http/http.dart' as http;
import 'dart:convert';

class AddressConvert {
  // Converts an address to latitude and longitude coordinates
  static Future<Map<String, double>?> addressToCoordinates(String address) async {
    try {
      final url = Uri.parse(
        "https://nominatim.openstreetmap.org/search?"
        "q=$address&format=json&limit=1"
      );

      final response = await http.get(url, headers: {
        "User-Agent": "StudyConnectApp/1.0" // User-Agent required by Nominatim
      });

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isEmpty) return null;

        final latitude = double.parse(data[0]["lat"]);
        final longitude = double.parse(data[0]["lon"]);
        final coordsMap = <String, double>{};

        coordsMap['latitude'] = latitude;
        coordsMap['longitude'] = longitude;

        return coordsMap;
      } else {
        
      }
      return null;
    } catch (e) {
      throw Exception("Address could not be converted.");
    }
  }
}