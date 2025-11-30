// Model class representing a single chat message in a study group
class User {
  final int id; // User ID (auto-incremented)
  final String displayName; // Display name of the user
  final String username;
  final String password;
  final String authToken;
  final double latitude;
  final double longitude;
  final int created; // Account creation timestamp

  User({
    required this.id,
    required this.displayName,
    required this.username,
    required this.password,
    required this.authToken,
    required this.latitude,
    required this.longitude,
    required this.created,
  });

  // Converts this object to a Map for storing in the database
  Map<String, Object?> toMap() => {
    'id': id,
    'displayName': displayName,
    'username': username,
    'password': password,
    'authToken': authToken,
    'latitude': latitude,
    'longitude': longitude,
    'created': created,
  };

  // Recreates a User object from a map
  factory User.fromMap(Map<String, Object?> m) => User(
    id: m['id'] as int,
    displayName: m['displayName'] as String,
    username: m['username'] as String,
    password: m['password'] as String,
    authToken: m['authToken'] as String,
    latitude: m['latitude'] as double,
    longitude: m['longitude'] as double,
    created: m['created'] as int,
  );
}
