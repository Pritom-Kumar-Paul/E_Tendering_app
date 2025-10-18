import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 1) Local notifications init (Android/iOS/macOS)
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _local.initialize(initSettings);

    // 2) FCM শুধুমাত্র Android/iOS/Web এ
    final fcmSupported = kIsWeb || Platform.isAndroid || Platform.isIOS;
    if (!fcmSupported) {
      // macOS/Windows/Linux → FCM skip
      return;
    }

    // 3) Permission
    try {
      if (kIsWeb || Platform.isIOS) {
        await _messaging.requestPermission();
      } else if (Platform.isAndroid) {
        // Android 13+ runtime permission (optional but recommended)
        final androidImpl = _local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidImpl?.requestNotificationsPermission();
      }
    } catch (_) {
      // Ignore permission errors to avoid crash
    }

    // 4) Foreground messages → show local notification
    FirebaseMessaging.onMessage.listen((msg) {
      final title = msg.notification?.title ?? 'Notification';
      final body = msg.notification?.body ?? '';
      _local.show(
        msg.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel',
            'General',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    });

    // 5) Background handler (Android/Web only)
    if (kIsWeb || Platform.isAndroid) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    }

    // 6) Save FCM token to Firestore
    try {
      final token = await _messaging.getToken();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Ignore token errors on unsupported envs
    }

    // 7) iOS foreground presentation options
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op; required to register handler on Android/Web.
}
