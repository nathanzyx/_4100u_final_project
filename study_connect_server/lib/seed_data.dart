/*
  NOTE:

    This entire file was created by ChatGPT for demo data during the apps runtime
*/

import 'dart:math';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Big demo dataset seeder for StudyConnect.
/// Call this once right after creating tables (inside AppDb.onCreate).
class DemoSeed {

  // Toggle if you ever want to disable seeding quickly
  static const bool enabled = true;

  // Change these to scale up/down.
  static const int userCount = 80;
  static const int groupCount = 45;

  // Sessions per group range (inclusive)
  static const int sessionsPerGroupMin = 1;
  static const int sessionsPerGroupMax = 4;

  // Messages per group range (inclusive)
  static const int messagesPerGroupMin = 10;
  static const int messagesPerGroupMax = 35;

  /// Seeds a bunch of users/groups/sessions/messages + memberships.
  static Future<void> seed(DatabaseExecutor db) async {
    if (!enabled) return;

    // only seed if database is empty
    final countRows = await db.rawQuery('SELECT COUNT(*) AS cnt FROM users');
    final count = (countRows.isNotEmpty) ? (countRows.first['cnt'] as int?) : 0;
    if ((count ?? 0) > 0) return;

    // If db is a Database, we can wrap everything in a transaction.
    if (db is Database) {
      await db.transaction((txn) async {
        await _seedInner(txn);
      });
      return;
    }

    // Fallback (rare): insert without transaction.
    await _seedInner(db);
  }

  static Future<void> _seedInner(DatabaseExecutor db) async {
    final rng = Random(1337); // deterministic demo data (same every run)
    final now = DateTime.now();
    int ms(DateTime dt) => dt.millisecondsSinceEpoch;

    // --- Location pools (spread out so nearby filter actually looks good) ---
    final cities = <_City>[
      _City('Toronto, ON', 43.6532, -79.3832),
      _City('Oshawa, ON', 43.8971, -78.8658),
      _City('Whitby, ON', 43.8975, -78.9429),
      _City('Ajax, ON', 43.8509, -79.0204),
      _City('Scarborough, ON', 43.7764, -79.2318),
      _City('Mississauga, ON', 43.5890, -79.6441),
      _City('Markham, ON', 43.8561, -79.3370),
      _City('Waterloo, ON', 43.4643, -80.5204),
      _City('Ottawa, ON', 45.4215, -75.6972),
      _City('Montreal, QC', 45.5017, -73.5673),
      _City('Vancouver, BC', 49.2827, -123.1207),
      _City('Calgary, AB', 51.0447, -114.0719),
      _City('New York, USA', 40.7128, -74.0060),
      _City('Boston, USA', 42.3601, -71.0589),
      _City('London, UK', 51.5072, -0.1276),
    ];

    final subjects = <String>[
      'Computer Science',
      'Math',
      'Physics',
      'Chemistry',
      'Biology',
      'Psychology',
      'Business',
      'Statistics',
      'Linear Algebra',
      'Calculus',
      'Software Engineering',
      'Databases',
      'AI / Machine Learning',
      'Operating Systems',
      'Networks',
    ];

    final tagsBySubject = <String, List<String>>{
      'Computer Science': ['CS', 'Programming', 'C++', 'Java', 'Python', 'Data Structures'],
      'Math': ['Math', 'Proofs', 'Homework', 'Midterm', 'First Year'],
      'Statistics': ['Stats', 'R', 'Probability', 'Regression', 'Practice'],
      'Calculus': ['Calculus', 'Derivatives', 'Integrals', 'Limits', 'Exam Prep'],
      'Linear Algebra': ['LinAlg', 'Matrices', 'Eigen', 'Vectors', 'Midterm'],
      'Databases': ['SQL', 'Relational Algebra', 'Normalization', 'ERD', 'Practice'],
      'AI / Machine Learning': ['ML', 'PyTorch', 'Numpy', 'Math', 'Projects'],
      'Operating Systems': ['OS', 'Processes', 'Threads', 'xv6', 'C'],
      'Psychology': ['Psych', 'Notes', 'Quiz Prep', 'Study Guide'],
      'Physics': ['Physics', 'Mechanics', 'Practice', 'Problems'],
      'Chemistry': ['Chem', 'Lab', 'Organic', 'Quiz Prep'],
      'Business': ['Finance', 'Accounting', 'Case Study', 'Group Work'],
      'Software Engineering': ['Design', 'Testing', 'Agile', 'Architecture'],
      'Networks': ['TCP', 'HTTP', 'Routing', 'Wireshark'],
      'Biology': ['Bio', 'Lab', 'Flashcards', 'Exam Prep'],
    };

    final groupNameTemplates = <String>[
      '{subject} Study Squad',
      '{subject} Homework Help',
      '{subject} Exam Prep',
      '{subject} Weekly Hangout',
      '{subject} Crash Course',
      '{subject} Practice Problems',
      '{subject} Notes & Review',
    ];

    final groupDescTemplates = <String>[
      'Weekly sessions, shared notes, and practice problems.',
      'Come ask questions and work through assignments together.',
      'Focused group for quizzes/midterms/finals — no judgment, just progress.',
      'Bring your toughest questions. We’ll grind them down.',
      'Study group with structured sessions and occasional chaos.',
    ];

    final sessionTitleTemplates = <String>[
      'Midterm Review',
      'Practice Problems Night',
      'Lecture Catch-up + Notes',
      'Assignment Help Session',
      'Concept Deep Dive',
      'Exam Prep Sprint',
    ];

    final messageSnippets = <String>[
      'Anyone understand the last concept from lecture?',
      'I can share my notes after class 👍',
      'What chapters are we focusing on this week?',
      'Let’s do a quick recap then problems.',
      'Does anyone want to meet earlier?',
      'I found a good practice set — I’ll post it soon.',
      'Reminder: quiz on Friday.',
      'Can we go over examples 3 and 4?',
      'I’m stuck on a question, please help 😭',
      'We should split the topics and teach each other.',
      'Don’t forget to bring a calculator / laptop.',
      'I’ll be 10 mins late.',
    ];

    // --- Insert users ---
    final userIds = <int>[];
    for (int i = 0; i < userCount; i++) {
      final city = cities[rng.nextInt(cities.length)];
      final name = _fakeName(rng);
      final username = _uniqueUsername(name, i);
      final password = 'pw$i';
      final token = 'seed_${username}_token';

      // jitter around the city center so nearby filtering makes sense
      final lat = _jitter(city.lat, rng, 0.08); // ~ up to ~9km-ish
      final lng = _jitter(city.lng, rng, 0.08);

      final created = ms(now.subtract(Duration(days: rng.nextInt(60) + 1, hours: rng.nextInt(24))));

      final id = await db.insert('users', {
        'displayName': name,
        'username': username,
        'password': password,
        'authToken': token,
        'latitude': lat,
        'longitude': lng,
        'created': created,
      });

      userIds.add(id);
    }

    // --- Insert groups + memberships + sessions + session memberships + messages ---
    final groupIds = <int>[];
    for (int gi = 0; gi < groupCount; gi++) {
      final subject = subjects[rng.nextInt(subjects.length)];
      final city = cities[rng.nextInt(cities.length)];
      final creatorId = userIds[rng.nextInt(userIds.length)];

      final groupName = _template(rng, groupNameTemplates).replaceAll('{subject}', subject);
      final desc = _template(rng, groupDescTemplates);
      final tags = _makeTags(rng, subject, tagsBySubject);

      final groupLat = _jitter(city.lat, rng, 0.15);
      final groupLng = _jitter(city.lng, rng, 0.15);

      final created = ms(now.subtract(Duration(days: rng.nextInt(90), hours: rng.nextInt(24))));

      final groupId = await db.insert('groups', {
        'name': groupName,
        'description': desc,
        'subject': subject,
        'location': city.label,
        'latitude': groupLat,
        'longitude': groupLng,
        'tags': tags.join('|'),
        'creatorId': creatorId,
        'created': created,
      });

      groupIds.add(groupId);

      // --- group_members: creator always joined + random members ---
      final memberCount = 6 + rng.nextInt(30); // 6..35-ish
      final memberSet = <int>{creatorId};

      while (memberSet.length < memberCount && memberSet.length < userIds.length) {
        memberSet.add(userIds[rng.nextInt(userIds.length)]);
      }

      for (final uid in memberSet) {
        await db.insert(
          'group_members',
          {
            'userId': uid,
            'groupId': groupId,
            'joinedAt': ms(now.subtract(Duration(days: rng.nextInt(30), hours: rng.nextInt(24)))),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // --- sessions ---
      final sessionsCount = sessionsPerGroupMin + rng.nextInt((sessionsPerGroupMax - sessionsPerGroupMin) + 1);
      final sessionIds = <int>[];

      for (int si = 0; si < sessionsCount; si++) {
        final start = now.add(Duration(days: rng.nextInt(14) + 1, hours: rng.nextInt(10) + 8));
        final durationHours = 1 + rng.nextInt(3); // 1..3
        final end = start.add(Duration(hours: durationHours));

        final maxAttendees = 6 + rng.nextInt(20);
        final title = '${_template(rng, sessionTitleTemplates)} • $subject';
        final location = '${city.label} • Room ${String.fromCharCode(65 + rng.nextInt(6))}${100 + rng.nextInt(300)}';

        final createdSess = ms(now.subtract(Duration(days: rng.nextInt(10), hours: rng.nextInt(24))));

        final sessId = await db.insert('sessions', {
          'groupId': groupId,
          'title': title,
          'description': 'Bring questions. We’ll focus on ${_focusPhrase(rng, subject)}.',
          'start': ms(start),
          'end': ms(end),
          'location': location,
          'maxAttendees': maxAttendees,
          // attendees will be set after we add session_members
          'attendees': 0,
          'creatorId': creatorId,
          'created': createdSess,
        });

        sessionIds.add(sessId);

        // --- session_members: pick subset of group members ---
        final groupMembersList = memberSet.toList()..shuffle(rng);
        final joinCount = min(groupMembersList.length, 2 + rng.nextInt(min(10, groupMembersList.length)));
        final joinedUsers = groupMembersList.take(joinCount).toList();

        for (final uid in joinedUsers) {
          await db.insert(
            'session_members',
            {
              'userId': uid,
              'sessionId': sessId,
              'joinedAt': ms(now.subtract(Duration(days: rng.nextInt(12), hours: rng.nextInt(24)))),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        // update attendees count to match session_members
        await db.rawUpdate(
          'UPDATE sessions SET attendees = ? WHERE id = ?',
          [joinedUsers.length, sessId],
        );
      }

      // --- messages (group chat + sometimes linked to a session) ---
      final msgCount = messagesPerGroupMin + rng.nextInt((messagesPerGroupMax - messagesPerGroupMin) + 1);
      final groupMembersList = memberSet.toList();

      // create a "timeline" of recent messages
      for (int mi = 0; mi < msgCount; mi++) {
        final uid = groupMembersList[rng.nextInt(groupMembersList.length)];
        final txt = _makeMessage(rng, messageSnippets, subject);

        // 25% chance it’s tied to a random session
        final sessionId = (sessionIds.isNotEmpty && rng.nextInt(4) == 0)
            ? sessionIds[rng.nextInt(sessionIds.length)]
            : null;

        final deltaHours = (msgCount - mi) * (1 + rng.nextInt(3));
        final timestamp = ms(now.subtract(Duration(hours: deltaHours)));

        await db.insert('messages', {
          'groupId': groupId,
          'sessionId': sessionId,
          'creatorId': uid,
          'text': txt,
          'date': timestamp,
        });
      }
    }

    // Optional: if you want a couple “global” groups with heavy activity:
    // (You can add special cases here.)
  }
}

/* -------------------- helpers -------------------- */

class _City {
  final String label;
  final double lat;
  final double lng;
  const _City(this.label, this.lat, this.lng);
}

double _jitter(double base, Random rng, double maxDelta) {
  // random uniform in [-maxDelta, +maxDelta]
  return base + (rng.nextDouble() * 2 - 1) * maxDelta;
}

String _template(Random rng, List<String> items) => items[rng.nextInt(items.length)];

List<String> _makeTags(Random rng, String subject, Map<String, List<String>> tagsBySubject) {
  final pool = tagsBySubject[subject] ?? ['Study', 'Help', 'Notes'];
  final n = 2 + rng.nextInt(4); // 2..5
  final set = <String>{subject.split(' ').first};
  while (set.length < n) {
    set.add(pool[rng.nextInt(pool.length)]);
  }
  return set.toList();
}

String _fakeName(Random rng) {
  const first = [
    'Alex','Sam','Taylor','Jordan','Avery','Casey','Riley','Jamie','Morgan','Quinn',
    'Chris','Drew','Nico','Maya','Noah','Liam','Emma','Olivia','Sophia','Ava',
    'Ethan','Lucas','Mila','Aria','Leo','Zoe','Layla','Chloe','Mason','Ella'
  ];
  const last = [
    'Nguyen','Patel','Smith','Brown','Wilson','Johnson','Lee','Martin','Clark','Walker',
    'Young','Allen','King','Wright','Scott','Green','Baker','Hill','Adams','Carter'
  ];
  return '${first[rng.nextInt(first.length)]} ${last[rng.nextInt(last.length)]}';
}

String _uniqueUsername(String displayName, int i) {
  final base = displayName.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  return '${base}${100 + i}';
}

String _focusPhrase(Random rng, String subject) {
  const generic = [
    'the hardest homework questions',
    'core concepts + practice',
    'a quick recap then problems',
    'exam-style questions',
    'common mistakes + fixes',
  ];
  final specific = {
    'Databases': ['relational algebra', 'SQL joins', '3NF/MVD practice', 'transactions + triggers'],
    'Calculus': ['limits + continuity', 'derivatives', 'integrals', 'optimization problems'],
    'Operating Systems': ['processes + syscalls', 'threads', 'memory + paging', 'xv6'],
    'AI / Machine Learning': ['loss functions', 'backprop intuition', 'overfitting', 'model training'],
    'Computer Science': ['pointers', 'OOP vs data-oriented', 'big-O', 'debugging'],
  };

  final pool = specific[subject] ?? generic;
  return pool[rng.nextInt(pool.length)];
}

String _makeMessage(Random rng, List<String> snippets, String subject) {
  final base = snippets[rng.nextInt(snippets.length)];
  if (rng.nextInt(5) == 0) {
    return '$base (topic: ${_focusPhrase(rng, subject)})';
  }
  if (rng.nextInt(7) == 0) {
    return '$base Also, anyone free this weekend?';
  }
  return base;
}
