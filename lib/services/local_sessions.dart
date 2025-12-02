// import 'package:study_connect/widgets/create_session.dart';

// /// Very simple in-memory store for sessions.
// /// Key = groupId, Value = list of sessions for that group.
// class LocalSessionStore {
//   LocalSessionStore._();

//   static final LocalSessionStore instance = LocalSessionStore._();

//   final Map<int, List<SessionInfo>> _sessionsByGroup = {};

//   List<SessionInfo> getSessions(int groupId) {
//     final list = _sessionsByGroup[groupId];
//     if (list == null) return [];
//     // return a copy so callers can't accidentally modify internal list
//     return List<SessionInfo>.from(list);
//   }

//   void addSession(int groupId, SessionInfo session) {
//     final list = _sessionsByGroup.putIfAbsent(groupId, () => <SessionInfo>[]);
//     list.add(session);
//   }
// }
