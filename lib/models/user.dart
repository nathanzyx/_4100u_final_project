// Model class representing a single chat message in a study group
class User {
  final int id; // User ID (auto-incremented)
  // String username; // Username of the user -- dormant
  // String password; // Password of the user -- dormant
  final String displayName; // Display name of the user
  final int created; // Account creation timestamp


  User({
    required this.id,
    required this.displayName,
    required this.created,
  });

  // Converts this object to a Map for storing in the database
  Map<String, Object?> toMap() => {
    'id': id,
    'displayName': displayName,
    'created': int,
  };

  // Recreates a User object from a map
  factory User.fromMap(Map<String, Object?> m) => User(
    id: m['id'] as int,
    displayName: m['displayName'] as String,
    created: m['created'] as int,
  );
}
