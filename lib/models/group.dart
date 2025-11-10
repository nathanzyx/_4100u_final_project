// Model class representing a study group (community of students)
class StudyGroup {
  final int? id;                // Database ID (auto-incremented)
  final String name;            // Name of the study group
  final String description;     // Description of the study group
  final String subject;         // Subject or topic focus
  final String location;        // Loaction of group (not meetings)
  final List<String> tags;      // Keywords/tags like “Math” or “History”
  final int? creatorId;     // Dormant field for future use
  // final bool joined;            // Whether the current user has joined

  StudyGroup({
    this.id,
    required this.name,
    required this.description,
    required this.subject,
    required this.location,
    this.tags = const [],
    this.creatorId,
    // this.joined = false,
  });

  // Creates a modified copy (used for toggling joined state)
  StudyGroup copyWith({bool? joined}) => StudyGroup(
    id: id,
    name: name,
    description: description,
    subject: subject,
    location: location,
    tags: tags,
    creatorId: creatorId,
    // joined: joined ?? this.joined,
  );

  // Converts the group into a Map for database storage
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'subject': subject,
    'location': location,
    'tags': tags.join('|'),
    'creatorId': creatorId,
    // 'joined': joined ? 1 : 0,
  };

  // Recreates a StudyGroup object from a Map (when reading from DB)
  factory StudyGroup.fromMap(Map<String, Object?> m) => StudyGroup(
    id: m['id'] as int?,
    name: m['name'] as String,
    description: m['description'] as String,
    subject: m['subject'] as String,
    location: m['location'] as String,
    tags: (m['tags'] as String?)?.split('|') ?? const [],
    creatorId: m['creatorId'] as int,
    // joined: (m['joined'] as int? ?? 0) == 1,
  );
}
