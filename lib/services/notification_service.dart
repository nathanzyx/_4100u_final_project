import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/*

  NotificationService

  - For sending notifications to the user

*/
class NotificationService
{
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async
  {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
  }

  Future<void> showMessageNotification
  (
    String groupName,
    String messageText,
  ) async
  {
    const androidDetails = AndroidNotificationDetails
    (
      'messages_channel',
      'Messages',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show
    (
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      groupName,
      messageText,
      details
    );
  }
}
