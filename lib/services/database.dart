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

  /// Lazily initializes the database if not already open
  Future<Database> get db async {
    if (_db != null) return _db!;

    final path = join(await getDatabasesPath(), 'study_connect_v2.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (d, v) async {
        // create main tables
        await d.execute('''
          CREATE TABLE groups(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            subject TEXT NOT NULL,
            meetingTime TEXT NOT NULL,
            location TEXT NOT NULL,
            tags TEXT NOT NULL,
            joined INTEGER NOT NULL
          );
        ''');

        await d.execute('''
          CREATE TABLE sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            groupId INTEGER NOT NULL,
            title TEXT NOT NULL,
            start TEXT NOT NULL,
            end TEXT NOT NULL,
            location TEXT NOT NULL,
            maxAttendees INTEGER NOT NULL,
            attendees INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(groupId) REFERENCES groups(id) ON DELETE CASCADE
          );
        ''');

        await d.execute('''
          CREATE TABLE messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            groupId INTEGER NOT NULL,
            author TEXT NOT NULL,
            text TEXT NOT NULL,
            ts TEXT NOT NULL,
            FOREIGN KEY(groupId) REFERENCES groups(id) ON DELETE CASCADE
          );
        ''');
      },
      onUpgrade: (d, oldV, newV) async {
        // safeguard: recreate missing message table if needed
        await d.execute('CREATE TABLE IF NOT EXISTS messages('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'groupId INTEGER NOT NULL,'
            'author TEXT NOT NULL,'
            'text TEXT NOT NULL,'
            'ts TEXT NOT NULL,'
            'FOREIGN KEY(groupId) REFERENCES groups(id) ON DELETE CASCADE'
            ');');
      },
    );
    return _db!;
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
  Future<int> addGroup(StudyGroup g) async =>
      (await db).insert('groups', g.toMap()..remove('id'));

  /// Updates an existing group’s info
  Future<int> updateGroup(StudyGroup g) async =>
      (await db).update('groups', g.toMap(), where: 'id=?', whereArgs: [g.id]);

  /// Deletes a group by ID
  Future<int> deleteGroup(int id) async =>
      (await db).delete('groups', where: 'id=?', whereArgs: [id]);

  /// Marks whether the user has joined or left a group
  Future<void> setJoined(int groupId, bool joined) async {
    await (await db).update(
      'groups',
      {'joined': joined ? 1 : 0},
      where: 'id=?',
      whereArgs: [groupId],
    );
  }

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
  Future<int> addSession(StudySession s) async =>
      (await db).insert('sessions', s.toMap());

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
  Future<int> addMessage(ChatMessage m) async =>
      (await db).insert('messages', m.toMap()..remove('id'));

  /// Deletes a chat message by ID
  Future<int> deleteMessage(int id) async =>
      (await db).delete('messages', where: 'id=?', whereArgs: [id]);
}
