// Model class representing a study group (community of students)
class StudyGroup {
  final int? id;                // Database ID (auto-incremented)
  final String name;            // Name of the study group
  final String description;     // Description of the study group
  final String subject;         // Subject or topic focus
  final String location;        // Loaction of group (not meetings)
  final double latitude;        // Latitude of location
  final double longitude;       // Longitude of location
  final List<String> tags;      // Keywords/tags like “Math” or “History”
  final int? creatorId;     // Dormant field for future use
  final int? created;        // Dormant field for future use

  // api only variables
  final bool joined;
  final int numMembers;

  StudyGroup({
    this.id,
    required this.name,
    required this.description,
    required this.subject,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.tags = const [],
    this.creatorId,
    this.created,
    this.joined = false,
    this.numMembers = 0,
  });

  // Creates a modified copy (used for toggling joined state)
  StudyGroup copyWith({
    bool? joined,
    int? numMembers
  }) => StudyGroup
  (
    id: id,
    name: name,
    description: description,
    subject: subject,
    location: location,
    latitude: latitude,
    longitude: longitude,
    tags: tags,
    creatorId: creatorId,
    created: created,
    joined: joined ?? this.joined,
    numMembers: numMembers ?? this.numMembers,
  );

  // Converts the group into a Map for database storage
  Map<String, Object?> toMap(
    {
      bool includeJoined = false,
      bool includeNumMembers = false,
    }) => {
    'id': id,
    'name': name,
    'description': description,
    'subject': subject,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'tags': tags.join('|'),
    'creatorId': creatorId,
    'created': created,
    if (includeJoined) 'joined': joined,
    if (includeNumMembers) 'numMembers': numMembers,
  };

  // Recreates a StudyGroup object from a Map (when reading from DB)
  factory StudyGroup.fromMap(Map<String, Object?> m) => StudyGroup(
    id: m['id'] as int?,
    name: m['name'] as String,
    description: m['description'] as String,
    subject: m['subject'] as String,
    location: m['location'] as String,
    latitude: m['latitude'] as double,
    longitude: m['longitude'] as double,
    tags: (m['tags'] as String?)?.split('|') ?? const [],
    creatorId: m['creatorId'] as int?,
    created: m['created'] as int?,
    joined: _parseBool(m['joined'], def: false),
    numMembers: (m['numMembers'] as int?) ?? 0,
  );

  /*
    bool _parseBool(Object? v, {bool def = false})

    Helper to parse a bool value for joined
  */
  static bool _parseBool(Object? v, {bool def = false})
  {
    if (v == null) return def;
    if (v is bool) return v;
    if (v is int || v is num) return v != 0;
    if (v is String)
    {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes' || s == 'y') return true;
      if (s == 'false' || s == '0' || s == 'no' || s == 'n') return false;
    }
    return def;
  }
}
