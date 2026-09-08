import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle ketika notifikasi di-tap
        if (response.payload != null) {
          developer.log('Notification payload: ${response.payload}');
        }
      },
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleAppointmentReminder({
    required String appointmentId,
    required String date,
    required String time,
    required String title,
    required String body,
  }) async {
    final appointmentDateTime = DateTime.tryParse('$date $time');
    if (appointmentDateTime == null) return;

    final reminderDateTime = appointmentDateTime.subtract(
      const Duration(hours: 1),
    );
    if (!reminderDateTime.isAfter(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'kedota_appointment_reminders',
      'Pengingat Janji Temu',
      channelDescription: 'Pengingat satu jam sebelum janji temu',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final scheduledDate = tz.TZDateTime.from(reminderDateTime, tz.local);
    try {
      await _scheduleReminder(
        id: _notificationId(appointmentId),
        title: title,
        body: body,
        date: scheduledDate,
        details: notificationDetails,
        mode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'appointment:$appointmentId',
      );
    } on PlatformException catch (error) {
      developer.log(
        'Exact alarm unavailable; using inexact reminder instead: $error',
      );
      await _scheduleReminder(
        id: _notificationId(appointmentId),
        title: title,
        body: body,
        date: scheduledDate,
        details: notificationDetails,
        mode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'appointment:$appointmentId',
      );
    }
  }

  Future<void> _scheduleReminder({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime date,
    required NotificationDetails details,
    required AndroidScheduleMode mode,
    required String payload,
  }) {
    return _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      date,
      details,
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> cancelAppointmentReminder(String appointmentId) {
    return _flutterLocalNotificationsPlugin.cancel(
      _notificationId(appointmentId),
    );
  }

  int _notificationId(String appointmentId) =>
      (appointmentId.hashCode & 0x7fffffff).clamp(1, 2147483647).toInt();

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'kedota_main_channel',
          'Kedota Notifications',
          channelDescription: 'Notifikasi utama untuk aplikasi Kedota',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}
