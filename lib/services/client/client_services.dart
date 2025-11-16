// import 'package:path/path.dart';
import 'package:study_connect_shared/models/user.dart';
import 'package:study_connect_shared/models/group.dart';
import 'package:study_connect_shared/models/session.dart';
import 'package:study_connect_shared/models/chat_message.dart';
import 'client_api.dart';
import 'dart:convert';

/*

  Client service for StudyConnect

  NOTE: later, we either need to send full user authentication info with sensitive
    operations, or use some sort of timed session key. Many functions currently do not
    properly validate the authenticity of actions.

*/
class ClientService {
  static final ClientService _i = ClientService._();  // singleton
  ClientService._();
  factory ClientService() => _i;

  // Client API grabbing so we can make calls to the server
  final ApiClient _api = ApiClient.instance;


  User? currentUser;


  /*

    Core app helpers

  */
  /*
    ap<String, String>::authHeaders()

    helper to get headers for client-server user authorization
  */
  Map<String, String> _authHeaders()
  {
    if (currentUser == null)
    {
      throw Exception('No current user set for authenticated request.');
    }
    return
    {
      'X-User-Id': currentUser!.id.toString(),
      'X-Auth-Token': currentUser!.authToken,
    };
  }
  /*
    User::getLocalUser()

    helper to return the user data stored on device.
  */
  Future<User> _getLocalUser() async
  {
    // temporary, will fix when local (mobile device) storage is implemented
    return await createUser();
  }
  /*
    User::ensureUser()

    helper to ensure this device has a user logged on
  */
  Future<User> _ensureUser() async 
  {
    if (currentUser != null) return currentUser!;

    final user = await createUser();
    currentUser = user;
    return user;
  }





  /* 

    User methods
    
  */
  /*
    User::createUser()

    calls server to create a brand new user. Returns said new user.
  */
  Future<User> createUser() async {
    final result = await _api.postJson('/users', <String, dynamic>{});

    if (result.statusCode != 201 && result.statusCode != 200) 
    {
      throw Exception('Failed to create user: ${result.statusCode}');
    }

    final map = Map<String, Object>.from(jsonDecode(result.body) as Map<String, dynamic>);
    final user = User.fromMap(map);
    currentUser = user; // set the newly created user as the current user for the device
    return user;
  }
  /*
    String?::getUserDisplayName(int userId)

    calls server to fetch the displayName of a user.

    - int userId: Id of the displayName of the user.
  */
  Future<String?> getUserDisplayName(int userId) async {
    final result = await _api.get('/users/$userId');

    if (result.statusCode == 404) return null;
    if (result.statusCode != 200) throw Exception('Failed to get user: ${currentUser!.id}');

    final map = Map<String, Object?>.from(jsonDecode(result.body) as Map<String, dynamic>);
    return map['displayName'] as String?;
  }
  /*
    void::setUserDisplayName(String newDisplayName)

    calls server to set the displayName of the current user.

    - String newDisplayName: new name of the current user.
  */
  Future<void> setUserDisplayName(String newDisplayName) async {
    if (currentUser == null) {
      throw Exception('No current user on this device');
    }

    final result = await _api.putJson(
      '/users/${currentUser!.id}',
      {'displayName': newDisplayName},
      headers: _authHeaders()
    );

    if (result.statusCode != 200) throw Exception('Failed to rename user: ${currentUser!.id}');

    // update the local user data to use the new diplay name
    currentUser = User
    (
      id: currentUser!.id,
      displayName: newDisplayName,
      username: currentUser!.username,
      password: currentUser!.password,
      authToken: currentUser!.authToken,
      created: currentUser!.created,
    );
  }
  /*
    void::deleteUser()

    calls server to delete the current user
  */
  Future<void> deleteUser() async {
    if (currentUser == null) throw Exception('No current user on this device');

    final result = await _api.delete(
      '/users/${currentUser!.id}',
      headers: _authHeaders()
    );

    if (result.statusCode != 200 && result.statusCode != 204) 
    {
      throw Exception('Failed to delete user: ${result.statusCode}');
    }

    currentUser = null;
  }





  /*

    Groups

  */
  /*
    List<StudyGroup>::getGroups()

    calls server to get all groups (communities).

    NOTE: This is vulnerable in fetching too much data, must be fixed in the future. Maybe
      instead we can get all a certain number of groups at a time.
  */
  Future<List<StudyGroup>> getGroups() async
  {
    final result = await _api.get('/groups');

    if (result.statusCode != 200) throw Exception('Failed to fetch groups: ${result.statusCode}');

    final List<dynamic> groups = jsonDecode(result.body) as List<dynamic>;

    return groups
      .map((json) =>
        StudyGroup.fromMap(Map<String, Object?>.from(json as Map)))
      .toList();
  }
  /*
    void::addGroup(StudyGroup group)

    calls server to add a new group (community).

    - StudyGroup group: the new group.
  */
  Future<void> addGroup(StudyGroup group) async 
  {
    final body = group.toMap()
    ..remove('id')
    ..remove('creatorId')
    ..remove('created');

    if (group.creatorId == null) 
    {
      body['creatorId'] = currentUser!.id;
    }

    final result = await _api.postJson(
      '/groups',
      Map<String, dynamic>.from(body),
      headers: _authHeaders()
    );

    if (result.statusCode != 201 && result.statusCode != 200) 
    {
      throw Exception('Failed to add group: ${result.statusCode}');
    }
  }
  /*
    void::updateGroup(StudyGroup group)

    calls server to update a groups (communities) data.

    - StudyGroup group: the group to update.
  */
  Future<void> updateGroup(StudyGroup group) async
  {
    if (group.id == null) throw Exception('Group does not have an ID');

    final result = await _api.putJson('/groups/${group.id}',
      Map<String, dynamic>.from(group.toMap()),
      headers: _authHeaders()
    );

    if (result.statusCode != 200) 
    {
      throw Exception('Failed to update group: ${result.statusCode}');
    }
  }
  /*
    void::setJoined(int groupId, bool joined)

    calls server to set joined status of the current user in a group.

    - int groupId: the group the current user is joining.
    - bool joined: the joined status (true = joined, false = not joined).
  */
  Future<void> setJoined(int groupId, bool joined) async 
  {
    if (currentUser == null) throw Exception('No current user to join a group');

    final result = await _api.postJson('/groups/$groupId/joined',
      {
        'joined': joined,
        'userId': currentUser!.id
      },
      headers: _authHeaders()
    );

    if (result.statusCode != 200) 
    {
      throw Exception('Failed to join group: ${result.statusCode}');
    }
  }
  /*
    void::deleteGroup(int groupId)

    calls server to delete a group owned by the current user.

    - int groupId: the group to delete.
    
    NOTE: this currently doesnt match the users credentials against the group, so
      its vulnerable to misuse. Fix later.
  */
  Future<void> deleteGroup(int groupId) async 
  {
    if (currentUser == null) throw Exception('No current user to delete any groups of');

    final result = await _api.delete(
      '/groups/$groupId',
      headers: _authHeaders()
    );

    if (result.statusCode != 200 && result.statusCode != 204) 
    {
      throw Exception('Failed to delete group: ${result.statusCode}');
    }
  }

  /*

    Sessions

  */
  /*
    List<StudySession>::getSessionsForGroup(int groupId)

    calls server to fetch all sessions inside a group (community).

    - int groupId: the group that the sessions belong
    
    NOTE: This is vulnerable in fetching too much data, must be fixed in the future. Maybe
      instead we can get all a certain number of sessions at a time.
  */
  Future<List<StudySession>> getSessionsForGroup(int groupId) async 
  {
    final result = await _api.get('/groups/$groupId/sessions');

    if (result.statusCode != 200) 
    {
      throw Exception('Failed to fetch sessions: ${result.statusCode}');
    }

    final List<dynamic> decoded = jsonDecode(result.body) as List<dynamic>;

    return decoded.map((json) =>
      StudySession.fromMap(Map<String, Object?>.from(json as Map))).toList();
  }
  /*
    void::addSession(StudySession session)

    calls server to add a new session.

    - StudySession session: the session to add, is added to the group of groupId.

    NOTE: eventually, we need a solid way to set the creator (currently manual)
  */
  Future<void> addSession(StudySession session) async 
  {
    final body = session.toMap()..remove('id');

    final result = await _api.postJson(
      '/groups/${session.groupId}/sessions', 
      Map<String, dynamic>.from(body),
      headers: _authHeaders()
      );

    if (result.statusCode != 201 && result.statusCode != 200) 
    {
      throw Exception('Failed to add session: ${result.statusCode}');
    }
  }
  /*
    void::deleteSession(int sessionId)

    calls server to delete a session.

    - int sessionId: the id of the session to delete.

    NOTE: we must also pass user data (or use a session key) to ensure the session being
      deleted belongs to the user calling for its deletion.
  */
  Future<void> deleteSession(int sessionId) async 
  {
    if (currentUser == null) throw Exception('No current user to delete a session for');

    final result = await _api.delete(
      '/sessions/$sessionId',
      headers: _authHeaders()
    );

    if (result.statusCode != 200 && result.statusCode != 204) 
    {
      throw Exception('Failed to delete session: ${result.statusCode}');
    }
  }





  /*

    Messages

  */
  /*
    List<ChatMessage>::getMessages(int groupId)

    calls server to fetch all messages of a group (community).

    - int groupId: the id of the group which messages we want.

    NOTE: This is vulnerable in fetching too much data, must be fixed in the future. Maybe
      instead we can get all a certain number of messages at a time (maybe within a time
      line).
  */
  Future<List<ChatMessage>> getMessages(int groupId) async 
  {
    final result = await _api.get('/groups/$groupId/messages');

    if (result.statusCode != 200) 
    {
      throw Exception('Failed to fetch messages: ${result.statusCode}');
    }

    final List<dynamic> decoded = jsonDecode(result.body) as List<dynamic>;

    return decoded.map((json) =>
      ChatMessage.fromMap(Map<String, Object?>.from(json as Map))).toList();
  }
  /*
    void::addMessage(ChatMessage message)

    calls server to add a new message withing a group (community).

    - ChatMessage message: message to send. Sends to group described in message.groupId

    NOTE: We need a server-side way to set creatorId, not rely on the client
  */
  Future<void> addMessage(ChatMessage message) async 
  {
    final user = await _ensureUser();
    if (currentUser == null) throw Exception('No current user to add a message for');

    final body = message.toMap()
    ..remove('id')
    ..remove('creatorId')
    ..remove('date');

    final result = await _api.postJson(
      '/groups/${message.groupId}/messages',
      Map<String, dynamic>.from(body), // maybe just body
      headers: _authHeaders()
    );

    if (result.statusCode != 201 && result.statusCode != 200) 
    {
      throw Exception('Failed to add message: ${result.statusCode}');
    }
  }
  /*
    void::deleteMessage(int messageId)

    calls server to delete a message.

    - int messageId: id of the message to be deleted.

    NOTE: We need a server-side solution to ensure the message being deleted belongs to the
      user trying to delete it.
  */
  Future<void> deleteMessage(int messageId) async
  {
    if (currentUser == null) throw Exception('No current user to delete a message for');

    final result = await _api.delete(
      '/messages/$messageId',
      headers: _authHeaders()
      );

    if (result.statusCode != 200 && result.statusCode != 204) 
    {
      throw Exception('Failed to delete message: ${result.statusCode}');
    }
  }
}