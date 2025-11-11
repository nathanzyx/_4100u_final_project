import '../../models/user.dart';
import '../../models/group.dart';
import '../../models/session.dart';
import '../../models/chat_message.dart';
import '../server/database.dart';

/*

  Client service for StudyConnect

  - Handles all client side calls which interact with the server database

  Note:
    - We have not yet implemented server functionality, so this currently
      acts as unecessary reiterative pass-through to ../server/database.dart
      instead of using server calls.


*/
class ClientService {
  static final ClientService _i = ClientService._();  // singleton instance
  ClientService._();
  factory ClientService() => _i;

  final AppDb _db = AppDb(); // server database handler

  User? currentUser;
  // temporary, since we have no real permanance yet
  // eventually, we retreive user data stored on device (and maybe authenticate it)
  User get currentUser_ {
    if (currentUser == null) {
      throw StateError('ClientService: user not initialized.');
    }
    return currentUser!;
  }
  /// Called once at app startup to create a user for this device/session.
  /// (In future: load from storage or real auth instead.)
  Future<void> ensureUserInitialized() async {
    if (currentUser != null) return;
    currentUser = await _db.createUser();
    await setUserDisplayName("username123");
  }

  // User methods
    // For first-time users, create a new user in the database and return their ID and generic display name
  Future<User> createUser() async {
    final User user = await _db.createUser();
    return user;
  }
    // simple user authentication (not used since user functionality is limited)
    // Uncomment if we ever implement user passwords
  Future<User?> authenicateUser() async {
    return await _db.authenticateUser(currentUser!);
  }
  Future<String?> getUserDisplayName(int userId) async {
    final String? displayName = await _db.getUserDisplayName(userId);
    return displayName;
  }
  Future<void> setUserDisplayName( String newDisplayName) async {
    // if we later implement passwords, we can add that as an argument here
    await _db.setUserDisplayName(currentUser!, newDisplayName);
  }
  Future<void> deleteUser() async {
    // if we later implement passwords, we can add that as an argument here
    await _db.deleteUser(currentUser!);
  }


  // Group methods
  Future<List<StudyGroup>> getGroups() => _db.getGroups();
    // if we later implement user authentication, we can add userId and password as an argument here
  Future<void> addGroup(StudyGroup group) => _db.addGroup(currentUser!, group);
    // if we later implement user authentication, we can add userId and password as an argument here
  Future<void> updateGroup(StudyGroup group) => _db.updateGroup(currentUser!, group);
    // if we later implement user authentication, we can add userId and password as an argument here
  Future<void> setJoined(int groupId, bool joined) => _db.setJoined(currentUser!, groupId, joined);
  Future<void> deleteGroup(int groupId) => _db.deleteGroup(currentUser!, groupId);

  // Session methods
  Future<List<StudySession>> getSessionsForGroup(int groupId) => _db.getSessionsForGroup(groupId);
    // if we later implement user authentication, we can add userId and password as an argument here
  Future<void> addSession(StudySession session) => _db.addSession(currentUser!, session);
    // if we later implement user authentication, we can add userId and password as an argument here
  Future<void> deleteSession(int sessionId) => _db.deleteSession(currentUser!, sessionId);

  // Chat message methods
  Future<List<ChatMessage>> getMessages(int groupId) => _db.getMessages(groupId);
    // if we later implement user authentication, we can add userId and password as an argument here
  Future<void> addMessage(ChatMessage message) => _db.addMessage(currentUser!, message);
  Future<void> deleteMessage(int messageId) => _db.deleteMessage(currentUser!, messageId);
}