// import 'package:path/path.dart';
import 'package:study_connect_shared/models/user.dart';
import 'package:study_connect_shared/models/group.dart';
import 'package:study_connect_shared/models/session.dart';
import 'package:study_connect_shared/models/chat_message.dart';
import 'client_api.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_connect/services/notification_service.dart';
import 'dart:async';

/*
  Helper class for cases where an account being sent with 'PUT' tries to use an existing username.
*/
class UsernameTakenException implements Exception
{
  final String message;
  UsernameTakenException([this.message = 'Username already taken']);
  @override
  String toString() => message;
}


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
  final ApiClient _api = ApiClient.instance;
  
  // For notifications
  Timer? _notificationTimer;
  int? _lastNotificationCheckMs;

  // local user
  User? currentUser;
  Future<User> ensureUser() => _ensureUser();

  // local user location checkers (determine whether we need to prompt user to enter their location)
  bool _createdNewInLastEnsure = false;
  bool get createdNewInLastEnsure => _createdNewInLastEnsure;

  static const _userIdKey = 'local_user_id';
  static const _userDisplayNameKey = 'local_user_displayName';
  static const _userUsernameKey = 'local_user_username';
  static const _userPasswordKey = 'local_user_password';
  static const _userAuthTokenKey = 'local_user_authToken';
  static const _userLatitudeKey = 'local_user_latitude';
  static const _userLongitudeKey = 'local_user_longitude';
  static const _userCreatedKey = 'local_user_created';
  // global app settings
  static const _appDarkModeKey = 'app_dark_mode';

  /*

    Core app helpers

  */
  Map<String, String> _authHeadersForUser(User u)
  {
    return 
    {
      'X-User-Id': u.id.toString(),
      'X-Auth-Token': u.authToken.toString()
    };
  }
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
    return _authHeadersForUser(currentUser!);
  }
  /*
    User::getLocalUser()

    helper to return the user data stored on device.
  */
  Future<User?> _getLocalUserFromStorage() async
  {
    final l = await SharedPreferences.getInstance();

    final id = l.getInt(_userIdKey);
    final displayName = l.getString(_userDisplayNameKey);
    final username = l.getString(_userUsernameKey);
    final password = l.getString(_userPasswordKey);
    final authToken = l.getString(_userAuthTokenKey);
    final latitude = l.getDouble(_userLatitudeKey);
    final longitude = l.getDouble(_userLongitudeKey);
    final created = l.getInt(_userCreatedKey);

    // Expect local to hold all user data, if not, assume no user on local device (set null)
    if 
    (
      id == null ||
      displayName == null ||
      username == null ||
      password == null ||
      authToken == null ||
      latitude == null ||
      longitude == null ||
      created == null
    ) { return null; }

    return User
    (
      id: id,
      displayName: displayName,
      username: username,
      password: password,
      authToken: authToken,
      latitude: latitude,
      longitude: longitude,
      created: created
    );
  }
  /*
    void::_saveLocalUserToStorage(User user)

    helper to save the local user data to the device.
  */
  Future<void> _saveLocalUserToStorage(User user) async
  {
    final l = await SharedPreferences.getInstance();
    await l.setInt(_userIdKey, user.id);
    await l.setString(_userDisplayNameKey, user.displayName);
    await l.setString(_userUsernameKey, user.username);
    await l.setString(_userPasswordKey, user.password);
    await l.setString(_userAuthTokenKey, user.authToken);
    await l.setDouble(_userLatitudeKey, user.latitude);
    await l.setDouble(_userLongitudeKey, user.longitude);
    await l.setInt(_userCreatedKey, user.created);
  }
  /*
    void::_clearLocalUserFromStorage()

    helper to erase local user from the device storage.
    (clears persistant user, not hot-path client side user)
  */
  Future<void> _clearLocalUserFromStorage() async 
  {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userDisplayNameKey);
    await prefs.remove(_userUsernameKey);
    await prefs.remove(_userPasswordKey);
    await prefs.remove(_userAuthTokenKey);
    await prefs.remove(_userLatitudeKey);
    await prefs.remove(_userLongitudeKey);
    await prefs.remove(_userCreatedKey);
  }
  /*
    User::_ensureUser()

    helper to ensure a user is registered to the device.
  */
  Future<User> _ensureUser() async
  {
    _createdNewInLastEnsure = false;
    print("CHECKING LOCALIZED USER DATA");
    // hot-path user check first
    if (currentUser != null) {
      final refreshed = await _validateUserWithServer(currentUser!);
      if (refreshed != null) 
      {
        print("CURRENT USER IS VALID");
        currentUser = refreshed;
        await _saveLocalUserToStorage(refreshed);
        return refreshed;
      }
    }

    // if live client user isn't valid
    final localUserFromStorage = await _getLocalUserFromStorage();
    if (localUserFromStorage != null)
    {
      final refreshed = await _validateUserWithServer(localUserFromStorage);
      if (refreshed != null) 
      {
        print("VALID USER FOUND LOCALLY");
        currentUser = refreshed;
        await _saveLocalUserToStorage(refreshed);
        return refreshed;
      }
    }

    print("NO VALID USER FOUND LOCALLY, CREATING NEW USER...");
    // If we cannot retreive a valid account locally, create a new account
    // (We assume this is the first time this device is using the app)
    _createdNewInLastEnsure = true; // let app know that user should be prompted to input location
    final newUser = await createUser();
    currentUser = newUser;
    await _saveLocalUserToStorage(newUser);
    return newUser;
  }
  /*
    bool::_validateUserWithServer(User)

    helper to validate a users credentials with the server.
  */
  Future<User?> _validateUserWithServer(User user) async
  {
    try 
    {
      final result = await _api.get(
        '/users/auth',
        headers: _authHeadersForUser(user)
      );

      if (result.statusCode != 200) 
      {
        return null;
      }
      final map = Map<String, Object?>.from(jsonDecode(result.body) as Map<String, dynamic>);
      return User.fromMap(map);
    }
    catch (e) 
    {
      return null;
    }
  }
  /*
    void::resetLocalUser()

    helper to forget the current user on this device WITHOUT calling the server.
    next time ensureUser() runs, a new user will be created.
  */
  Future<void> resetLocalUser() async
  {
    currentUser = null;
    await _clearLocalUserFromStorage();
  }

  /*
    bool::loadDarkModePreference()

    helper to load the saved dark-mode flag from local storage.
    defaults to false (light theme) if not set.
  */
  Future<bool> loadDarkModePreference() async
  {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_appDarkModeKey) ?? false;
  }
  /*
    void::saveDarkModePreference(bool enabled)

    helper to save the dark-mode flag to local storage.
  */
  Future<void> saveDarkModePreference(bool enabled) async
  {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appDarkModeKey, enabled);
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
    currentUser = user; // set the newly created user as the current user for the device memory
    await _saveLocalUserToStorage(user); // set the newly created user for the devices persistance storage
    return user;
  }
  /*
    User::getUser()

    method to acces private _getLocalUserFromStorage() method
  */
  Future<User?> getUser() async {
    return await _getLocalUserFromStorage();
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

    // update the local user data to use the new display name
    currentUser = User
    (
      id: currentUser!.id,
      displayName: newDisplayName,
      username: currentUser!.username,
      password: currentUser!.password,
      authToken: currentUser!.authToken,
      latitude: currentUser!.latitude,
      longitude: currentUser!.longitude,
      created: currentUser!.created,
    );
    await _saveLocalUserToStorage(currentUser!);
  }
  /*
    void::setUserCoordinates(double newLatitude, double newLongitude)

    calls server to set the coordinates of the current user and returns the user.

    - double newLatitude: new latitude of the current user.
    - double newLongitude: new longitude of the current user.
  */
  Future<User?> setUserCoordinates(double newLatitude, double newLongitude) async {
    if (currentUser == null) {
      throw Exception('No current user on this device');
    }

    final result = await _api.putJson(
      '/users/${currentUser!.id}',
      {
        'latitude': newLatitude,
        'longitude': newLongitude
      },
      headers: _authHeaders()
    );

    if (result.statusCode != 200) throw Exception('Failed to update user coordinates: ${currentUser!.id}');

    // update the local user data to use the new coordinates
    currentUser = User
    (
      id: currentUser!.id,
      displayName: currentUser!.displayName,
      username: currentUser!.username,
      password: currentUser!.password,
      authToken: currentUser!.authToken,
      latitude: newLatitude,
      longitude: newLongitude,
      created: currentUser!.created,
    );
    await _saveLocalUserToStorage(currentUser!);
    return currentUser;
  }
  /*
    void::deleteUser()

    calls server to delete the current user
  */
  Future<void> deleteUser() async
  {
    if (currentUser == null) throw Exception('No current user on this device');

    final result = await _api.delete(
      '/users/${currentUser!.id}',
      headers: _authHeaders()
    );

    if (result.statusCode != 200 && result.statusCode != 204) 
    {
      throw Exception('Failed to delete user: ${result.statusCode}');
    }

    currentUser = null; // remove this user from devices memory
    await _clearLocalUserFromStorage(); // remove this user from the devices persistant storage
  }
  /*

  */
  Future<User> loginWithUsernamePassword(String username, String password) async
  {
    final result = await _api.postJson('/users/login',
    {
      'username': username.trim(),
      'password': password.trim(),
    });

    if (result.statusCode == 401) throw Exception('Invalid username or password.');
    if (result.statusCode != 200) throw Exception('Login failed: ${result.statusCode}');

    final map = Map<String, Object?>.from(jsonDecode(result.body) as Map);
    final user = User.fromMap(map);

    currentUser = user;
    await _saveLocalUserToStorage(user);
    return user;
  }
  /*

  */
  Future<void> updateAccount
  ({
    String? displayName,
    String? username,
    String? password,
  }) async
  {
    if (currentUser == null) {
      throw Exception('No current user on this device');
    }

    final patch = <String, Object?>{};
    if (displayName != null) patch['displayName'] = displayName;
    if (username != null) patch['username'] = username;
    if (password != null) patch['password'] = password;

    if (patch.isEmpty) return;

    final result = await _api.putJson(
      '/users/${currentUser!.id}',
      patch,
      headers: _authHeaders(),
    );

    if (result.statusCode == 409) throw UsernameTakenException();
    if (result.statusCode != 200) throw Exception('Failed to update account: ${result.statusCode} ${result.body}');
    
    currentUser = User(
      id: currentUser!.id,
      displayName: displayName ?? currentUser!.displayName,
      username: username ?? currentUser!.username,
      password: password ?? currentUser!.password,
      authToken: currentUser!.authToken,
      latitude: currentUser!.latitude,
      longitude: currentUser!.longitude,
      created: currentUser!.created,
    );

    await _saveLocalUserToStorage(currentUser!);
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
  Future<List<StudyGroup>> getGroups
  (
    {
      String? query,
      String? subject,
      String? location,
      String? tag,
      int limit = 50,
      int? beforeCreatedMs,
      int? afterCreatedMs,
      // for geolocation
      double? nearLat,
      double? nearLng,
      double? withinKm,
    }
  ) async
  {
    final params = <String, String>{
      'limit': limit.toString(),
    };
    if (query != null && query.trim().isNotEmpty)
    {
      params['query'] = query.trim();
    }
    if (subject != null && subject.trim().isNotEmpty)
    {
      params['subject'] = subject.trim();
    }
    if (location != null && location.trim().isNotEmpty)
    {
      params['location'] = location.trim();
    }
    if (tag != null && tag.trim().isNotEmpty)
    {
      params['tag'] = tag.trim();
    }
    if (beforeCreatedMs != null)
    {
      params['beforeCreated'] = beforeCreatedMs.toString();
    }
    if (afterCreatedMs != null)
    {
      params['afterCreated'] = afterCreatedMs.toString();
    }
    if (nearLat != null && nearLng != null && withinKm != null && withinKm > 0)
    {
      params['nearLat'] = nearLat.toString();
      params['nearLng'] = nearLng.toString();
      params['withinKm'] = withinKm.toString();
    }

    final queryString = params.entries.map((e) =>'${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    final headers = (currentUser == null) ? null : _authHeadersForUser(currentUser!);
    final result = await _api.get('/groups?$queryString', headers: headers);
    
    if (result.statusCode != 200)
    {
      throw Exception('Failed to fetch groups: ${result.statusCode}');
    }

    final List<dynamic> groupsJson = jsonDecode(result.body) as List<dynamic>;

    return groupsJson.map((json) => StudyGroup.fromMap(Map<String, Object?>.from(json as Map),)).toList();
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
  Future<bool> updateGroup(StudyGroup group) async
  {
    if (group.id == null) throw Exception('Group does not have an ID');

    final result = await _api.putJson('/groups/${group.id}',
      Map<String, dynamic>.from(group.toMap()),
      headers: _authHeaders()
    );

    if (result.statusCode == 200) 
    {
      return true;
    }
    // check for forbidden (user doesnt own the group)
    if (result.statusCode == 403) 
    {
      return false;
    }

    throw Exception('Failed to update group: ${result.statusCode}');
  }
  /*
    void::setJoined(int groupId, bool joined)

    calls server to set joined status of the current user in a group.

    - int groupId: the group the current user is joining.
    - bool joined: the joined status (true = joined, false = not joined).
  */
  Future<bool> setJoinedGroup(int groupId, bool joined) async 
  {
    if (currentUser == null) throw Exception('No current user to join a group');

    final result = await _api.postJson('/groups/$groupId/joined',
      {
        'joined': joined,
        'userId': currentUser!.id
      },
      headers: _authHeaders()
    );

    if (result.statusCode == 200) {
      return true;
    }
    // check for forbidden (user doesnt own the group)
    if (result.statusCode == 403) {
      return false;
    }

    throw Exception('Failed to join group: ${result.statusCode}');
  }
  /*
    void::deleteGroup(int groupId)

    calls server to delete a group owned by the current user.

    - int groupId: the group to delete.
    
    NOTE: this currently doesnt match the users credentials against the group, so
      its vulnerable to misuse. Fix later.
  */
  Future<bool> deleteGroup(int groupId) async 
  {
    if (currentUser == null) throw Exception('No current user to delete any groups of');

    final result = await _api.delete(
      '/groups/$groupId',
      headers: _authHeaders()
    );

    if (result.statusCode == 200 || result.statusCode == 204) 
    {
      return true;
    }
    // check for forbidden (user doesnt own the group)
    if (result.statusCode == 403) 
    {
      return false;
    }

    throw Exception('Failed to delete group: ${result.statusCode}');
  }

  /*

    Sessions

  */
  /*
    List<StudySession>::getSessionsForGroup(int groupId)

    calls server to fetch all sessions inside a group (community).

    - int groupId: the group that the sessions belong
  */
  Future<List<StudySession>> getSessionsForGroup
  (
    int groupId,
    {
      String? query,
      String? location,
      DateTime? startFrom,
      DateTime? startTo,
      DateTime? endFrom,
      DateTime? endTo,
      int limit = 50
    }
  ) async 
  {
    final params = <String, String>
    {
      'limit': limit.toString(),
    };

    if (query != null && query.trim().isNotEmpty)
    {
      params['query'] = query.trim();
    }
    if (location != null && location.trim().isNotEmpty)
    {
      params['location'] = location.trim();
    }
    if (startFrom != null)
    {
      params['startFrom'] = startFrom.millisecondsSinceEpoch.toString();
    }
    if (startTo != null)
    {
      params['startTo'] = startTo.millisecondsSinceEpoch.toString();
    }
    if (endFrom != null)
    {
      params['endFrom'] = endFrom.millisecondsSinceEpoch.toString();
    }
    if (endTo != null)
    {
      params['endTo'] = endTo.millisecondsSinceEpoch.toString();
    }

    final queryString = params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');

    final headers = (currentUser == null) ? null : _authHeadersForUser(currentUser!);
    final result = await _api.get('/groups/$groupId/sessions?$queryString', headers: headers);

    if (result.statusCode != 200)
    {
      throw Exception('Failed to fetch sessions: ${result.statusCode}');
    }

    final List<dynamic> decoded = jsonDecode(result.body) as List<dynamic>;

    return decoded.map((json) => StudySession.fromMap(Map<String, Object?>.from(json as Map),)).toList();
  }
  /*
    void::addSession(StudySession session)

    calls server to add a new session.

    - StudySession session: the session to add, is added to the group of groupId.
  */
  Future<bool> addSession(StudySession session) async 
  {
    final body = session.toMap()..remove('id');

    final result = await _api.postJson(
      '/groups/${session.groupId}/sessions', 
      Map<String, dynamic>.from(body),
      headers: _authHeaders()
      );

    if (result.statusCode == 200 || result.statusCode == 201) 
    {
      return true;
    }
    // check for forbidden (user isn't apart of the group)
    if (result.statusCode == 403) 
    {
      return false;
    }

    throw Exception('Failed to add session: ${result.statusCode}');
  }
  /*
    void::deleteSession(int sessionId)

    calls server to delete a session.

    - int sessionId: the id of the session to delete.
  */
  Future<bool> deleteSession(int sessionId) async 
  {
    if (currentUser == null) throw Exception('No current user to delete a session for');

    final result = await _api.delete(
      '/sessions/$sessionId',
      headers: _authHeaders()
    );

    if (result.statusCode == 200 || result.statusCode == 204) 
    {
      return true;
    }
    // check for forbidden (user doesnt own the group)
    if (result.statusCode == 403) 
    {
      return false;
    }

    throw Exception('Failed to delete session: ${result.statusCode}');
  }
  /*
    bool::setSessionJoined(int sessionId, bool joined)

    calls server to join the user in a session.

    - int sessionId: the id of the session to delete.
    - bool joined: the join status if the user (false = leave).
  */
  Future<bool> setSessionJoined(int sessionId, bool joined) async
  {
    if (currentUser == null)
    {
      throw Exception('No current user to join a session');
    }

    final result = await _api.postJson
    (
      '/sessions/$sessionId/joined',
      {
        'joined': joined,
        'userId': currentUser!.id,
      },
      headers: _authHeaders(),
    );

    if (result.statusCode == 200)
    {
      return true;
    }
    // not used rn
    if (result.statusCode == 403)
    {
      return false;
    }

    throw Exception('Failed to join session: ${result.statusCode}');
  }





  /*

    Messages

  */
  /*
    List<ChatMessage>::getMessages(int groupId)

    calls server to fetch all messages of a group (community).

    - int groupId: the id of the group which messages we want.

  */
  Future<List<ChatMessage>> getMessages
  (
    int groupId,
    {
      int limit = 50,
      DateTime? before,
      DateTime? after,
      String? query,
      int? sessionId,
      int? creatorId,
    }
  ) async 
  {
    final params = <String, String>
    {
      'limit': limit.toString(),
    };

    if (before != null)
    {
      params['before'] = before.millisecondsSinceEpoch.toString();
    }
    if (after != null)
    {
      params['after'] = after.millisecondsSinceEpoch.toString();
    }
    if (query != null && query.trim().isNotEmpty)
    {
      params['query'] = query.trim();
    }
    if (sessionId != null)
    {
      params['sessionId'] = sessionId.toString();
    }
    if (creatorId != null)
    {
      params['creatorId'] = creatorId.toString();
    }

    final queryString = params.entries.map((e) =>'${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');

    final result = await _api.get('/groups/$groupId/messages?$queryString');

    if (result.statusCode != 200)
    {
      throw Exception('Failed to fetch messages: ${result.statusCode}');
    }

    final List<dynamic> decoded = jsonDecode(result.body) as List<dynamic>;

    return decoded.map((json) => ChatMessage.fromMap(Map<String, Object?>.from(json as Map))).toList();
  }
  /*
    void::addMessage(ChatMessage message)

    calls server to add a new message withing a group (community).

    - ChatMessage message: message to send. Sends to group described in message.groupId
  */
  Future<bool> addMessage(ChatMessage message) async 
  {
    if (currentUser == null) throw Exception('No current user to add a message for');

    final body = message.toMap()
    ..remove('id')
    ..remove('creatorId')
    ..remove('date');

    final result = await _api.postJson(
      '/groups/${message.groupId}/messages',
      Map<String, dynamic>.from(body),
      headers: _authHeaders()
    );

    if (result.statusCode == 201 || result.statusCode == 200) {
      return true;
    }

    // not applicable right now
    if (result.statusCode == 403) 
    {
      return false;
    }

    throw Exception('Failed to add message: ${result.statusCode}');
  }
  /*
    void::deleteMessage(int messageId)

    calls server to delete a message.

    - int messageId: id of the message to be deleted.

    NOTE: We need a server-side solution to ensure the message being deleted belongs to the
      user trying to delete it.
  */
  Future<bool> deleteMessage(int messageId) async
  {
    if (currentUser == null) throw Exception('No current user to delete a message for');

    final result = await _api.delete(
      '/messages/$messageId',
      headers: _authHeaders()
      );
    
    if (result.statusCode == 201 || result.statusCode == 200) {
      return true;
    }

    if (result.statusCode == 401 || result.statusCode == 403) {
      return false;
    }

    throw Exception('Failed to delete message: ${result.statusCode}');
  }










  /*

    Notifications

  */
  void startNotificationPolling()
  {
    _notificationTimer?.cancel();
    // _lastNotificationCheckMs = DateTime.now().millisecondsSinceEpoch;
    _notificationTimer = Timer.periodic
    (
      const Duration(seconds: 10),
      (_) => _pollNotifications(),
    );
  }

  void stopNotificationPolling()
  {
    _notificationTimer?.cancel();
    _notificationTimer = null;
  }

  Future<void> _pollNotifications() async
  {
    try
    {
      final user = currentUser ?? await ensureUser();

      final params = <String, String>{};
      if (_lastNotificationCheckMs != null)
      {
        params['since'] = _lastNotificationCheckMs!.toString();
      }

      final queryString = params.isEmpty ? '' : '?' + params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');

      final result = await _api.get('/notifications$queryString',headers: _authHeadersForUser(user));

      // print('[NOTIF] status=${result.statusCode} body=${result.body}');

      if (result.statusCode != 200) return;

      final decoded = jsonDecode(result.body) as List<dynamic>;
      if (decoded.isEmpty) return;

      int newest = _lastNotificationCheckMs ?? 0;

      for (final raw in decoded)
      {
        final m = Map<String, Object?>.from(raw as Map);

        final notifId = (m['id'] as int?) ?? 0;
        final groupName = (m['groupName'] as String?) ?? 'New message';
        final text = (m['messageText'] as String?) ?? '';

        await NotificationService.instance.showMessageNotification(groupName,text);
      }

      _lastNotificationCheckMs = newest + 1;

      
    }
    catch (e, st)
    {
      // print('[NOTIF] ERRORS=$e\n$st');
    }
  }

}