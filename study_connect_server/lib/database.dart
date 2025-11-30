import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_connect_shared/models/user.dart';
import 'package:study_connect_shared/models/group.dart';
import 'package:study_connect_shared/models/session.dart';
import 'package:study_connect_shared/models/chat_message.dart';
import 'dart:math';

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
      version: 3,
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
        // await d.insert('users', {'displayName': 'You'});


      

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
      


        // DEMO SEED DATA (just for example visuals, remove later)
        final now = DateTime.now();
        int ms(DateTime dt) => dt.millisecondsSinceEpoch;

        // Users
        final aliceId = await d.insert('users', {
          'displayName': 'Alice',
          'username': 'alice',
          'password': 'alicepw',
          'authToken': 'seed_alice_token',
          'latitude': 43.6532,
          'longitude': -79.3832,
          'created': ms(now.subtract(const Duration(days: 10))),
        });

        final bobId = await d.insert('users', {
          'displayName': 'Bob',
          'username': 'bob',
          'password': 'bobpw',
          'authToken': 'seed_bob_token',
          'latitude': 43.6532,
          'longitude': -79.3832,
          'created': ms(now.subtract(const Duration(days: 8))),
        });

        final charlieId = await d.insert('users', {
          'displayName': 'Charlie',
          'username': 'charlie',
          'password': 'charliepw',
          'authToken': 'seed_charlie_token',
          'latitude': 43.6532,
          'longitude': -79.3832,
          'created': ms(now.subtract(const Duration(days: 5))),
        });

        // Groups
        final calcGroupId = await d.insert('groups', {
          'name': 'Calculus I - Study Squad',
          'description': 'Limits, derivatives, and exam prep for Calc I.',
          'subject': 'Math',
          'location': 'Library 2nd Floor',
          'tags': 'Math|Calculus|First Year',
          'creatorId': aliceId,
          'created': ms(now.subtract(const Duration(days: 9))),
        });

        final csGroupId = await d.insert('groups', {
          'name': 'Intro to Programming (C++)',
          'description': 'Weekly coding sessions and assignment help.',
          'subject': 'Computer Science',
          'location': 'Lab B12',
          'tags': 'CS|C++|Programming',
          'creatorId': bobId,
          'created': ms(now.subtract(const Duration(days: 7))),
        });

        final psychGroupId = await d.insert('groups', {
          'name': 'Psych 101 Review',
          'description': 'Review sessions before quizzes, share notes.',
          'subject': 'Psychology',
          'location': 'Room H310',
          'tags': 'Psychology|First Year',
          'creatorId': charlieId,
          'created': ms(now.subtract(const Duration(days: 6))),
        });

        final calcSess1Id = await d.insert('sessions', {
          'groupId': calcGroupId,
          'title': 'Limit Laws Deep Dive',
          'description': 'In-depth exploration of limit laws and their applications',
          'start': ms(now.add(const Duration(days: 1, hours: 17))),
          'end': ms(now.add(const Duration(days: 1, hours: 19))),
          'location': 'Library 2nd Floor - Table 4',
          'maxAttendees': 8,
          'attendees': 3,
          'creatorId': aliceId,
          'created': ms(now.subtract(const Duration(days: 1))),
        });

        await d.insert('sessions', {
          'groupId': calcGroupId,
          'title': 'Derivatives Practice Marathon',
          'description': 'Long practice session with worked examples and problem solving',
          'start': ms(now.add(const Duration(days: 3, hours: 18))),
          'end': ms(now.add(const Duration(days: 3, hours: 20))),
          'location': 'Library 1st Floor - Study Room A',
          'maxAttendees': 10,
          'attendees': 5,
          'creatorId': aliceId,
          'created': ms(now),
        });

        final csSess1Id = await d.insert('sessions', {
          'groupId': csGroupId,
          'title': 'Pointers & Memory Basics',
          'description': 'Beginner-friendly introduction to pointers, references, and memory allocation',
          'start': ms(now.add(const Duration(days: 2, hours: 16))),
          'end': ms(now.add(const Duration(days: 2, hours: 18))),
          'location': 'Lab B12',
          'maxAttendees': 12,
          'attendees': 4,
          'creatorId': bobId,
          'created': ms(now.subtract(const Duration(hours: 3))),
        });

        final psychSess1Id = await d.insert('sessions', {
          'groupId': psychGroupId,
          'title': 'Chapter 3: Memory & Learning',
          'description': 'Review session with Kahoot quiz covering memory and learning concepts',
          'start': ms(now.add(const Duration(days: 4, hours: 15))),
          'end': ms(now.add(const Duration(days: 4, hours: 17))),
          'location': 'Room H310',
          'maxAttendees': 15,
          'attendees': 6,
          'creatorId': charlieId,
          'created': ms(now),
        });

        // Messages in Calculus group
        await d.insert('messages', {
          'groupId': calcGroupId,
          'sessionId': calcSess1Id,
          'creatorId': aliceId,
          'text': 'Hey everyone! We\'ll focus on limits from section 2.3 tomorrow.',
          'date': ms(now.subtract(const Duration(days: 1, hours: 2))),
        });

        await d.insert('messages', {
          'groupId': calcGroupId,
          'sessionId': calcSess1Id,
          'creatorId': bobId,
          'text': 'Nice! I\'ll bring some practice problems.',
          'date': ms(now.subtract(const Duration(days: 1, hours: 1, minutes: 30))),
        });

        await d.insert('messages', {
          'groupId': calcGroupId,
          'sessionId': null,
          'creatorId': charlieId,
          'text': 'Anyone else struggling with epsilon-delta? Can we add that?',
          'date': ms(now.subtract(const Duration(hours: 6))),
        });

        // Messages in CS group
        await d.insert('messages', {
          'groupId': csGroupId,
          'sessionId': csSess1Id,
          'creatorId': bobId,
          'text': 'Today: pointers, references, and why your program segfaults 😈',
          'date': ms(now.subtract(const Duration(hours: 5))),
        });

        await d.insert('messages', {
          'groupId': csGroupId,
          'sessionId': csSess1Id,
          'creatorId': aliceId,
          'text': 'Can we also review dynamic arrays?',
          'date': ms(now.subtract(const Duration(hours: 4, minutes: 30))),
        });

        // Messages in Psych group
        await d.insert('messages', {
          'groupId': psychGroupId,
          'sessionId': psychSess1Id,
          'creatorId': charlieId,
          'text': 'We\'ll do a quick Kahoot on chapters 1-3 at the end.',
          'date': ms(now.subtract(const Duration(hours: 2))),
        });
      },




      onUpgrade: (d, oldV, newV) async {
        if (oldV < 3) {
          d.execute('ALTER TABLE users ADD COLUMN latitude REAL NOT NULL DEFAULT 0;');
          d.execute('ALTER TABLE users ADD COLUMN longitude REAL NOT NULL DEFAULT 0;');
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

    return User(
      id: id,
      displayName: displayName,
      username: username,
      password: password,
      authToken: authToken,
      latitude: latitude,
      longitude: longitude,
      created: now
    );
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

  /// Fetches all groups (sorted by name)
  Future<List<StudyGroup>> getGroups
  (
    {
      String? text,
      String? subject,
      String? location,
      String? tag,
      int limit = 50,
      int? beforeCreated,
      int? afterCreated
    }
  ) async
  {
    final _db = await db;
    final iLimit = limit <= 0 ? 50 : (limit > 200 ? 200 : limit);

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

    final rows = await _db.query
    (
      'groups',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereParts.isEmpty ? null : whereArgs,
      orderBy: 'created DESC, name ASC',
      limit: iLimit,
    );

    return rows.map(StudyGroup.fromMap).toList();
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
  Future<void> insertGroup(StudyGroup g) async
  {
    final dbInst = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final map = g.toMap()
    ..remove('id')
    ..['created'] ??= now;

    dbInst.insert('groups', map);

    return;
    // return dbInst.insert('groups', map);
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

    if (joined == true)
    {
      await db_.insert
      (
        'group_members',
        {
          'userId': userId,
          'groupId': groupId,
          'joinedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    else
    {
      await db_.delete
      (
        'group_members',
        where: 'userId = ? AND groupId = ?',
        whereArgs: [userId, groupId],
      );
    }
  }

  /// Deletes a group by ID
  Future<void> deleteGroup(int id) async
  {
    (await db).delete('groups', where: 'id=?', whereArgs: [id]);
  }

  /*

    Group Methods

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
      if (userId == creatorId) continue; // dont notify the creator of the message

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
    if (notifIds.isEmpty) return;
    final db_ = await db;

    final placeholders = List.filled(notifIds.length, '?').join(',');
    await db_.rawUpdate('UPDATE notifications SET read = 1 WHERE id IN ($placeholders)',notifIds);
  }


}
