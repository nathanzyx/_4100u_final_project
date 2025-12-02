import 'package:study_connect_server/database.dart';
import 'dart:math';
import 'dart:async';

/*
  PLEASE NOTE:

  This file was created by ChatGPT.
  This file is used for sending random messages every few seconds to simulate an active app environment

*/

class ServerAutoMessenger {
  final AppDb db;
  final Random _rng = Random();

  Timer? _timer;
  bool _running = false;

  // tweak these freely
  final Duration tick;
  final double sendChancePerTick;

  ServerAutoMessenger(
    this.db, {
    this.tick = const Duration(seconds: 3),
    this.sendChancePerTick = 0.25, // 25% chance each tick => ~1 msg/min on average
  });

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(tick, (_) => _run());
    _run(); // optional immediate run
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;

    try {
      // random chance so it doesn't spam every tick
      if (_rng.nextDouble() > sendChancePerTick) return;

      final db_ = await db.db;

      // pick a random group
      final groups = await db_.rawQuery('SELECT id, name FROM groups');
      if (groups.isEmpty) return;

      final g = groups[_rng.nextInt(groups.length)];
      final groupId = g['id'] as int;
      final groupName = (g['name'] as String?) ?? 'Group';

      // pick a "system" author (use an existing user; simplest: the lowest user id)
      final users = await db_.rawQuery('SELECT id FROM users ORDER BY id ASC LIMIT 1');
      if (users.isEmpty) return;
      final systemUserId = users.first['id'] as int;

      const messages = [
        'Reminder: be kind and keep it on-topic 🙂',
        'Quick check-in: what are you working on today?',
        'Tip: set a 25-minute timer and do one focused sprint.',
        'Drop your hardest question here — someone will help!',
        'If you joined recently, introduce yourself 👋',
      ];
      final text = '[Auto] ${messages[_rng.nextInt(messages.length)]}';

      // insert message
      final messageId = await db_.insert('messages', {
        'groupId': groupId,
        'sessionId': null,
        'creatorId': systemUserId,
        'text': text,
        'date': DateTime.now().millisecondsSinceEpoch,
      });

      // notify group members (reuses your existing pipeline)
      await db.insertNotificationsForNewMessage(groupId, messageId, systemUserId);

      print('[AUTO] Sent message to "$groupName" (groupId=$groupId)');
    } catch (e) {
      int a = 1;
    } finally {
      _running = false;
    }
  }
}