import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firestore_service.dart';
import 'notification_service.dart';

class PushNotificationService {
  PushNotificationService(
    this._messaging,
    this._firestoreService,
    this._notificationService,
  );

  final FirebaseMessaging _messaging;
  final FirestoreService _firestoreService;
  final NotificationService _notificationService;
  String? _initializedForUser;

  Future<void> initForUser(String userId) async {
    if (_initializedForUser == userId) return;
    _initializedForUser = userId;

    await _notificationService.init();
    await _requestPermission();

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _firestoreService.addFcmToken(userId, token);
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      if (newToken.isNotEmpty) {
        await _firestoreService.addFcmToken(userId, newToken);
      }
    });

    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;
      await _notificationService.showStatusUpdate(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: notification.title ?? 'Order Update',
        body: notification.body ?? 'Your order has been updated.',
      );
    });
  }

  Future<void> _requestPermission() async {
    if (kIsWeb) {
      await _messaging.requestPermission();
      return;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      return;
    }
    await _messaging.requestPermission();
  }
}
