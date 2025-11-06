// Model class representing a study group (community of students)
class StudyGroup {
  final int? id;                // Database ID (auto-incremented)
  final String name;            // Name of the study group
  final String subject;         // Subject or topic focus
  final String meetingTime;     // Regular meeting schedule
  final String location;        // Meeting location
  final List<String> tags;      // Keywords/tags like “Math” or “History”
  final bool joined;            // Whether the current user has joined

  StudyGroup({
    this.id,
    required this.name,
    required this.subject,
    required this.meetingTime,
    required this.location,
    this.tags = const [],
    this.joined = false,
  });

  // Creates a modified copy (used for toggling joined state)
  StudyGroup copyWith({bool? joined}) => StudyGroup(
    id: id,
    name: name,
    subject: subject,
    meetingTime: meetingTime,
    location: location,
    tags: tags,
    joined: joined ?? this.joined,
  );

  // Converts the group into a Map for database storage
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'subject': subject,
    'meetingTime': meetingTime,
    'location': location,
    'tags': tags.join('|'),
    'joined': joined ? 1 : 0,
  };

  // Recreates a StudyGroup object from a Map (when reading from DB)
  factory StudyGroup.fromMap(Map<String, Object?> m) => StudyGroup(
    id: m['id'] as int?,
    name: m['name'] as String,
    subject: m['subject'] as String,
    meetingTime: m['meetingTime'] as String,
    location: m['location'] as String,
    tags: (m['tags'] as String?)?.split('|') ?? const [],
    joined: (m['joined'] as int? ?? 0) == 1,
  );
}
