import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_connect_shared/models/user.dart';
import 'package:study_connect_shared/models/group.dart';
import 'package:study_connect_shared/models/session.dart';
import 'package:study_connect_shared/models/chat_message.dart';
import 'dart:math';

import 'seed_data.dart';

// SQLite database handler for StudyConnect
// Handles all CRUD operations for:
//  - groups     -> study communities
//  - sessions   -> group study events
//  - messages   -> per-group chat messages
class AppDb {
  static final AppDb _i = AppDb._();  // singleton instance
  AppDb._();
  factory AppDb() => _i;

  Database? _db; // holds the open database connection

  final _random = Random.secure();
  String _getRandomString(int length) 
  {
    String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (a) => chars[_random.nextInt(chars.length)]
      ).join();
  }

  // Lazily initializes the database if not already open
  Future<Database> get db async {
    if (_db != null) return _db!;

    final path = join(await getDatabasesPath(), 'study_connect.db');
    // await deleteDatabase(path); // FOR TESTING ONLY: reset DB on each run

    _db = await openDatabase(
      path,
      version: 4,
      onCreate: (d, v) async {

        /*

        Users
          - `id`: unique, auto-incremented identifier
          - `displayName`: non-unique dislay name for the user

          Context:
            - Used for identifying messages and creators of groups/sessions
        
          Future notes/ideas (ideal, time permitting):
            - Add password and authentication

        */
        await d.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            displayName TEXT NOT NULL,
            username TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            authToken TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            created INTEGER NOT NULL
          );
        ''');


      

        /*

        Group
          - `id`: unique, auto-incremented identifier
          - `name`: the name of the study group
          - `description`: brief description of the group
          - `subject`: subject or topic of the group
          - `location`: physical location associated with the group (e.g. OTU address)
          - `tags`: keywords associated with the group (stored as a | delimited string)
          - `creator`: who created the group (dormant since there is no singular ownership of groups)
          - `created`: timestamp of creation (dormant field)

          - A group represents a study community (ex: "Calculus 101", "OTU Computer Science")

          Context:
            - Groups are non-owned, meaning the creator does not have special privileges (creator is
                a dormant field for potential future use)
        
          Future notes/ideas (ideal, time permitting):
            - Groups are auto deleted if no others join within X time of creation

        */
        await d.execute('''
          CREATE TABLE groups(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT NOT NULL,
            subject TEXT NOT NULL,
            location TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            tags TEXT NOT NULL,
            creatorId INTEGER NOT NULL, -- dormant field
            created INTEGER NOT NULL, -- dormant field
            FOREIGN KEY(creatorId) REFERENCES users(id) ON DELETE CASCADE
          );
        ''');

        /*

        */
        await d.execute('''
          CREATE TABLE group_members(
            userId INTEGER NOT NULL,
            groupId INTEGER NOT NULL,
            joinedAt INTEGER NOT NULL,
            PRIMARY KEY(userId, groupId),
            FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY(groupId) REFERENCES groups(id) ON DELETE CASCADE
          );
        ''');

        /*

        Session

          - A session represents a scheduled study event within a group

          Notes for later (ideal, time permitting):
            - Sessions are deleted after their end time has passed
            - Sessions can only be scheduled within X amount of time in the future (e.g., 30 days)

        */
        await d.execute('''
          CREATE TABLE sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            groupId INTEGER NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            start INTEGER NOT NULL,
            end INTEGER NOT NULL,
            location TEXT NOT NULL,
            maxAttendees INTEGER NOT NULL,
            attendees INTEGER NOT NULL DEFAULT 0,
            creatorId INTEGER NOT NULL, -- dormant field
            created INTEGER NOT NULL,
            FOREIGN KEY(groupId) REFERENCES groups(id) ON DELETE CASCADE,
            FOREIGN KEY(creatorId) REFERENCES users(id) ON DELETE CASCADE
          );
        ''');

        await d.execute('''
          CREATE TABLE session_members(
            userId INTEGER NOT NULL,
            sessionId INTEGER NOT NULL,
            joinedAt INTEGER NOT NULL,
            PRIMARY KEY(userId, sessionId),
            FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY(sessionId) REFERENCES sessions(id) ON DELETE CASCADE
          );
        ''');


        /*

        Message

          - A message is a single chat message
          - A message has a:
            - author (mandatory)
            - group (mandatory)
            - session (optional)
            all messages are shown within the group chat, but we can filter by session

          Notes for later (ideal, time permitting):
            - Time permitting, color-coding messages by sessions should be considered
              (or alternative to allow for readability)

        */
        await d.execute('''
          CREATE TABLE messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            groupId INTEGER NOT NULL,
            sessionId INTEGER,
            creatorId INTEGER NOT NULL,
            text TEXT NOT NULL,
            date INTEGER NOT NULL,
            FOREIGN KEY(groupId) REFERENCES groups(id) ON DELETE CASCADE,
            FOREIGN KEY(sessionId) REFERENCES sessions(id) ON DELETE CASCADE,
            FOREIGN KEY(creatorId) REFERENCES users(id) ON DELETE CASCADE
          );
        ''');


        await d.execute('''
          CREATE TABLE notifications(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId INTEGER NOT NULL,
            groupId INTEGER NOT NULL,
            messageId INTEGER NOT NULL,
            created INTEGER NOT NULL,
            read INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY(groupId) REFERENCES groups(id) ON DELETE CASCADE,
            FOREIGN KEY(messageId) REFERENCES messages(id) ON DELETE CASCADE
          );
        ''');

        // insert AI generated demo data into the database (only seeds if no user exist (empty db))
        await DemoSeed.seed(d);
      },

      onUpgrade: (d, oldV, newV) async {
        if (oldV < 4) {
          d.execute('ALTER TABLE users ADD COLUMN latitude REAL NOT NULL DEFAULT 0;');
          d.execute('ALTER TABLE users ADD COLUMN longitude REAL NOT NULL DEFAULT 0;');
          d.execute('ALTER TABLE groups ADD COLUMN latitude REAL NOT NULL DEFAULT 0;');
          d.execute('ALTER TABLE groups ADD COLUMN longitude REAL NOT NULL DEFAULT 0;');
        }

        await d.execute('CREATE TABLE IF NOT EXISTS messages('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'groupId INTEGER NOT NULL,'
            'sessionId INTEGER,'
            'creatorId INTEGER NOT NULL,'
            'text TEXT NOT NULL,'
            'date INTEGER NOT NULL,'
            'FOREIGN KEY(groupId) REFERENCES groups(id) ON DELETE CASCADE,'
            'FOREIGN KEY(sessionId) REFERENCES sessions(id) ON DELETE CASCADE,'
            'FOREIGN KEY(creatorId) REFERENCES users(id) ON DELETE CASCADE'
            ');'
        );
        await d.execute('CREATE TABLE IF NOT EXISTS group_members('
            'userId INTEGER NOT NULL,'
            'groupId INTEGER NOT NULL,'
            'joinedAt INTEGER NOT NULL,'
            'PRIMARY KEY(userId, groupId),'
            'FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE,'
            'FOREIGN KEY(groupId) REFERENCES groups(id) ON DELETE CASCADE'
            ');'
        );
        await d.execute('CREATE TABLE IF NOT EXISTS session_members('
            'userId INTEGER NOT NULL,'
            'sessionId INTEGER NOT NULL,'
            'joinedAt INTEGER NOT NULL,'
            'PRIMARY KEY(userId, sessionId),'
            'FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE,'
            'FOREIGN KEY(sessionId) REFERENCES sessions(id) ON DELETE CASCADE'
            ');'
        );
        await d.execute('CREATE TABLE IF NOT EXISTS notifications('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'userId INTEGER NOT NULL,'
            'groupId INTEGER NOT NULL,'
            'messageId INTEGER NOT NULL,'
            'created INTEGER NOT NULL,'
            'read INTEGER NOT NULL DEFAULT 0,'
            'FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE,'
            'FOREIGN KEY(groupId) REFERENCES groups(id) ON DELETE CASCADE,'
            'FOREIGN KEY(messageId) REFERENCES messages(id) ON DELETE CASCADE'
            ');'
        );
      },
            
    );
    return _db!;
  }

  /*

    User Methods

  */

  Future<User> createUser() async 
  {
    final db_ = await db;
    final displayName = 'New User';
    final username = 'user_${_getRandomString(10)}';
    final password = _getRandomString(10);
    final authToken = _getRandomString(50);
    final latitude = 43.6532;
    final longitude = -79.3832;
    final now = DateTime.now().millisecondsSinceEpoch;

    final id = await db_.insert('users', {
        'displayName': displayName,
        'username': username,
        'password': password,
        'authToken': authToken,
        'latitude': latitude,
        'longitude': longitude,
        'created': now,
    });

    User user = User(
      id: id,
      displayName: displayName,
      username: username,
      password: password,
      authToken: authToken,
      latitude: latitude,
      longitude: longitude,
      created: now
    );

    print("CREATED NEW USER username=${user.username} id=${user.id}");

    return user;
  }

  //
  Future<bool> authenticateUserBool(User user) async
  {
    final db_ = await db;
    final rows = await db_.query(
      'users',
      where: 'id = ?',
      whereArgs: [user.id],
      limit: 1,
    );
    if (rows.isEmpty) return false; // user doesnt exist

    // authentication
    if (
      user.id == rows.first['id']
      // replace with username and password when implemented
      ) {
        return true;
      }
    // if authentication fails, 
    return false;

  }

  // This is vulnerable, when we implement the server we must secure it
  Future<User?> getUserById(int id) async
  {
    final db_ = await db;

    final rows = await db_.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<User?> getUserByUsernamePassword(String username, String password) async
  {
    final db_ = await db;

    final rows = await db_.query
    (
      'users',
      where: 'username = ? and password = ?',
      whereArgs: [username, password],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    
    return User.fromMap(rows.first);
  }

  Future<int?> getUserIdByUsername(String username) async
  {
    final db_ = await db;

    final rows = await db_.query(
      'users',
      columns: ['id'],
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  Future<void> setUserUsername(int userId, String newUsername) async
  {
    final db_ = await db;

    await db_.update(
      'users',
      {'username': newUsername},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> setUserPassword(int userId, String newPassword) async
  {
    final db_ = await db;

    await db_.update(
      'users',
      {'password': newPassword},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<String?> getUserDisplayName(int userId) async
  {
    final db_ = await db;
    final rows = await db_.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['displayName'] as String;
  }

  Future<void> setUserDisplayName(int userId, String newDisplayName) async
  {
    final db_ = await db;
    await db_.update(
      'users',
      {'displayName': newDisplayName},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> setUserCoordinates(int userId, double newLatitude, double newLongitude) async
  {
    final db_ = await db;
    await db_.update(
      'users',
      {
        'latitude': newLatitude,
        'longitude': newLongitude
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> deleteUser(int id) async
  {
    final db_ = await db;
    await db_.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /*

    Group Methods

  */

  // Fetches all groups (sorted by name)
  Future<List<StudyGroup>> getGroups
  (
    {
      String? text,
      String? subject,
      String? location,
      String? tag,
      int limit = 50,
      int? beforeCreated,
      int? afterCreated,
      
      // for geolocation
      double? nearLat,
      double? nearLng,
      double? withinKm,
    }
  ) async
  {
    final _db = await db;
    final iLimit = limit <= 0 ? 50 : (limit > 200 ? 200 : limit);
    // determine if we should use geolocation for selective search
    final useGeo = nearLat != null && nearLng != null && withinKm != null && withinKm > 0;

    final whereParts = <String>[];
    final whereArgs = <Object>[];

    if (text != null && text.trim().isNotEmpty) 
    {
      final like = '%${text.trim()}%';
      whereParts.add
      (
        '(name LIKE ? OR '
        'description LIKE ? OR '
        'subject LIKE ? OR '
        'location LIKE ? OR '
        'tags LIKE ?)',
      );
      whereArgs.addAll([like, like, like, like, like]);
    }
    // Subject
    if (subject != null && subject.trim().isNotEmpty)
    {
      whereParts.add('subject LIKE ?');
      whereArgs.add('%${subject.trim()}%');
    }
    // Location
    if (location != null && location.trim().isNotEmpty)
    {
      whereParts.add('location LIKE ?');
      whereArgs.add('%${location.trim()}%');
    }
    // Tag
    if (tag != null && tag.trim().isNotEmpty)
    {
      whereParts.add('tags LIKE ?');
      whereArgs.add('%${tag.trim()}%');
    }
    if (beforeCreated != null)
    {
      whereParts.add('created < ?');
      whereArgs.add(beforeCreated);
    }
    if (afterCreated != null)
    {
      whereParts.add('created > ?');
      whereArgs.add(afterCreated);
    }
    if (useGeo) {
      final dLat = withinKm / 111.32;

      final latRad = _deg2rad(nearLat!);
      final cosLat = cos(latRad).abs();
      final dLon = (cosLat < 1e-6) ? 180.0 : (withinKm / (111.32 * cosLat));

      whereParts.add('latitude BETWEEN ? AND ?');
      whereArgs.add(nearLat - dLat);
      whereArgs.add(nearLat + dLat);

      whereParts.add('longitude BETWEEN ? AND ?');
      whereArgs.add(nearLng - dLon);
      whereArgs.add(nearLng + dLon);
    }

    // 1000km limit
    final geolocationLimit = useGeo ? 1000 : iLimit;

    final rows = await _db.query
    (
      'groups',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereParts.isEmpty ? null : whereArgs,
      orderBy: 'created DESC, name ASC',
      limit: geolocationLimit,
    );

    final groups = rows.map(StudyGroup.fromMap).toList();

    if (!useGeo) return groups;

    // distance filter + sort by distance
    final pairs = <MapEntry<StudyGroup, double>>[];
    for (final g in groups)
    {
      final d = _haversineKm(nearLat, nearLng, g.latitude, g.longitude);
      if (d <= withinKm) {
        pairs.add(MapEntry(g, d));
      }
    }

    pairs.sort((a, b) => a.value.compareTo(b.value));

    return pairs.take(iLimit).map((e) => e.key).toList();
  }

  // Fetches group given by id
  Future<StudyGroup?> getGroupById(int id) async
  {
      final db_ = await db;
      final rows = await db_.query(
      'groups',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StudyGroup.fromMap(rows.first);
  }

  /// Inserts a new group into the database
  Future<StudyGroup> insertGroup(StudyGroup g) async
  {
    final dbInst = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final map = g.toMap()
    ..remove('id')
    ..['created'] ??= now;

    final newId = await dbInst.insert('groups', map);

    return StudyGroup(
      id: newId,
      name: g.name,
      description: g.description,
      subject: g.subject,
      location: g.location,
      latitude: g.latitude,
      longitude: g.longitude,
      tags: g.tags,
      creatorId: g.creatorId,
      created: map['created'] as int?,
      joined: false,
    );
  }

  /// Updates an existing group’s info
  Future<void> updateGroup(StudyGroup g) async
  {
    final db_ = await db;
    await db_.update(
    'groups', {
      'name': g.name,
      'description': g.description,
      'subject': g.subject,
      'location': g.location,
      'latitude': g.latitude,
      'longitude': g.longitude,
      'tags': g.tags.join('|'),
    },
    where: 'id = ?',
    whereArgs: [g.id],
  );
  }

  Future<void> setJoinedGroup(int userId, int groupId, bool joined) async
  {
    final db_ = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    // transaction to prevent partial completions
    await db_.transaction((transaction) async {
      if (joined == true)
      {
        await transaction.insert
        (
          'group_members',
          {
            'userId': userId,
            'groupId': groupId,
            'joinedAt': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        return;
      }


      // if user is leaving the group
      {
        // get all sessions the user has joined in inside the group they are leaving
        final sessionRows = await transaction.rawQuery
        (
          'SELECT sm.sessionId AS sessionId '
          'FROM session_members sm '
          'JOIN sessions s ON s.id = sm.sessionId '
          'WHERE sm.userId = ? AND s.groupId = ?',
          [userId, groupId],
        );
        // for each session the user is joined in inside the group they are leaving, make the user leave
        for (final r in sessionRows)
        {
          final sessionId = r['sessionId'] as int;
          final deleted = await transaction.delete
          (
            'session_members',
            where: 'userId = ? AND sessionId = ?',
            whereArgs: [userId, sessionId],
          );
          if (deleted > 0)
          {
            await transaction.rawUpdate
            (
              'UPDATE sessions '
              'SET attendees = CASE WHEN attendees > 0 THEN attendees - 1 ELSE 0 END '
              'WHERE id = ?',
              [sessionId],
            );
          }
        }

        // finally, make the user leave the group
        await transaction.delete
        (
          'group_members',
          where: 'userId = ? AND groupId = ?',
          whereArgs: [userId, groupId],
        );
      }
    });
  }

  Future<Set<int>> getJoinedGroupIds(int userId) async
  {
    final db_ = await db;
    final rows = await db_.query
    (
      'group_members',
      columns: ['groupId'],
      where: 'userId = ?',
      whereArgs: [userId],
    );
    return rows.map((r) => r['groupId'] as int).toSet();
  }

  Future<bool> isUserInGroup(int userId, int groupId) async
  {
    final db_ = await db;
    final rows = await db_.query
    (
      'group_members',
      columns: ['groupId'],
      where: 'userId = ? AND groupId = ?',
      whereArgs: [userId, groupId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Map<int, int>> getGroupMemberCounts(List<int> groupIds) async
  {
    if (groupIds.isEmpty) return <int, int>{};

    final db_ = await db;
    final placeholders = List.filled(groupIds.length, '?').join(',');

    final rows = await db_.rawQuery
    (
      'SELECT groupId, COUNT(*) AS count '
      'FROM group_members '
      'WHERE groupId IN ($placeholders) '
      'GROUP BY groupId',
      groupIds,
    );

    final result = <int, int>{};
    for (final row in  rows)
    {
      final gid = row['groupId'] as int;
      final cnt = row['count'] as int;
      result[gid] = cnt;
    }
    return result;
  }

  /// Deletes a group by ID
  Future<void> deleteGroup(int id) async
  {
    (await db).delete('groups', where: 'id=?', whereArgs: [id]);
  }

  /*

    Session Methods

  */

  /// Returns all sessions belonging to a specific group
  Future<List<StudySession>> getSessionsForGroup
  (
    int groupId,
    {
      String? text,
      String? location,
      int? startFromMs,
      int? startToMs,
      int? endFromMs,
      int? endToMs,
      int limit = 50,
    }
  ) async
  {
    final _db = await db;

    final iLimit = limit <= 0 ? 50 : (limit > 100 ? 100 : limit);

    final whereParts = <String>['groupId = ?'];
    final whereArgs = <Object>[groupId];

    // generic search
    if (text != null && text.trim().isNotEmpty)
    {
      final like = '%${text.trim()}%';
      whereParts.add('(title like ? OR description like ?)');
      whereArgs.addAll([like, like]);
    }
    // location
    if (location != null && location.trim().isNotEmpty)
    {
      whereParts.add('location LIKE ?');
      whereArgs.add('%${location.trim()}%');
    }
    // start time
    if (startFromMs != null)
    {
      whereParts.add('start >= ?');
      whereArgs.add(startFromMs);
    }
    if (startToMs != null)
    {
      whereParts.add('start <= ?');
      whereArgs.add(startToMs);
    }
    // end time
    if (endFromMs != null)
    {
      whereParts.add('end >= ?');
      whereArgs.add(endFromMs);
    }
    if (endToMs != null)
    {
      whereParts.add('end <= ?');
      whereArgs.add(endToMs);
    }

    final rows = await _db.query
    (
      'sessions',
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'start ASC, title ASC',
      limit: iLimit,
    );

    return rows.map(StudySession.fromMap).toList();
  }

  // Fetches group given by id
  Future<StudySession?> getSessionById(int id) async
  {
      final db_ = await db;
      final rows = await db_.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StudySession.fromMap(rows.first);
  }

  /// Adds a new study session
  Future<void> addSession(StudySession s) async
  {
    final dbInst = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final map = s.toMap()
      ..remove('id')
      ..['created'] = now;

    dbInst.insert('sessions', map);
  }

  Future<void> setJoinedSession(int userId, int sessionId, bool joined) async
  {
    final db_ = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (joined == true)
    {
      // add session membership
      final inserted = await db_.insert
      (
        'session_members',
        {
          'userId': userId,
          'sessionId': sessionId,
          'joinedAt': now
        },
        conflictAlgorithm: ConflictAlgorithm.ignore
      );
      if (inserted != 0)
      {
        await db_.rawUpdate('UPDATE sessions SET attendees = attendees + 1 WHERE id = ?',[sessionId]);
      }
    }
    else
    {
      // remove session membership
      final deleted = await db_.delete
      (
        'session_members',
        where: 'userId = ? AND sessionId = ?',
        whereArgs: [userId, sessionId],
      );

      if (deleted > 0)
      {
        await db_.rawUpdate
        (
          'UPDATE sessions '
          'SET attendees = CASE WHEN attendees > 0 THEN attendees - 1 ELSE 0 END '
          'WHERE id = ?',
          [sessionId],
        );
      }
    }
  }

  Future<Set<int>> getJoinedSessionIdsForUserInGroup(int userId, int groupId) async
  {
    final db_ = await db;
    final rows = await db_.rawQuery
    (
      'SELECT sm.sessionId AS sessionId '
      'FROM session_members sm '
      'JOIN sessions s ON s.id = sm.sessionId '
      'WHERE sm.userId = ? AND s.groupId = ?',
      [userId, groupId],
    );

    return rows.map((r) => r['sessionId'] as int).toSet();
  }

  /// Deletes a specific session
  Future<void> deleteSession(int id) async
  {
    (await db).delete('sessions', where: 'id=?', whereArgs: [id]);
  }

  /// Increments attendee count for a session (e.g., when someone joins)
  /// This probably shouldnt be counted this way (REMOVE LATER, MAYBE)
  Future<void> incrementAttendees(int id, {int delta = 1}) async
  {
    await (await db).rawUpdate(
      'UPDATE sessions SET attendees = attendees + ? WHERE id = ?',
      [delta, id],
    );
  }

  /*
    Messages
  */

  /// Loads all messages
  Future<List<ChatMessage>> getMessages(
    int groupId,
    {
      int limit = 50,
      int? beforeMs,
      int? afterMs,
      String? text,
      int? sessionId,
      int? creatorId
    }
  ) async
  {
    final db_ = await db;

    final iLimit =limit <= 0 ? 50 : (limit > 200 ? 200 : limit);

    final whereParts = <String>['groupId = ?'];
    final whereArgs = <Object>[groupId];

    // session filter
    if (sessionId != null)
    {
      whereParts.add('sessionId = ?');
      whereArgs.add(sessionId);
    }

    // creator filter
    if (creatorId != null)
    {
      whereParts.add('creatorId = ?');
      whereArgs.add(creatorId);
    }

    // time filters
    if (beforeMs != null)
    {
      whereParts.add('date < ?');
      whereArgs.add(beforeMs);
    }
    if (afterMs != null)
    {
      whereParts.add('date > ?');
      whereArgs.add(afterMs);
    }

    // message context search
    if (text != null && text.trim().isNotEmpty)
    {
      whereParts.add('text LIKE ?');
      whereArgs.add('%${text.trim()}%');
    }

    final rows = await db_.query
    (
      'messages',
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'date DESC',
      limit: iLimit,
    );

    return rows.reversed.map(ChatMessage.fromMap).toList();
  }

  // Fetches group given by id
  Future<ChatMessage?> getMessageById(int id) async
  {
      final db_ = await db;
      final rows = await db_.query(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ChatMessage.fromMap(rows.first);
  }

  /// Adds a new chat message
  Future<int> addMessage(ChatMessage m) async
  {

    final dbInst = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final map = m.toMap()
      ..remove('id')
      ..['date'] = now;

    final id = dbInst.insert('messages', map);
    return id;
  }

  /// Deletes a chat message by ID
  Future<void> deleteMessage(int id) async
  {
    (await db).delete('messages', where: 'id=?', whereArgs: [id]);
  }

  /*
    Notifications
  */
    Future<void> insertNotificationsForNewMessage
    (
    int groupId,
    int messageId,
    int creatorId
    ) async
    {
    final db_ = await db;

    // gather group members
    final members = await db_.query
    (
      'group_members',
      columns: ['userId'],
      where: 'groupId = ?',
      whereArgs: [groupId]
    );

    if (members.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    for (final row in members)
    {
      final userId = row['userId'] as int;
      // if (userId == creatorId) continue; // dont notify the creator of the message

      await db_.insert('notifications',
        {
          'userId': userId,
          'groupId': groupId,
          'messageId': messageId,
          'created': now,
          'read': 0
        }
      );
    }

    print('[NOTIF] groupId=$groupId messageId=$messageId creatorId=$creatorId');
    print('[NOTIF] members=${members.length} ids=${members.map((r)=>r['userId']).toList()}');
  }

  Future<List<Map<String, Object?>>> getUnreadNotificationsForUser
  (
    int userId,
    {
    int? sinceMs,
    int limit = 50
    }
  ) async {
    final db_ = await db;

    final whereArgs = <Object>[userId];
    final whereExtra = <String>[];

    if (sinceMs != null) {
      whereExtra.add('n.created > ?');
      whereArgs.add(sinceMs);
    }

    final whereClause = [
      'n.userId = ?',
      'n.read = 0',
      ...whereExtra
    ].join(' AND ');

    final sql = '''
      SELECT
        n.id AS notifId,
        n.created AS notifCreated,
        m.id AS messageId,
        m.text AS messageText,
        m.date AS messageDate,
        g.id AS groupId,
        g.name AS groupName
      FROM notifications n
      JOIN messages m ON m.id = n.messageId
      JOIN groups g   ON g.id = n.groupId
      WHERE $whereClause
      ORDER BY n.created DESC
      LIMIT ?
    ''';

    whereArgs.add(limit);

    final rows = await db_.rawQuery(sql, whereArgs);
    return rows;
  }

  Future<void> markNotificationsAsRead(List<int> notifIds) async
  {
    if (notifIds.isEmpty)
    {
      print("NOTIFICATION IDS EMPTY");
      return;
    }
    final db_ = await db;

    final placeholders = List.filled(notifIds.length, '?').join(',');
    await db_.rawUpdate('UPDATE notifications SET read = 1 WHERE id IN ($placeholders)',notifIds);
    print("RAW UPDATE");
  }

  /*
    Helpers for location based search

    Please note that these 2 functions were made with the help of AI, as lat/lng search is very complex
  */

  double _deg2rad(double deg) => deg * (pi / 180.0);
  double _haversineKm(double lat1, double lon1, double lat2, double lon2)
  {
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = pow(sin(dLat / 2), 2) + cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }
}
