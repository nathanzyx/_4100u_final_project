import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:study_connect_server/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_connect_shared/models/user.dart';
import 'package:study_connect_shared/models/group.dart';
import 'package:study_connect_shared/models/session.dart';
import 'package:study_connect_shared/models/chat_message.dart';

// for random messages
import 'auto_messenger.dart';

void main(List<String> arguments) async {

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = AppDb();

  const port = 8080;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('StudyConnect server listening to http://localhost:$port');

  // begin auto message sending
  final auto = ServerAutoMessenger(
    db,
    tick: const Duration(seconds: 5),
    sendChancePerTick: 0.2,
    );
  auto.start();

  await for (final request in server) 
  {
    await _handleRequest(request, db);
  }
}

Future<void> _handleRequest(HttpRequest request, AppDb db) async
{
  final method = request.method;

  final uri = request.uri.toString();
  print('[REQ] $method $uri');

  final segments = request.uri.pathSegments;

  if (segments.isEmpty || (segments.length == 1 && segments[0].isEmpty)) 
  {
    if (method == 'GET') 
    {
      _json(request, {'message': 'StudyConnect server running'});
    }
    else 
    {
      _methodNotAllowed(request, ['GET']);
    }
    return;
  }

  try 
  {
    final root = segments[0];

    if (root == 'ping') 
    {
      if (method == 'GET') 
      {
        _json(request, {'status': 'ok'});
      } else 
      {
        _methodNotAllowed(request, ['GET']);
      }
    }
    else if (root == 'users') 
    {
      await _handleUsers(request, db, segments, method);
    }
    else if (root == 'groups') 
    {
      await _handleGroups(request, db, segments, method);
    }
    else if (root == 'sessions') 
    {
      await _handleSessions(request, db, segments, method);
    }
    else if (root == 'messages') 
    {
      await _handleMessages(request, db, segments, method);
    } 
    else if (root == 'notifications') 
    {
      await _handleNotifications(request, db, segments, method);
    } 
    else 
    {
      _notFound(request);
    }
  } catch (error, status) 
  {
    stderr.writeln('Error in handling request ${request.method} ${request.uri}: $error\n$status');
    _text(request, 'Server Error', statusCode: HttpStatus.internalServerError);
  }
}

Future<void> _handleUsers
(
  HttpRequest request,
  AppDb db,
  List<String> segments,
  String method,
) async
{
  /*
    /users
  */
  if (segments.length == 1) 
  {
    if (method == 'POST') 
    {
      final user = await db.createUser();
      _json(request, user.toMap(), statusCode: HttpStatus.created);
    }
    else 
    {
      _methodNotAllowed(request, ['POST']);
    }
    return;
  }
  /*
    /users/auth
  */
  if (segments.length == 2 && segments[1] == 'auth') 
  {
    if (method == 'GET')
    {
      final user = await _requireAuth(request, db);
      if (user == null) return;

      // Since authorized, return full data for the authorized user
      _json(request, user.toMap());
    }
    else
    {
      _methodNotAllowed(request, ['GET']);
    }
    return;
  }
  /*
    /users/login
  */
  if (segments.length == 2 && segments[1] == 'login')
  {
    if (method != 'POST')
    {
      _methodNotAllowed(request, ['POST']);
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    if (body.isEmpty) {
      _badRequest(request, 'Missing request body');
      return;
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    final username = (data['username'] as String?)?.trim();
    final password = (data['password'] as String?)?.trim();

    if (username == null || username.isEmpty || password == null || password.isEmpty)
    {
      _badRequest(request, 'username and password are required');
      return;
    }

    final user = await db.getUserByUsernamePassword(username, password);
    if (user == null)
    {
      _unauthorized(request);
      return;
    }

    _json(request, user.toMap());
    return;
  }
  /*
    /users/{id}
  */
  if (segments.length == 2) 
  {
    final id = int.tryParse(segments[1]);
    if (id == null) 
    {
      _badRequest(request, 'Invalid User Id');
      return;
    }
    if (method == 'GET') // public user getter (only returns public user data)
    {
      final user = await db.getUserById(id);
      if (user == null) 
      {
        _notFound(request);
      }
      else 
      {
        _json(request,
        {
          'id': user.id,
          'displayName': user.displayName,
          'created': user.created
        }
        );
      }
    } 
    else if (method == 'PUT')
    {
      // authentication
      final user = await _requireAuth(request, db);
      if (user == null) return;

      // Ensure user making call is changing themself
      if (user.id != id)
      {
        _forbidden(request);
        return;
      }

      final body = await utf8.decoder.bind(request).join();
      if (body.isEmpty) 
      {
        _badRequest(request, 'Missing request body');
        return;
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      bool changed = false;

      if (data['displayName'] != null)
      {
        final displayName = (data['displayName'] as String).trim();
        if (displayName.isEmpty)
        {
          _badRequest(request, 'displayName cannot be empty');
          return;
        }

        await db.setUserDisplayName(id, displayName);
        changed = true;
      }

      if (data['latitude'] != null && data['longitude'] != null)
      {
        final latitude = (data['latitude'] as num).toDouble();
        final longitude = (data['longitude'] as num).toDouble();
        await db.setUserCoordinates(id, latitude, longitude);


        changed = true;
      }

      if (data['username'] != null)
      {
        final username = (data['username'] as String).trim();
        if (username.isEmpty)
        {
          _badRequest(request, 'username cannot be empty');
          return;
        }

        final ownerId = await db.getUserIdByUsername(username);
        if (ownerId != null && ownerId != id)
        {
          _conflict(request, 'username_taken');
          return;
        }

        await db.setUserUsername(id, username);
        changed = true;
      }

      if (data['password'] != null)
      {
        final password = (data['password'] as String).trim();

        if (password.isEmpty)
        {
          _badRequest(request, 'password cannot be empty');
          return;
        }

        await db.setUserPassword(id, password);
        changed = true;
      }

      if (!changed)
      {
        _badRequest(request, 'No supported fields to update');
        return;
      }

      // return updated user
      final updated = await db.getUserById(id);

      _json(request, {'success': true, 'user': updated?.toMap()});
    }
    else if (method == 'DELETE') 
    {
      // authentication
      final user = await _requireAuth(request, db);
      if (user == null) return;

      // Ensure user making the call is naming themselves
      if (user.id != id)
      {
        _forbidden(request);
        return;
      }

      await db.deleteUser(id);
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
    }
    else 
    {
      _methodNotAllowed(request, ['GET', 'PUT', 'DELETE']);
    }
    return;
  }
  
  

  _notFound(request);
}

Future<void> _handleGroups
(
  HttpRequest request,
  AppDb db,
  List<String> segments,
  String method,
) async
{
  /*
    /groups
  */
  if (segments.length == 1)
  {
    if(method == 'GET') 
    {
      final q = request.uri.queryParameters;

      // limit
      final limit = _parseLimit(q, def: 50, max: 100);

      // filters
      final query = q['query'];
      final subject = q['subject'];
      final location = q['location'];
      final tag = q['tag'];

      final nearLat = _parseDoubleParam(q, 'nearLat');
      final nearLng = _parseDoubleParam(q, 'nearLng');
      final withinKm = _parseDoubleParam(q, 'withinKm');

      // if radius is given, but no coords were given, bad request
      if (withinKm != null && (nearLat == null || nearLng == null))
      {
        _badRequest(request, 'latitude and longitude are missing!');
        return;
      }

      // time
      final beforeCreated = _parseIntParam(q, 'beforeCreated');
      final afterCreated = _parseIntParam(q, 'afterCreated');

      final groups = await db.getGroups
      (
        text: query,
        subject: subject,
        location: location,
        tag: tag,
        limit: limit,
        beforeCreated: beforeCreated,
        afterCreated: afterCreated,
        nearLat: nearLat,
        nearLng: nearLng,
        withinKm: withinKm,
      );

      // if a valid user made this call (and is authenticated, then we also determine whether the user is or isnt joined in reach group)
      User? user;
      final hasAnyAuthHeader = request.headers.value('X-User-Id') != null || request.headers.value('X-Auth-Token') != null;

      if (hasAnyAuthHeader)
      {
        user = await _requireAuth(request, db);
        if (user == null) return;
      }

      final joinedGroupIds = (user == null)? <int>{} : await db.getJoinedGroupIds(user.id);

      // mark each group as joined or unjoined
      final groupIds = groups.map((g) => g.id).whereType<int>().toList();
      final memberCounts = await db.getGroupMemberCounts(groupIds);

      final list = groups.map((g)
      {
        final isJoined = g.id != null && joinedGroupIds.contains(g.id!);
        final members = g.id != null ? (memberCounts[g.id!] ?? 0) : 0;

        return g.copyWith(joined: isJoined, numMembers: members).toMap(includeJoined: true, includeNumMembers: true);
      }).toList();

      _json(request, list);
    }
    else if (method == 'POST') 
    {
      // authentication
      final user = await _requireAuth(request, db);
      if (user == null) return;

      final body = await utf8.decoder.bind(request).join();
      if (body.isEmpty) 
      {
        _badRequest(request, 'Missing Request Body');
        return;
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final g = StudyGroup.fromMap(data.cast<String, Object>());
      final group = StudyGroup
      (
        id: null,
        name: g.name,
        description: g.description,
        subject: g.subject,
        location: g.location,
        latitude: g.latitude,
        longitude: g.longitude,
        tags: g.tags,
        creatorId: user.id,
        created: null,
      );
      final newGroup = await db.insertGroup(group);

      // auto-join the creator of the group into the group
      await db.setJoinedGroup(user.id, newGroup.id!, true);

      _json(request, true, statusCode: HttpStatus.created);
    }
    else 
    {
      _methodNotAllowed(request, ['GET', 'POST']);
    }
    return;
  }

  /*
    /groups/{id}
  */
  if (segments.length >= 2) 
  {
    final groupId = int.tryParse(segments[1]);
    if (groupId == null) 
    {
      _badRequest(request, 'Null Group Id');
      return;
    }
    /*
      /groups/{id}
    */
    if (segments.length == 2) 
    {
      if (method == 'PUT') 
      { 
        // authentication
        final user = await _requireAuth(request, db);
        if (user == null) return;

        final body = await utf8.decoder.bind(request).join();
        if (body.isEmpty) 
        {
          _badRequest(request, 'Missing Request Body');
          return;
        }

        // retreive group
        final existing = await db.getGroupById(groupId);
        if (existing == null) {
          _notFound(request);
          return;
        }
        // ensure user owns the group
        if (existing.creatorId != user.id) {
          _forbidden(request);
          return;
        }

        final data = jsonDecode(body) as Map<String, dynamic>;
        final g = StudyGroup.fromMap(data.cast<String, Object?>());
        final group = StudyGroup
        (
          id: existing.id,
          name: g.name,
          description: g.description,
          subject: g.subject,
          location: g.location,
          latitude: g.latitude,
          longitude: g.longitude,
          tags: g.tags,
          creatorId: user.id,
          created: null,
        );
        await db.updateGroup(group);
        _json(request, {'success': 'true'});
      }
      else if (method == 'DELETE') 
      {
        // authentication
        final user = await _requireAuth(request, db);
        if (user == null) return;

        // retreive group
        final existing = await db.getGroupById(groupId);
        if (existing == null) {
          _notFound(request);
          return;
        }

        // ensure user owns the group
        if (existing.creatorId != user.id) {
          _forbidden(request);
          return;
        }

        await db.deleteGroup(groupId);
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
      }
      else 
      {
        _methodNotAllowed(request, ['PUT, DELETE']);
      }
      return;
    }

    /*
      /groups/{id}/joined
    */
    if (segments.length == 3 && segments[2] == 'joined') 
    {
      if(method != 'POST') 
      {
        _methodNotAllowed(request, ['POST']);
        return;
      }

      // authentication
      final user = await _requireAuth(request, db);
      if (user == null) return;

      final body = await utf8.decoder.bind(request).join();
      if (body.isEmpty) 
      {
        _badRequest(request, 'Missing Request Body');
        return;
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final joined = data['joined'] as bool?;
      final userId = data['userId'] as int?;
      if (joined == null || userId == null)
      {
        _badRequest(request, '\'joined\' or \'userId\' is null.');
        return;
      }

      // Ensure client sent user id matched authenticated id
      if (userId != user.id) {
        _forbidden(request);
        return;
      }

      await db.setJoinedGroup(user.id, groupId, joined);
      _json(request, {'success': 'true'});
      return;
    }

    /*
      /groups/{id}/sessions
    */
    if (segments.length == 3 && segments[2] == 'sessions') 
    {
      if(method == 'GET') 
      { 
        // if the user making this query is authenticated, we attach joined status for each session for that user
        User? user;
        final hasAnyAuthHeader = request.headers.value('X-User-Id') != null || request.headers.value('X-Auth-Token') != null;
        if (hasAnyAuthHeader)
        {
          user = await _requireAuth(request, db);
          if (user == null) return;
        }
        // get all sessions joined for the authenticated user
        final joinedSessionIds = (user == null) ? <int>{} : await db.getJoinedSessionIdsForUserInGroup(user.id, groupId);

        final qp = request.uri.queryParameters;

        // limit
        final limit = _parseLimit(qp, def: 50, max: 100);
        // filters
        final query = qp['query'];
        final location = qp['location'];

        // session start and end times
        final startFrom = _parseIntParam(qp, 'startFrom');
        final startTo = _parseIntParam(qp, 'startTo');
        final endFrom = _parseIntParam(qp, 'endFrom');
        final endTo = _parseIntParam(qp, 'endTo');

        final sessions = await db.getSessionsForGroup
        (
          groupId,
          text: query,
          location: location,
          startFromMs: startFrom,
          startToMs: startTo,
          endFromMs: endFrom,
          endToMs: endTo,
          limit: limit,
        );

        // add joined status if applicable
        final list = sessions.map((s)
        {
          final isJoined = s.id != null && joinedSessionIds.contains(s.id!);
          return s.copyWith(joined: isJoined).toMap(includeJoined: true);
        }).toList();

        _json(request, list);
      }
      else if (method == 'POST') 
      {
        // authentication
        final user = await _requireAuth(request, db);
        if (user == null) return;

        final body = await utf8.decoder.bind(request).join();
        if (body.isEmpty) 
        {
          _badRequest(request, 'Missing Request Body');
          return;
        }
        final data = jsonDecode(body) as Map<String, dynamic>;
        final s = StudySession.fromMap(data.cast<String, Object?>());
        final session = StudySession
        (
          id: null,
          groupId: s.groupId,
          title: s.title,
          description: s.description,
          start: s.start,
          end: s.end,
          location: s.location,
          maxAttendees: s.maxAttendees,
          attendees: s.attendees,
          creatorId: user.id,
          created: DateTime.now(),
        );
        await db.addSession(session);
        _json(request, {'success': 'true'});
        return;
      }
      else 
      {
        _methodNotAllowed(request, ['GET, POST']);
      }
      return;
    }

    /*
      /groups/{id}/messages
    */
    if (segments.length == 3 && segments[2] == 'messages') 
    {
      if(method == 'GET') 
      {
        final qp = request.uri.queryParameters;

        final limit = _parseLimit(qp, def: 50, max: 100);
        final beforeMs = _parseIntParam(qp, 'before');
        final afterMs = _parseIntParam(qp, 'after');

        final query = qp['query'];
        final sessionId = _parseIntParam(qp, 'sessionId');
        final creatorId = _parseIntParam(qp, 'creatorId');

        final messages = await db.getMessages
        (
          groupId,
          limit: limit,
          beforeMs: beforeMs,
          afterMs: afterMs,
          text: query,
          sessionId: sessionId,
          creatorId: creatorId,
        );

        final list = messages.map((m) => m.toMap()).toList();
        _json(request, list);
      }
      else if (method == 'POST') 
      {
        // authentication
        final user = await _requireAuth(request, db);
        if (user == null) return;

        final body = await utf8.decoder.bind(request).join();
        if (body.isEmpty) 
        {
          _badRequest(request, 'Missing Request Body');
          return;
        }
        final data = jsonDecode(body) as Map<String, dynamic>;
        final clientMessage = ChatMessage.fromMap(data.cast<String, Object?>());
        final message = ChatMessage
        (
          id: null,
          groupId: clientMessage.groupId,
          sessionId: clientMessage.sessionId,
          creatorId: user.id,
          text: clientMessage.text,
          date: DateTime.now()
        );
        final messageId = await db.addMessage(message);

        // create notifications for group members except the message writer
        await db.insertNotificationsForNewMessage
        (
          message.groupId,
          messageId,
          message.creatorId!,
        );

        _json(request, {'success': 'true'});
        return;
      }
      else 
      {
        _methodNotAllowed(request, ['GET, POST']);
      }
      return;
    }
  }
  _notFound(request);
}


Future<void> _handleSessions
(
  HttpRequest request,
  AppDb db,
  List<String> segments,
  String method,
) async
{
  /*
    /session/{id}
  */
  if(segments.length >= 2) 
  {
    final id = int.tryParse(segments[1]);
    if (id == null)
    {
      _badRequest(request, 'Null session id.');
      return;
    }

    /*
      /sessions/{id}
    */
    if (segments.length == 2)
    {
      if (method == 'DELETE')
      {
      // authentication
      final user = await _requireAuth(request, db);
      if (user == null) return;

      final id = int.tryParse(segments[1]);
      if (id == null) 
      {
        _badRequest(request, 'Null session id.');
        return;
      }

      final session = await db.getSessionById(id);
      if (session == null)
      {
        _notFound(request);
        return;
      }

      if (session.creatorId != user.id) 
      {
        _forbidden(request);
        return;
      }

      await db.deleteSession(id);
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
      }
    }
    /*
      /sessions/{id}/joined
    */
    if (segments.length == 3 && segments[2] == 'joined')
    {
      if (method != 'POST')
      {
        _methodNotAllowed(request, ['POST']);
        return;
      }

      // authentication
      final user = await _requireAuth(request, db);
      if (user == null) return;

      final body = await utf8.decoder.bind(request).join();
      if (body.isEmpty)
      {
        _badRequest(request, 'Missing Request Body');
        return;
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final joined = data['joined'] as bool?;
      final userId = data['userId'] as int?;
      if (joined == null || userId == null)
      {
        _badRequest(request, '\'joined\' or \'userId\' is null.');
        return;
      }

      // ensure user joining is the same as the user making this request
      if (userId != user.id)
      {
        _forbidden(request);
        return;
      }

      await db.setJoinedSession(user.id, id, joined);
      _json(request, {'success': 'true'});
      return;
    }
  }
  _notFound(request);
}


Future<void> _handleMessages
(
  HttpRequest request,
  AppDb db,
  List<String> segments,
  String method,
) async
{
  /*
    /messages/{id}
  */
  if(segments.length == 2 && method == 'DELETE') 
  {
    // authentication
    final user = await _requireAuth(request, db);
    if (user == null) return;

    final id = int.tryParse(segments[1]);
    if (id == null) 
    {
      _badRequest(request, 'Null message id.');
      return;
    }

    final message = await db.getMessageById(id);
    if (message == null) 
    {
      _notFound(request);
      return;
    }

    // ensure the message being deleted is owned by the user
    if (message.creatorId != user.id) 
    {
      _forbidden(request);
      return;
    }

    await db.deleteMessage(id);
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }
  _notFound(request);
}



Future<void> _handleNotifications
(
  HttpRequest request,
  AppDb db,
  List<String> segments,
  String method
) async
{
  /*
    /notifications
  */
  if (segments.length == 1)
  {
    if (method != 'GET')
    {
      _methodNotAllowed(request, ['GET']);
      return;
    }

    // authorize user
    final user = await _requireAuth(request, db);
    if (user == null) return;

    final qp = request.uri.queryParameters;
    final sinceMs = _parseIntParam(qp, 'since');
    final limit = _parseLimit(qp, def: 50, max: 100);

    final rows = await db.getUnreadNotificationsForUser
    (
      user.id,
      sinceMs: sinceMs,
      limit: limit,
    );

    // mark as read right away
    final ids = rows.map((r) => r['notifId']).whereType<int>().toList();
    await db.markNotificationsAsRead(ids);

    // make response
    final list = rows.map((r)
    {
      return {
        'id': r['notifId'],
        'groupId': r['groupId'],
        'groupName': r['groupName'],
        'messageId': r['messageId'],
        'messageText': r['messageText'],
        'messageDate': r['messageDate'],
        'created': r['notifCreated'],
      };
    }).toList();

    // print("MADE IT TO END OF /notifications");

    _json(request, list);
    return;
  }

  _notFound(request);
}






/*
  Helpers
*/
void _json(HttpRequest request, Object body, {int statusCode = HttpStatus.ok}) 
{
  request.response.statusCode = statusCode;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  request.response.close();
}

void _text(HttpRequest request, String body, {int statusCode = HttpStatus.badRequest}) 
{
  request.response.statusCode = statusCode;
  request.response.headers.contentType = ContentType.text;
  request.response.write(body);
  request.response.close();
}

void _badRequest(HttpRequest request, String message) 
{
  _text(request, 'Bad Request: $message', statusCode: HttpStatus.badRequest);
}

void _notFound(HttpRequest request) 
{
  _text(request, 'Not found', statusCode: HttpStatus.notFound);
}

void _methodNotAllowed(HttpRequest request, List<String> allowed) 
{
  request.response.headers.set('Allow', allowed.join(', '));
  _text(request, 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
}

void _unauthorized(HttpRequest request) 
{
  _text(request, 'Unauthorized', statusCode: HttpStatus.unauthorized);
}

void _forbidden(HttpRequest request) 
{
  _text(request, 'Forbidden', statusCode: HttpStatus.forbidden);
}

void _conflict(HttpRequest request, String message)
{
  _json(request, {'error': message}, statusCode: HttpStatus.conflict);
}

Future<User?> _requireAuth
(
  HttpRequest request, AppDb db
) async
{
  final idHeader = request.headers.value('X-User-Id');
  final token = request.headers.value('X-Auth-Token');

  if (idHeader == null || token == null) { _unauthorized(request); return null; }

  final userId = int.tryParse(idHeader);
  if (userId == null)  { _unauthorized(request); return null; }

  final user = await db.getUserById(userId);
  if (user == null || user.authToken != token) { _unauthorized(request); return null; }

  return user;
}

int _parseLimit
(
  Map<String, String> queryParams,
  {
    int def = 50,
    int max = 100
  }
) 
{
  final i = queryParams['limit'];
  final parsed = i != null ? int.tryParse(i) : null;
  if (parsed == null || parsed <= 0) return def;
  if (parsed > max) return max;
  return parsed;
}

int? _parseIntParam
(
  Map<String, String> qp,
  String key
)
{
  final i = qp[key];
  if (i == null) return null;
  return int.tryParse(i);
}

double? _parseDoubleParam(Map<String, String> queryParam, String key)
{
  final i = queryParam[key];
  if (i == null) return null;
  return double.tryParse(i);
}

