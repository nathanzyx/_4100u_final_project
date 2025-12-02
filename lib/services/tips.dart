import 'dart:math';

// Simple local Study Tips service (no API needed)
// Each time the app loads, a random educational or motivational tip is shown.
class TipsService {
  // List of positive, education-friendly tips
  static final List<String> _tips = [
    'Study a little every day; consistency builds knowledge.',
    'Taking breaks helps your brain recharge; balance matters!',
    'Review what you learned before sleeping; your brain loves repetition.',
    'Ask questions; curiosity is the best way to learn deeply.',
    'A tidy study space helps you stay calm and focused.',
    'Learning something new each day keeps your mind healthy.',
    'Don’t fear mistakes; every error teaches you something valuable.',
    'Explaining what you’ve learned helps you remember it better.',
    'Drink water, move around, and take mindful breaths while studying.',
    'You don’t need to be perfect; progress happens one step at a time.',
    'Be proud of every small achievement; learning is growth!',
    'Your brain is like a muscle; keep training it with curiosity.',
    'Dream big, start small, and keep going; you’ve got this!',
  ];

  /// Returns a random positive study tip
  static Future<String> fetchDailyTip() async {
    await Future.delayed(const Duration(milliseconds: 300)); // mimic network delay  chat gpt did this one
    final random = Random();
    return _tips[random.nextInt(_tips.length)];
  }
}
