import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<void> showStatusUpdate({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized || kIsWeb) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'order_updates',
        'Order Updates',
        channelDescription: 'Notifications for order, payment, and delivery updates',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
