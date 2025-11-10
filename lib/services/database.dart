import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/group.dart';
import '../models/session.dart';
import '../models/chat_message.dart';

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

    final path = join(await getDatabasesPath(), 'study_connect_v2.db');
    await deleteDatabase(path); // FOR TESTING ONLY: reset DB on each run

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
            displayName TEXT NOT NULL
          );
        ''');
        await d.insert('users', {'displayName': 'You'});


      

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
            creatorID INTEGER NOT NULL,
            text TEXT NOT NULL,
            date INTEGER NOT NULL,
            FOREIGN KEY(groupId) REFERENCES groups(id) ON DELETE CASCADE,
            FOREIGN KEY(sessionId) REFERENCES sessions(id) ON DELETE CASCADE,
            FOREIGN KEY(creatorId) REFERENCES users(id) ON DELETE CASCADE
          );
        ''');
      },
      onUpgrade: (d, oldV, newV) async {
        // safeguard: recreate missing message table if needed
        await d.execute('CREATE TABLE IF NOT EXISTS messages('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'groupId INTEGER NOT NULL,'
            'sessionId INTEGER,'
            'creatorID INTEGER NOT NULL,'
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

  // TEMPORARY: retrieves the local user ID (there is only one user)
  // later we must implement proper displayName retrieval
  Future<int> getLocalUserId() async {
    final dbInst = await db;
    final rows = await dbInst.query('users', limit: 1);
    return rows.first['id'] as int;

  }

  // --------------------------------------------------------------------------
  // GROUPS
  // --------------------------------------------------------------------------

  /// Fetches all groups (sorted by name)
  Future<List<StudyGroup>> getGroups() async {
    final rows = await (await db).query('groups', orderBy: 'name ASC');
    return rows.map(StudyGroup.fromMap).toList();
  }

  /// Inserts a new group into the database
  Future<int> addGroup(StudyGroup g) async {
    final dbInst = await db;
    final userId = await getLocalUserId();

    final map = g.toMap()..remove('id');

    map['creatorId'] ??= userId;
    map['created'] ??= DateTime.now().millisecondsSinceEpoch;

    return dbInst.insert('groups', map);
  }

  /// Updates an existing group’s info
  Future<int> updateGroup(StudyGroup g) async =>
      (await db).update('groups', g.toMap(), where: 'id=?', whereArgs: [g.id]);

  /// Deletes a group by ID
  Future<int> deleteGroup(int id) async =>
      (await db).delete('groups', where: 'id=?', whereArgs: [id]);


  // --------------------------------------------------------------------------
  // SESSIONS
  // --------------------------------------------------------------------------

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
  Future<int> addSession(StudySession s) async {
    final dbInst = await db;
    final userId = await getLocalUserId();

    final map = s.toMap()..remove('id');

    map['creatorId'] ??= userId;
    map['created'] ??= DateTime.now().millisecondsSinceEpoch;

    return dbInst.insert('sessions', map);
  }

  /// Deletes a specific session
  Future<void> deleteSession(int id) async =>
      (await db).delete('sessions', where: 'id=?', whereArgs: [id]);

  /// Increments attendee count for a session (e.g., when someone joins)
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
      orderBy: 'ts ASC',
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  /// Adds a new chat message
  Future<int> addMessage(ChatMessage m) async {
    final dbInst = await db;
    final userId = await getLocalUserId();

    final map = m.toMap()..remove('id');

    map['authorId'] ??= userId;
    map['ts'] ??= DateTime.now().millisecondsSinceEpoch;

    return dbInst.insert('messages', map);
  }

  /// Deletes a chat message by ID
  Future<int> deleteMessage(int id) async =>
      (await db).delete('messages', where: 'id=?', whereArgs: [id]);
}
