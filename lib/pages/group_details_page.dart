import 'package:flutter/material.dart';
import 'package:study_connect_shared/models/group.dart';
import 'package:study_connect_shared/models/session.dart'; // kept for later if you hook backend

import '../services/client/client_services.dart';
import '../services/app_notifier.dart';
import '../services/local_sessions.dart';
import '../widgets/create_session.dart';
import 'chat_page.dart';

/// Details screen for a single study group.
/// - Shows group info (name, tags, description, location)
/// - Lets you open the chat
/// - Shows upcoming sessions
/// - Lets you create a new session
class GroupDetailsPage extends StatefulWidget {
  final StudyGroup group;

  const GroupDetailsPage({super.key, required this.group});

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  final _client = ClientService();
  final _sessionStore = LocalSessionStore.instance;

  final List<SessionInfo> _sessions = [];
  bool _loadingSessions = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  /// Load sessions for this group from the local store.
  Future<void> _loadSessions() async {
    setState(() => _loadingSessions = true);

    final id = widget.group.id;
    final loaded = (id == null) ? <SessionInfo>[] : _sessionStore.getSessions(id);

    setState(() {
      _sessions
        ..clear()
        ..addAll(loaded);
      _loadingSessions = false;
    });
  }

  /// Opens the chat page for this group.
  Future<void> _openChat() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(group: widget.group),
      ),
    );
  }

  /// Shows the dialog to create a new session and adds it to the list + store.
  Future<void> _createSession() async {
    final info = await showDialog<SessionInfo>(
      context: context,
      builder: (_) => const CreateSessionDialog(),
    );

    if (info == null) return;

    final id = widget.group.id;
    if (id != null) {
      _sessionStore.addSession(id, info);
    }

    setState(() {
      _sessions.add(info);
    });

    AppNotifier.show(
      context,
      message: 'Session "${info.title}" added to ${widget.group.name}',
      icon: Icons.event,
    );
  }

  /// Nice little banner at the top to show membership.
  Widget _buildMemberBanner() {
    return Container(
      width: double.infinity,
      color: Colors.green.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Center(
        child: Text(
          'You are a member of this group.',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  /// Chips for the group tags (e.g., Math, Calculus, First Year)
  Widget _buildTagsRow() {
    if (widget.group.tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: widget.group.tags
          .map(
            (t) => Chip(
          label: Text(t),
          visualDensity: VisualDensity.compact,
        ),
      )
          .toList(),
    );
  }

  /// Card that shows the main info about this group.
  Widget _buildGroupHeaderCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group name
            Text(
              widget.group.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            // Tags row
            _buildTagsRow(),
            const SizedBox(height: 12),

            // Description
            if (widget.group.description != null &&
                widget.group.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(widget.group.description!),
              ),

            // Location line
            if (widget.group.location.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.group.location,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Formats date + time range for a session.
  /// Example: "Tue, Nov 25, 2025 • 14:00 → 16:00"
  String _formatSession(SessionInfo s) {
    if (s.startDateTime == null) return '';

    final d = s.startDateTime!;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final wd = weekdays[d.weekday - 1];
    final m = months[d.month - 1];
    final day = d.day.toString().padLeft(2, '0');
    final year = d.year.toString();

    String fmtTime(DateTime dt) => dt.toLocal().toString().substring(11, 16);

    final dateStr = '$wd, $m $day, $year';

    if (s.startDateTime != null && s.endDateTime != null) {
      return '$dateStr • ${fmtTime(s.startDateTime!)} → ${fmtTime(s.endDateTime!)}';
    }
    if (s.startDateTime != null) {
      return '$dateStr • Starts ${fmtTime(s.startDateTime!)}';
    }

    return dateStr;
  }

  /// One card for a single session.
  Widget _buildSessionCard(SessionInfo s) {
    final subtitleLines = <String>[];

    final scheduleLine = _formatSession(s);
    if (scheduleLine.isNotEmpty) {
      subtitleLines.add(scheduleLine);
    }

    if (s.location != null && s.location!.isNotEmpty) {
      subtitleLines.add('Room: ${s.location}');
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        title: Text(s.title),
        subtitle:
        subtitleLines.isEmpty ? null : Text(subtitleLines.join('\n')),
      ),
    );
  }

  /// Whole "Upcoming sessions" section.
  Widget _buildSessionsSection() {
    if (_loadingSessions) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_sessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'No sessions yet. Tap "Create session" to schedule one!',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Upcoming sessions',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        ..._sessions.map(_buildSessionCard),
        const SizedBox(height: 80), // space above the FAB / bottom bar
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSession,
        icon: const Icon(Icons.add),
        label: const Text('Create session'),
      ),
      body: Column(
        children: [
          _buildMemberBanner(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildGroupHeaderCard(),
                  const SizedBox(height: 8),
                  _buildSessionsSection(),
                ],
              ),
            ),
          ),
        ],
      ),

      // Big "Open chat" button pinned to the bottom.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton.icon(
            onPressed: _openChat,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Open chat'),
          ),
        ),
      ),
    );
  }
}
