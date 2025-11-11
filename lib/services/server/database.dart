import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/user.dart';
import '../../models/group.dart';
import '../../models/session.dart';
import '../../models/chat_message.dart';

// SQLite database handler for StudyConnect
// Handles all CRUD operations for:
//  - groups     → study communities
//  - sessions   → group study events
//  - messages   → per-group chat messages
class AppDb {
  static final AppDb _i = AppDb._();  // singleton instance
  AppDb._();
  factory AppDb() => _i;

  Database? _db; // holds the open database connection

  // Lazily initializes the database if not already open
  Future<Database> get db async {
    if (_db != null) return _db!;

    final path = join(await getDatabasesPath(), 'study_connect.db');
    // await deleteDatabase(path); // FOR TESTING ONLY: reset DB on each run

    _db = await openDatabase(
      path,
      version: 2,
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
      // },


        // ----------------------------------------------------------
        // DEMO SEED DATA (generated, just for example visuals)
        // ----------------------------------------------------------
        final now = DateTime.now();
        int ms(DateTime dt) => dt.millisecondsSinceEpoch;

        // Users
        final aliceId = await d.insert('users', {
          'displayName': 'Alice',
          'created': ms(now.subtract(const Duration(days: 10))),
        });
        final bobId = await d.insert('users', {
          'displayName': 'Bob',
          'created': ms(now.subtract(const Duration(days: 8))),
        });
        final charlieId = await d.insert('users', {
          'displayName': 'Charlie',
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

        // Sessions for Calculus group
        final calcSess1Id = await d.insert('sessions', {
          'groupId': calcGroupId,
          'title': 'Limit Laws Deep Dive',
          'start': ms(now.add(const Duration(days: 1, hours: 17))),
          'end': ms(now.add(const Duration(days: 1, hours: 19))),
          'location': 'Library 2nd Floor - Table 4',
          'maxAttendees': 8,
          'attendees': 3,
          'creatorId': aliceId,
          'created': ms(now.subtract(const Duration(days: 1))),
        });

        final calcSess2Id = await d.insert('sessions', {
          'groupId': calcGroupId,
          'title': 'Derivatives Practice Marathon',
          'start': ms(now.add(const Duration(days: 3, hours: 18))),
          'end': ms(now.add(const Duration(days: 3, hours: 20))),
          'location': 'Library 1st Floor - Study Room A',
          'maxAttendees': 10,
          'attendees': 5,
          'creatorId': aliceId,
          'created': ms(now),
        });

        // Sessions for CS group
        final csSess1Id = await d.insert('sessions', {
          'groupId': csGroupId,
          'title': 'Pointers & Memory Basics',
          'start': ms(now.add(const Duration(days: 2, hours: 16))),
          'end': ms(now.add(const Duration(days: 2, hours: 18))),
          'location': 'Lab B12',
          'maxAttendees': 12,
          'attendees': 4,
          'creatorId': bobId,
          'created': ms(now.subtract(const Duration(hours: 3))),
        });

        // A Psych session
        final psychSess1Id = await d.insert('sessions', {
          'groupId': psychGroupId,
          'title': 'Chapter 3: Memory & Learning',
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
        // safeguard: recreate missing message table if needed
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
            ');');
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
    final now = DateTime.now().millisecondsSinceEpoch;

    final id = await db_.insert('users', {
        'displayName': displayName,
        'created': now,
    });

    return User(id: id, displayName: displayName, created: now);
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

  // since we have not implemented passwords, this isnt true authentication
  Future<User?> authenticateUser(User user) async 
  {
    // authenticate user first to ensure proper credentials
    if (await authenticateUserBool(user) == false) { return null; }
    final db_ = await db;
    final rows = await db_.query(
      'users',
      where: 'id = ?',
      whereArgs: [user.id],
      limit: 1,
    );
    if (rows.isEmpty) return null; // user doesnt exist

    return User(
      id: rows.first['id'] as int, 
      displayName: rows.first['displayName'] as String, 
      created: rows.first['created'] as int
    );
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

  Future<void> setUserDisplayName(User user, String newDisplayName) async
  {
    if (await authenticateUserBool(user) == false) { return; }
    final db_ = await db;
    await db_.update(
      'users',
      {'displayName': newDisplayName},
      where: 'id = ?',
      whereArgs: [user.id],
    );
    // return (await getUserDisplayName(user.id) == newDisplayName); // if boolean method
  }

  Future<void> deleteUser(User user) async
  {
    if (await authenticateUserBool(user) == false) { return; }
    final db_ = await db;
    await db_.delete(
      'users',
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  /*

    Group Methods

  */

  /// Fetches all groups (sorted by name)
  Future<List<StudyGroup>> getGroups() async {
    final rows = await (await db).query('groups', orderBy: 'name ASC');
    return rows.map(StudyGroup.fromMap).toList();
  }

  /// Inserts a new group into the database
  Future<void> addGroup(User user, StudyGroup g) async {
    if (await authenticateUserBool(user) == false) { return; }

    final dbInst = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final map = g.toMap()
    ..remove('id')
    ..['creatorId'] = user.id
    ..['created'] ??= now;

    dbInst.insert('groups', map);

    return;
    // return dbInst.insert('groups', map);
  }

  /// Updates an existing group’s info
  Future<void> updateGroup(User user, StudyGroup g) async
  {
    // BAD: we need to ensure the user is the creator of the group
    if (await authenticateUserBool(user) == false) { return; }

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

  Future<void> setJoined(User user, int groupId, bool joined) async {
    // todo
    return;
  }

  /// Deletes a group by ID
  Future<void> deleteGroup(User user, int id) async
  {
    // BAD: we need to ensure the user is the creator of the group
    if (await authenticateUserBool(user) == false) { return; }

    (await db).delete('groups', where: 'id=?', whereArgs: [id]);
  }

  /*

    Group Methods

  */

  /// Returns all sessions belonging to a specific group
  Future<List<StudySession>> getSessionsForGroup(int groupId) async {
    final rows = await (await db).query(
      'sessions',
      where: 'groupId=?',
      whereArgs: [groupId],
      orderBy: 'start ASC',
    );
    return rows.map(StudySession.fromMap).toList();
  }

  /// Adds a new study session
  Future<void> addSession(User user, StudySession s) async {
    if (await authenticateUserBool(user) == false) { return; }
    final dbInst = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final map = s.toMap()
      ..remove('id')
      ..['creatorId'] = user.id
      ..['created'] = now;

    dbInst.insert('sessions', map);
  }

  /// Deletes a specific session
  Future<void> deleteSession(User user, int id) async {
    // BAD: we need to ensure the user is the creator of the session
    if (await authenticateUserBool(user) == false) { return; }

    (await db).delete('sessions', where: 'id=?', whereArgs: [id]);
  }

  /// Increments attendee count for a session (e.g., when someone joins)
  /// This probably shouldnt be counted this way (REMOVE LATER, MAYBE)
  Future<void> incrementAttendees(int id, {int delta = 1}) async {
    await (await db).rawUpdate(
      'UPDATE sessions SET attendees = attendees + ? WHERE id = ?',
      [delta, id],
    );
  }

  // --------------------------------------------------------------------------
  // MESSAGES (per-group chat)
  // --------------------------------------------------------------------------

  /// Loads all messages for a specific group (oldest → newest)
  Future<List<ChatMessage>> getMessages(int groupId) async {
    final rows = await (await db).query(
      'messages',
      where: 'groupId=?',
      whereArgs: [groupId],
      orderBy: 'date ASC',
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  /// Adds a new chat message
  Future<void> addMessage(User user, ChatMessage m) async {
    // should add future authentication (such as ensuring user is
    // part of the group the message is being sent into)
    if (await authenticateUserBool(user) == false) { return; }

    final dbInst = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final map = m.toMap()
      ..remove('id')
      ..['creatorId'] = user.id
      ..['date'] = now;

    dbInst.insert('messages', map);
  }

  /// Deletes a chat message by ID
  Future<void> deleteMessage(User user, int id) async {
    // BAD: we need to ensure the user is the creator of the message
    if (await authenticateUserBool(user) == false) { return; }

    (await db).delete('messages', where: 'id=?', whereArgs: [id]);
  }
}
