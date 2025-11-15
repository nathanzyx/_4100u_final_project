import 'package:flutter/material.dart';
import 'package:study_connect_shared/models/user.dart';
import 'package:study_connect_shared/models/group.dart';
import 'package:study_connect_shared/models/session.dart';
import 'package:study_connect_shared/models/chat_message.dart';
import '../services/client/client_services.dart';
import '../services/app_notifier.dart';

// Per-group local chat screen (SQLite-backed)
class ChatPage extends StatefulWidget {
  final StudyGroup group;
  const ChatPage({super.key, required this.group});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _client = ClientService();
  final _inputCtrl = TextEditingController();         // message composer

  // final _displayNameCtrl = TextEditingController(
  //   text: 'You',
  // ); // simple local display name
  List<ChatMessage> _messages = [];                   // loaded from DB

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _init() async {
    final msgs = await _client.getMessages(widget.group.id!);

    setState(() {
      _messages = msgs;
    });
  }

  /// Loads all messages for this group (ascending by time)
  Future<void> _loadMessages() async {
    if (widget.group.id == null) return;
    final msgs = await _client.getMessages(widget.group.id!);
    setState(() => _messages = msgs);
  }

  /// Sends the current input as a message (no-op if blank)
  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || widget.group.id == null) return;

    final msg = ChatMessage(
      groupId: widget.group.id!,
      text: text,
    );

    await _client.addMessage(msg);
    _inputCtrl.clear();
    await _loadMessages(); // refresh list

    // Give a notification
    AppNotifier.show(
      context,
      message: 'Message sent to ${widget.group.name}',
      icon: Icons.chat_bubble_outline,
    );
  }

  /// Nicely formats a timestamp like "2025-11-05 14:36"
  String _formatTs(DateTime date) => date.toLocal().toString().substring(0, 16);

  /// One chat bubble (left/right aligned by author)
  Widget _buildMessageBubble(ChatMessage m) {
    final currentUserId = (_client.currentUser)!.id;
    final isMine = m.creatorId == currentUserId;
    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final authorLabel = isMine ? 'You' : (m.creatorId != null ? 'User ${m.creatorId}' : 'Unknown');

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
              authorLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            // message text
            Text(m.text),
            const SizedBox(height: 2),
            // timestamp
            Text(
              _formatTs(m.date!),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat • ${widget.group.name}')),
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
