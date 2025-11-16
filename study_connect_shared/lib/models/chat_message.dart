// Model class representing a single chat message in a study group
class ChatMessage {
  final int? id;           // Database ID (auto-incremented)
  final int groupId;       // ID of the group this message belongs to
  final int? sessionId;     // ID of the session this message belongs to (optional)
  final int? creatorId;     // Name of the person who sent the message
  final String text;       // Message content
  final DateTime? date;       // Timestamp of when the message was sent

  ChatMessage({
    this.id,
    required this.groupId,
    this.sessionId,
    this.creatorId,
    required this.text,
    this.date,
  });

  // Converts this object to a Map for storing in the database
  Map<String, Object?> toMap() => {
    'id': id,
    'groupId': groupId,
    'sessionId': sessionId,
    'creatorId': creatorId,
    'text': text,
    'date': date?.millisecondsSinceEpoch,
  };

  // Recreates a ChatMessage object from a database record (Map)
  factory ChatMessage.fromMap(Map<String, Object?> m) => ChatMessage(
    id: m['id'] as int?,
    groupId: m['groupId'] as int,
    sessionId: m['sessionId'] as int?,
    creatorId: m['creatorId'] as int?,
    text: m['text'] as String,
    date: m['date'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
  );
}
