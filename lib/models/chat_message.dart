// Model class representing a single chat message in a study group
class ChatMessage {
  final int? id;           // Database ID (auto-incremented)
  final int groupId;       // ID of the group this message belongs to
  final String author;     // Name of the person who sent the message
  final String text;       // Message content
  final DateTime ts;       // Timestamp of when the message was sent

  ChatMessage({
    this.id,
    required this.groupId,
    required this.author,
    required this.text,
    required this.ts,
  });

  // Converts this object to a Map for storing in the database
  Map<String, Object?> toMap() => {
    'id': id,
    'groupId': groupId,
    'author': author,
    'text': text,
    'ts': ts.toIso8601String(),
  };

  // Recreates a ChatMessage object from a database record (Map)
  factory ChatMessage.fromMap(Map<String, Object?> m) => ChatMessage(
    id: m['id'] as int?,
    groupId: m['groupId'] as int,
    author: m['author'] as String,
    text: m['text'] as String,
    ts: DateTime.parse(m['ts'] as String),
  );
}
