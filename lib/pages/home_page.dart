import 'package:flutter/material.dart';
import 'package:study_connect_shared/models/group.dart';
import 'package:study_connect/pages/group_details_page.dart';
import 'package:study_connect/services/tips.dart';
import 'package:study_connect/widgets/create_group.dart';
import '../services/client/client_services.dart';

// Home screen of StudyConnect:
// - Shows a "Study Tip of the Day"
// - Lets users search/filter study groups
// - Displays all groups with swipe-to-delete
// - Adds new groups via a floating button
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _client = ClientService();
  final _search = TextEditingController(); // search box controller

  List<StudyGroup> _groups = [];           // loaded list of groups
  String _tip = 'Loading tip...';          // motivational tip text

  @override
  void initState() {
    super.initState();
    _load(); // fetch groups and daily tip
  }

  /// Loads study groups and the daily tip
  Future<void> _load() async {
    final g = await _client.getGroups();
    final tip = await TipsService.fetchDailyTip();
    setState(() {
      _groups = g;
      _tip = tip;
    });
  }

  /// Opens the "Create Group" dialog and adds it to the database
  Future<void> _createGroup() async {
    final g = await showDialog<StudyGroup>(
      context: context,
      builder: (_) => const CreateGroupDialog(),
    );
    if (g != null) {
      await _client.addGroup(g);
      await _load();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Group created')));
    }
  }

  /// Deletes a selected group and updates the list
  Future<void> _deleteGroup(StudyGroup g) async {
    await _client.deleteGroup(g.id!);
    await _load();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Deleted "${g.name}"')));
  }

  /// Builds the "Study Tip of the Day" card
  Widget _buildTipCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lightbulb),
        title: const Text('Study Tip of the Day'),
        subtitle: Text(_tip),
      ),
    );
  }

  /// Builds the search field for filtering groups
  Widget _buildSearchBox() {
    return TextField(
      controller: _search,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'Search study groups...',
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}), // updates filter on text change
    );
  }

  /// Builds a single group card (with swipe-to-delete)
  Widget _buildGroupTile(StudyGroup g) {
    return Dismissible(
      key: ValueKey('g_${g.id}_${g.name}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        // confirm deletion dialog
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete group?'),
            content: Text(
                'This will remove "${g.name}" and all its sessions & chat.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
            false;
      },
      onDismissed: (_) => _deleteGroup(g),
      child: Card(
        child: ListTile(
          title: Text(g.name),
          subtitle: Text('${g.subject}\n${g.location}'),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GroupDetailsPage(group: g)),
            );
            await _load(); // refresh on return
          },
        ),
      ),
    );
  }

  /// Builds the list of study groups (filtered by search)
  Widget _buildGroupList() {
    final query = _search.text.trim().toLowerCase();

    final filtered = _groups.where((g) {
      if (query.isEmpty) return true;
      return g.name.toLowerCase().contains(query) ||
          g.subject.toLowerCase().contains(query) ||
          g.tags.any((t) => t.toLowerCase().contains(query));
    }).toList();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('No groups yet. Tap "New Group" to add one!'),
        ),
      );
    }

    return Column(children: filtered.map(_buildGroupTile).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StudyConnect')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        icon: const Icon(Icons.group_add),
        label: const Text('New Group'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTipCard(),
            const SizedBox(height: 12),
            _buildSearchBox(),
            const SizedBox(height: 12),
            _buildGroupList(),
          ],
        ),
      ),
    );
  }
}
