import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:study_connect_shared/models/group.dart';
import 'package:study_connect/pages/group_details_page.dart';
import 'package:study_connect/services/tips.dart';
import 'package:study_connect/widgets/create_group.dart';
import 'package:study_connect/pages/settings_page.dart'; // settings screen
import 'package:study_connect/widgets/location_picker.dart';
import '../services/client/client_services.dart';

// Home screen of StudyConnect:
// - Shows a "Study Tip of the Day"
// - Lets users search/filter study groups
// - Displays all groups with swipe-to-delete
// - Adds new groups via a floating button
class HomePage extends StatefulWidget {
  // Whether dark mode is currently on or off (comes from main.dart)
  final bool darkModeEnabled;


  // Callback to tell main.dart that the theme switch changed
  final ValueChanged<bool> onThemeChanged;

  const HomePage({
    super.key,
    required this.darkModeEnabled,
    required this.onThemeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _client = ClientService();

  final _search = TextEditingController(); // search box controller

  // for geolocation
  LatLng? _nearPoint;
  String? _nearLabel;
  double? _nearKm;

  List<StudyGroup> _groups = [];           // loaded list of groups
  String _tip = 'Loading tip...';          // motivational tip text

  @override
  void initState() {
    super.initState();
    _client.startNotificationPolling(); // begin polling for notifications
    _load(); // fetch groups and daily tip
    // _getLocation(); // get user location
  }

  Future<void> _getLocation() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final picked = await showLocationPickerDialog(
        context: context,
        barrierDismissible: false,
        title: 'Please set your location',
      );

      if (picked == null) return;

      await _client.setUserCoordinates(
        picked.point.latitude,
        picked.point.longitude,
      );
    });
  }

  /// Loads study groups and the daily tip
  Future<void> _load() async {
    final q = _search.text.trim();
    final g = await _client.getGroups
    (
      query: q.isEmpty ? null : q,
      nearLat: _nearPoint?.latitude,
      nearLng: _nearPoint?.longitude,
      withinKm: _nearKm,
    );
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
    final hasNear = _nearPoint != null && _nearKm != null;

    return Row(
      children:
      [
        Expanded(
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search study groups...',
              border: OutlineInputBorder(),
            ),
            onChanged: (i) => _load(),
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: hasNear ? 'Nearby filter (active)' : 'Nearby filter',
          child: IconButton.filledTonal(
            onPressed: _openNearbyFilter,
            icon: Icon(hasNear ? Icons.near_me : Icons.near_me_outlined),
          ),
        ),
      ],
    );
  }

  // small helper for reducing location size
  String _shorten(String text, {int max = 40})
  {
    if (text.length <= max) return text;
    return text.substring(0, max) + '…';
  }

  Future<void> _refreshGroups() => _load();

  Widget _buildGroupTile(StudyGroup g)
  {
    final isJoined = g.joined;


    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
    child: ListTile(
      title: Text(g.name),
      subtitle: 
        Text(
          '${g.subject}\n${_shorten(g.location, max: 19)}\n${g.numMembers} member${g.numMembers == 1 ? '' : 's'}'
          '${isJoined ? " • Joined" : ""}',
        ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isJoined)
            OutlinedButton(
              onPressed: () async {
                await _client.setJoinedGroup(g.id!, false);
                _refreshGroups();
              },
              child: const Text('Leave'),
            )
          else
            FilledButton(
              onPressed: () async {
                await _client.setJoinedGroup(g.id!, true);
                _refreshGroups();
              },
              child: const Text('Join'),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GroupDetailsPage(group: g)),
        );
        _refreshGroups();
      },
    ),
    );
  }

  /// build the list of study groups (filtered by search)
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
          child: Text('There are no groups! 🔎'),
        ),
      );
    }

    return Column(children: filtered.map(_buildGroupTile).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StudyConnect'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              // Open the Settings screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    // pass the real dark-mode flag from main.dart
                    darkModeEnabled: widget.darkModeEnabled,
                    // when the user changes the switch, tell main.dart
                    onThemeChanged: widget.onThemeChanged,
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
            const SizedBox(height: 12),
            _buildNearbyLoc(),
            if (_nearPoint != null) const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /*
    Helpers for geolocation searching
  */
  Future<void> _openNearbyFilter() async
  {
    final outerContext = context;

    LatLng? point = _nearPoint ?? (_client.currentUser == null ? null : LatLng(_client.currentUser!.latitude, _client.currentUser!.longitude));
    String? label = _nearLabel;
    final kmCtrl = TextEditingController(text: (_nearKm ?? 10).toString());

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Nearby groups'),
          content: StatefulBuilder(
            builder: (ctx, setModal) {
              final display = label ??
                  (point == null
                      ? 'No location selected'
                      : 'Lat: ${point!.latitude.toStringAsFixed(4)}, Lng: ${point!.longitude.toStringAsFixed(4)}');
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(

                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(display, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: const Text('Pick a location on the map'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Pick on map'),
                          onPressed: () async {
                            final picked = await showLocationPickerDialog(
                              context: ctx,
                              title: 'Choose search location',
                              initialCenter: point ?? const LatLng(43.6532, -79.3832),
                              allowCancel: true,

                            );
                            if (picked == null) return;

                            setModal(() {
                              point = picked.point;
                              label = picked.label;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: kmCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Radius (km)',
                      border: OutlineInputBorder(),
                      suffixText: 'km',
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('clear'),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: ()
              {
                final km = double.tryParse(kmCtrl.text.trim());

                if (point == null)
                {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    const SnackBar(content: Text('Pick a location first.')),
                  );
                  return;
                }
                if (km == null || km <= 0)
                {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    const SnackBar(content: Text('Enter a valid radius in km.')),
                  );
                  return;
                }

                _nearPoint = point;
                _nearLabel = label;
                _nearKm = km;

                Navigator.of(ctx).pop('apply');
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (result == null) return;
    if (result == 'clear')
    {
      setState(() {
        _nearPoint = null;
        _nearLabel = null;
        _nearKm = null;
      });
      await _load();
      return;
    }

    setState(() {}); // already set fields above
    await _load();
  }

  Widget _buildNearbyLoc()
  {
    if (_nearPoint == null || _nearKm == null) return const SizedBox.shrink();

    final label = _nearLabel ?? 'Lat ${_nearPoint!.latitude.toStringAsFixed(3)}, Lng ${_nearPoint!.longitude.toStringAsFixed(3)}';

    return InputChip(
      avatar: const Icon(Icons.near_me_outlined, size: 18),
      label: Text('Within ${_nearKm!.toStringAsFixed(0)} km • $label',
          overflow: TextOverflow.ellipsis),
      onPressed: _openNearbyFilter,
      onDeleted: () async {
        setState(() {
          _nearPoint = null;
          _nearLabel = null;
          _nearKm = null;
        });
        await _load();
      },
    );
  }

}
