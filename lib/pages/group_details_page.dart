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
  final ClientService _client = ClientService();
  late StudyGroup _group;
  bool _loading = true;
  bool _changingGroupMembership = false;
  final Set<int> _changingSessionMembership = {};
  List<StudySession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _afterLoad();
  }

  Future<void> _afterLoad() async {
    try {
      await _client.ensureUser();
    } catch (_) {}
    await _refresh();
  }

  Future<void> _refresh() async
  {
    if (_group.id == null) return;
    setState(() => _loading = true);

    try
    {
      final sessions = await _client.getSessionsForGroup(_group.id!);
      setState(()
      {
        _sessions = sessions;
        _loading = false;
      });
    }
    catch (e)
    {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar
      (
        SnackBar(content: Text('Failed to load sessions: $e')),
      );
    }
  }

  String _timeConverter(DateTime dt)
  {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');

    return '${local.month}/${local.day} ${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _setGroupJoined(bool joined) async
  {
    if (_group.id == null) return;
    final wasJoined = _group.joined;

    setState(() => _changingGroupMembership = true);

    try
    {
      await _client.setJoinedGroup(_group.id!, joined);

      setState(() {
        // compute loc change
        int delta = 0;
        if (joined && !wasJoined) delta = 1;
        if (!joined && wasJoined) delta = -1;

        final newCount = (_group.numMembers + delta).clamp(0, 1 << 31);
        _group = _group.copyWith(
          joined: joined,
          numMembers: newCount,
        );
      });

      await _refresh();
    }
    catch (e)
    {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update group membership: $e')),
      );
    }
    finally
    {
      if (mounted) setState(() => _changingGroupMembership = false);
    }
  }

  Future<void> _setSessionJoined(StudySession s, bool joined) async
  {
    if (s.id == null) return;
    setState(() => _changingSessionMembership.add(s.id!));

    try
    {
      await _client.setSessionJoined(s.id!, joined);
      await _refresh();
    }
    catch (e)
    {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update session membership: $e')),
      );
    }
    finally
    {
      if (mounted)
      {
        setState(() => _changingSessionMembership.remove(s.id!));
      }
    }
  }

  Future<void> _createSession() async
  {
    if (_group.id == null) return;
    if (!_group.joined)
    {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join the group to create a session first.')),
      );
      return;
    }

    final info = await showDialog<SessionInfo>(
      context: context,
      builder: (_) => const CreateSessionDialog(),
    );

    if (info == null) return; // user canceled

    final now = DateTime.now();

    final start = info.startDateTime ?? now.add(const Duration(hours: 1));
    final end = info.endDateTime ?? start.add(const Duration(hours: 1));

    final session = StudySession(
      id: null,
      groupId: _group.id!,
      title: info.title,
      description: info.description ?? '',
      start: start,
      end: end,
      location: info.location ?? _group.location,
      maxAttendees: info.maxAttendees ?? 10,
      attendees: 0,
      creatorId: null,
      created: null,
    );

    try
    {
      final ok = await _client.addSession(session);
      if (!mounted) return;

      if (ok) {
        await _refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session created')),);
      }
      else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create session')),); }
    }
    catch (e)
    {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create session: $e')),);
    }
  }

  // Opens the chat page for this group.
  Future<void> _openChat() async
  {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(group: widget.group),
      ),
    );
  }

  /// Formats date + time range for a session.
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
      return '$dateStr  ${fmtTime(s.startDateTime!)} → ${fmtTime(s.endDateTime!)}';
    }
    if (s.startDateTime != null) {
      return '$dateStr  Starts ${fmtTime(s.startDateTime!)}';
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

  @override
  Widget build(BuildContext context) {
    final isJoined = _group.joined;
    // for delete button
    final currentUserId = _client.currentUser?.id;
    final canDeleteGroup = currentUserId != null && _group.creatorId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_group.name),
        actions: [
          if (canDeleteGroup)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete group',
              onPressed: _confirmDeleteGroup,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _group.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text('${_group.description}'),
            const SizedBox(height: 10),
            Text('${_group.subject}'),
            const SizedBox(height: 10),
            Text('${_group.location}'),
            const SizedBox(height: 10),
            Text(
              '${_group.numMembers} member${_group.numMembers == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            _buildTagsRow(),
            const SizedBox(height: 15),

            // chat box
            Card(
              child: ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Group Chat'),
                subtitle: const Text('Open the chat for this group'),
                onTap: _openChat,
              ),
            ),

            const SizedBox(height: 12),

            // group members row
            Row(
              children: [
                Chip(label: Text(isJoined ? 'Joined' : 'Not joined')),
                const Spacer(),
                if (_changingGroupMembership)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isJoined)
                  OutlinedButton(
                    onPressed: () => _setGroupJoined(false),
                    child: const Text('Leave'),
                  )
                else
                  FilledButton(
                    onPressed: () => _setGroupJoined(true),
                    child: const Text('Join'),
                  ),
              ],
            ),

            const SizedBox(height: 24),
            Row( children: [
                Text(
                  'Sessions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _group.joined ? _createSession : null,
                  icon: const Icon(Icons.add),
                  label: const Text('New session'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No sessions in this group yet.'),
              )
            else
              ..._sessions.map((s) {
                final sessionJoined = s.joined;
                final busy = s.id != null && _changingSessionMembership.contains(s.id!);
                // for session deletion
                final currentUserId = _client.currentUser?.id;
                final canDeleteSession = currentUserId != null && s.creatorId == currentUserId;

                return Card(
                  child: ListTile(
                    title: Text(s.title),
                    subtitle: Text(
                      '${_timeConverter(s.start)} - ${_timeConverter(s.end)} • ${s.location} \n'
                      '${s.description}'
                      '${s.attendees}/${s.maxAttendees} attending'
                    ),
                    isThreeLine: true,
                    trailing: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (sessionJoined)
                                OutlinedButton(
                                  onPressed: () => _setSessionJoined(s, false),
                                  child: const Text('Leave'),
                                )
                              else
                                FilledButton(
                                  // If backend requires group membership first:
                                  onPressed: isJoined ? () => _setSessionJoined(s, true) : null,
                                  child: const Text('Join'),
                                ),
                              if (canDeleteSession)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Delete session',
                                  onPressed: () => _confirmDeleteSession(s),
                                ),
                            ],
                          ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }




  Future<void> _confirmDeleteGroup() async
  {
    // early out
    if (_group.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group'),
        content: const Text(
          'Are you sure you want to delete this group? '
          'This will also remove all its sessions and messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final ok = await _client.deleteGroup(_group.id!);
      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group deleted')),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nice Try!')),
        );
      }
    }
    catch (e)
    {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete group :< ($e)')),
      );
    }
  }

  Future<void> _confirmDeleteSession(StudySession s) async
  {
    // early out
    if (s.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session'),
        content: Text(
          'Delete the session "${s.title}"?\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(()
    {
      if (s.id != null) {
        _changingSessionMembership.add(s.id!);
      }
    });

    try
    {
      final ok = await _client.deleteSession(s.id!);
      if (!mounted) return;

      if (ok) {
        
        await _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session deleted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nice Try!')),
        );
      }
    }
    catch (e)
    {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete session: $e')),
      );
    }
    finally
    {
      if (mounted && s.id != null)
      {
        setState(() {
          _changingSessionMembership.remove(s.id!);
        });

      }
    }
  }

}
