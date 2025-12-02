// Model class representing a single study session within a group
class StudySession {
  final int? id;              // Database ID (auto-incremented)
  final int groupId;          // ID of the parent study group
  final String title;         // Session topic or title
  final String description;     // Description of the session
  final DateTime start;       // Start time/date of the session
  final DateTime end;         // End time/date of the session
  final String location;      // Where the session will be held
  final int maxAttendees;     // Maximum allowed participants
  final int attendees;        // Current number of attendees
  final int? creatorId;      // Dormant field for future use
  final DateTime created;   // Creation timestamp

  // api only variable for indicating device user joined status
  final bool joined;

  StudySession({
    this.id,
    required this.groupId,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    required this.location,
    required this.maxAttendees,
    this.attendees = 0,
    this.creatorId,
    DateTime? created,
    this.joined = false,
  }) : created = created ?? DateTime.now();

  // Converts this object into a Map for saving into SQLite
  Map<String, Object?> toMap({bool includeJoined = false}) => {
    'id': id,
    'groupId': groupId,
    'title': title,
    'description': description,
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
    'location': location,
    'maxAttendees': maxAttendees,
    'attendees': attendees,
    'creatorId': creatorId,
    'created': created.millisecondsSinceEpoch,
    if (includeJoined) 'joined': joined
  };

  // Creates a StudySession instance from a Map (from SQLite)
  factory StudySession.fromMap(Map<String, Object?> m) => StudySession(
    id: m['id'] as int?,
    groupId: m['groupId'] as int,
    title: m['title'] as String,
    description: (m['description'] as String?) ?? '',
    start: DateTime.fromMillisecondsSinceEpoch(m['start'] as int),
    end: DateTime.fromMillisecondsSinceEpoch(m['end'] as int),
    location: m['location'] as String,
    maxAttendees: m['maxAttendees'] as int,
    attendees: (m['attendees'] as int?) ?? 0,
    creatorId: m['creatorId'] as int?,
    created: DateTime.fromMillisecondsSinceEpoch(m['created'] as int),
    joined: _parseBool(m['joined'], def: false)
  );

  /*
    Helper to copy a session data instance with/without the joined variable
  */
  StudySession copyWith({bool? joined}) => StudySession(
    id: id,
    groupId: groupId,
    title: title,
    description: description,
    start: start,
    end: end,
    location: location,
    maxAttendees: maxAttendees,
    attendees: attendees,
    creatorId: creatorId,
    created: created,
    joined: joined ?? this.joined
  );
  /*
    bool _parseBool(Object? v, {bool def = false})

    Helper to parse a bool value for joined
  */
  static bool _parseBool(Object? v, {bool def = false})
  {
    if (v == null) return def;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is num) return v != 0;
    if (v is String)
    {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes' || s == 'y') return true;
      if (s == 'false' || s == '0' || s == 'no' || s == 'n') return false;
    }
    return def;
  }
}
