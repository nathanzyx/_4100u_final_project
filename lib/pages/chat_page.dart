import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/group.dart';
import '../services/database.dart';

// Per-group local chat screen (SQLite-backed)
class ChatPage extends StatefulWidget {
  final StudyGroup group;
  const ChatPage({super.key, required this.group});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _db = AppDb();
  final _inputCtrl = TextEditingController();         // message composer
  final _displayNameCtrl = TextEditingController(
    text: 'You',
  ); // simple local display name
  List<ChatMessage> _messages = [];                   // loaded from DB

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  /// Loads all messages for this group (ascending by time)
  Future<void> _loadMessages() async {
    final msgs = await _db.getMessages(widget.group.id!);
    setState(() => _messages = msgs);
  }

  /// Sends the current input as a message (no-op if blank)
  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    final author = _displayNameCtrl.text.trim().isEmpty
        ? 'You'
        : _displayNameCtrl.text.trim();

    final msg = ChatMessage(
      groupId: widget.group.id!,
      author: author,
      text: text,
      ts: DateTime.now(),
    );

    await _db.addMessage(msg);
    _inputCtrl.clear();
    await _loadMessages(); // refresh list
  }

  /// Nicely formats a timestamp like "2025-11-05 14:36"
  String _formatTs(DateTime ts) => ts.toLocal().toString().substring(0, 16);

  /// Opens a small dialog to edit the local display name
  Future<void> _editDisplayName() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: _displayNameCtrl,
          decoration: const InputDecoration(hintText: 'e.g., Faryal'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    setState(() {}); // rebuild so alignment reflects new name
  }

  /// One chat bubble (left/right aligned by author)
  Widget _buildMessageBubble(ChatMessage m) {
    final isMine = m.author == _displayNameCtrl.text;
    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.indigo.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // author name
            Text(
              m.author,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            // message text
            Text(m.text),
            const SizedBox(height: 2),
            // timestamp
            Text(
              _formatTs(m.ts),
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  /// Message composer row (TextField + Send button)
  Widget _buildComposer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                decoration: const InputDecoration(
                  hintText: 'Type a message…',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  /// App bar with group title and a quick action to edit display name
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text('Chat • ${widget.group.name}'),
      actions: [
        IconButton(
          tooltip: 'Change display name',
          icon: const Icon(Icons.person),
          onPressed: _editDisplayName,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // messages list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
            ),
          ),
          // composer
          _buildComposer(),
        ],
      ),
    );
  }
}
