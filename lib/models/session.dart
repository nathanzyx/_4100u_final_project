// Model class representing a single study session within a group
class StudySession {
  final int? id;              // Database ID (auto-incremented)
  final int groupId;          // ID of the parent study group
  final String title;         // Session topic or title
  final DateTime start;       // Start time/date of the session
  final DateTime end;         // End time/date of the session
  final String location;      // Where the session will be held
  final int maxAttendees;     // Maximum allowed participants
  final int attendees;        // Current number of attendees

  StudySession({
    this.id,
    required this.groupId,
    required this.title,
    required this.start,
    required this.end,
    required this.location,
    required this.maxAttendees,
    this.attendees = 0,
  });

  // Converts this object into a Map for saving into SQLite
  Map<String, Object?> toMap() => {
    'id': id,
    'groupId': groupId,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'location': location,
    'maxAttendees': maxAttendees,
    'attendees': attendees,
  };

  // Creates a StudySession instance from a Map (from SQLite)
  factory StudySession.fromMap(Map<String, Object?> m) => StudySession(
    id: m['id'] as int?,
    groupId: m['groupId'] as int,
    title: m['title'] as String,
    start: DateTime.parse(m['start'] as String),
    end: DateTime.parse(m['end'] as String),
    location: m['location'] as String,
    maxAttendees: m['maxAttendees'] as int,
    attendees: (m['attendees'] as int?) ?? 0,
  );
}
