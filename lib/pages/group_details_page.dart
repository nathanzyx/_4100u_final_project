import 'package:flutter/material.dart';
import 'package:study_connect_shared/models/group.dart';
import 'package:study_connect_shared/models/session.dart';
import 'package:study_connect/pages/chat_page.dart';
import 'package:study_connect/widgets/create_session.dart';
import 'package:study_connect/widgets/edit.dart';
import '../services/client/client_services.dart';

// Group details screen:
// - Join/Leave group
// - Edit group info
// - Open chat for this group
// - List/Create/Delete sessions
class GroupDetailsPage extends StatefulWidget {
  final StudyGroup group;
  const GroupDetailsPage({super.key, required this.group});

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  final _client = ClientService();
  late StudyGroup _group;                 // current group (updates after edit/join)
  List<StudySession> _sessions = [];      // sessions for this group

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _load(); // fetch sessions from DB
  }

  /// Loads sessions for this group
  Future<void> _load() async {
    final s = await _client.getSessionsForGroup(_group.id!);
    setState(() => _sessions = s);
  }

  /// Toggles joined/left state for this group
  // Future<void> _toggleJoin() async {
  //   await _db.setJoined(_group.id!, !_group.joined);
  //   setState(() => _group = _group.copyWith(joined: !_group.joined));
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(content: Text(_group.joined ? 'Joined ${_group.name}' : 'Left ${_group.name}')),
  //   );
  // }

  /// Opens dialog to create a new session, saves to DB, refreshes list
  Future<void> _createSession() async {
    final created = await showDialog<StudySession>(
      context: context,
      builder: (_) => CreateSessionDialog(groupId: _group.id!),
    );
    if (created != null) {
      await _client.addSession(created);
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session created')));
    }
  }

  /// Deletes a session and refreshes list
  Future<void> _deleteSession(StudySession s) async {
    await _client.deleteSession(s.id!);
    await _load();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session deleted')));
  }

  /// Opens dialog to edit group, saves to DB, updates local copy
  Future<void> _editGroup() async {
    final updated = await showDialog<StudyGroup>(
      context: context,
      builder: (_) => EditGroupDialog(group: _group),
    );
    if (updated != null) {
      await _client.updateGroup(updated);
      setState(() => _group = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group updated')));
    }
  }

  // ---------- UI helpers  ----------

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(_group.name),
      actions: [
        // Join / Leave toggle
        // TextButton.icon(
        //   // onPressed: _toggleJoin,
        //   // icon: Icon(_group.joined ? Icons.logout : Icons.group_add, color: Colors.white),
        //   // label: Text(_group.joined ? 'Leave' : 'Join', style: const TextStyle(color: Colors.white)),
        // ),
        // Overflow menu (Edit)
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _editGroup();
          },
          itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit group'))],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // tags row
        Wrap(spacing: 8, children: _group.tags.map((t) => Chip(label: Text(t))).toList()),
        const SizedBox(height: 8),

        // time + location
        Text(_group.location),
        const SizedBox(height: 8),

        // open chat button
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatPage(group: _group)),
          ),
          icon: const Icon(Icons.chat),
          label: const Text('Open Chat'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSessionTile(StudySession s) {
    return Card(
      child: ListTile(
        title: Text(s.title),
        subtitle: Text(
          '${s.start} → ${s.end}\n${s.location} • ${s.attendees}/${s.maxAttendees} attending',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _deleteSession(s),
        ),
        onTap: () async {
          // await _client.incrementAttendees(s.id!); // "join" the session
          await _load();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined session')));
        },
      ),
    );
  }

  Widget _buildSessionsList() {
    if (_sessions.isEmpty) {
      return const Text('No upcoming sessions. Tap "Create Session" to add one.');
    }
    return Column(children: _sessions.map(_buildSessionTile).toList());
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSession,
        icon: const Icon(Icons.add),
        label: const Text('Create Session'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          _buildSessionsList(),
        ],
      ),
    );
  }
}
