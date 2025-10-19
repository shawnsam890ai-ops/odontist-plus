import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _flnp = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Timezone setup
    // Initialize available tz data and use platform default local without explicit name lookup.
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
    const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _flnp.initialize(initSettings,
        onDidReceiveNotificationResponse: (response) async {
      // Handle notification taps if needed
      debugPrint('Notification tapped: ${response.payload}');
    });

    // Android 13+ notification permission
  await _flnp
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.requestNotificationsPermission();

    // iOS permissions
    await _flnp.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);

    // Create default channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'appointments_channel',
      'Appointments',
      description: 'Reminders for scheduled appointments',
      importance: Importance.high,
    );
    await _flnp.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> scheduleAppointmentNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (!_initialized) await init();
    final tz.TZDateTime when = tz.TZDateTime.from(scheduledTime, tz.local);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) {
      // Do not schedule in the past
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'appointments_channel',
      'Appointments',
      channelDescription: 'Reminders for scheduled appointments',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _flnp.zonedSchedule(
      id,
      title,
      body,
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> cancel(int id) async {
    if (!_initialized) await init();
    await _flnp.cancel(id);
  }

  Future<void> cancelAll() async {
    if (!_initialized) await init();
    await _flnp.cancelAll();
  }
}
