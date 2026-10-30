import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../screens/home/history_screen.dart';
import '../screens/home/appointment_detail_screen.dart';
import '../screens/home/reservation_flow_screen.dart';
import '../screens/home/settle_payment_screen.dart';
import 'supabase_auth_service.dart';
import '../widgets/app_lock_overlay.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> markNotificationsUnread() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_marked_as_read', false);
  }

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;
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
        final payload = response.payload;
        if (payload != null && payload.startsWith('deposit:')) {
          _openAppointmentPayment(payload.substring('deposit:'.length));
        } else if (payload != null && payload.startsWith('dp_forfeited:')) {
          // DP Hangus — buka detail, BUKAN payment screen
          _openAppointmentDetail(payload.substring('dp_forfeited:'.length));
        } else if (payload != null && payload.startsWith('expired:')) {
          _openAppointmentDetail(payload.substring('expired:'.length));
        } else if (payload != null && payload.startsWith('appointment:')) {
          _openAppointmentDetail(payload.substring('appointment:'.length));
        } else if (payload != null && payload.startsWith('review:')) {
          _openAppointmentDetail(payload.substring('review:'.length));
        } else if (payload != null && payload.startsWith('therapist:')) {
          _openAppointmentDetail(payload.substring('therapist:'.length));
        } else if (payload != null && payload.startsWith('exercise:')) {
          _openAppointmentDetail(payload.substring('exercise:'.length));
        } else if (payload != null && payload.startsWith('follow_up:')) {
          _openReservation();
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
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('pref_notif_push') ?? true) ||
        !(prefs.getBool('pref_notif_reminder') ?? true)) {
      return;
    }
    final appointmentDateTime = DateTime.tryParse('$date $time');
    if (appointmentDateTime == null) return;

    final now = DateTime.now();
    if (!appointmentDateTime.isAfter(now)) return;

    final scheduledReminderDateTime = appointmentDateTime.subtract(
      const Duration(hours: 1),
    );
    // If the one-hour point has already passed, remind immediately for an
    // appointment that is still upcoming instead of silently dropping it.
    final reminderDateTime = scheduledReminderDateTime.isAfter(now)
        ? scheduledReminderDateTime
        : now.add(const Duration(seconds: 2));

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
    await _saveReminderEvent(
      appointmentId: appointmentId,
      date: date,
      time: time,
      title: title,
      body: body,
      scheduledFor: reminderDateTime,
    );
  }

  Future<void> scheduleExpirationNotice({
    required String appointmentId,
    required String date,
    required String time,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('pref_notif_push') ?? true) || appointmentId.isEmpty) {
      return;
    }
    final appointmentDateTime = DateTime.tryParse('$date $time');
    if (appointmentDateTime == null) return;
    final expirationDateTime = appointmentDateTime.add(
      const Duration(minutes: 15),
    );
    if (!expirationDateTime.isAfter(DateTime.now())) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'kedota_appointment_expired',
        'Batas Waktu Janji Temu',
        channelDescription: 'Notifikasi saat janji temu melewati batas waktu',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      _expirationNotificationId(appointmentId),
      title,
      body,
      tz.TZDateTime.from(expirationDateTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'expired:$appointmentId',
    );
  }

  Future<void> _saveReminderEvent({
    required String appointmentId,
    required String date,
    required String time,
    required String title,
    required String body,
    required DateTime scheduledFor,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final events = prefs.getStringList('reminder_notifications') ?? [];
    final nextEvent = <String, dynamic>{
      'appointment_id': appointmentId,
      'booker_id': userId,
      'appointment_date': date,
      'appointment_time': time,
      'title': title,
      'body': body,
      'scheduled_for': scheduledFor.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };
    final filtered = events.where((event) {
      try {
        final decoded = jsonDecode(event);
        return decoded is! Map ||
            decoded['appointment_id'] != appointmentId ||
            decoded['appointment_date'] != date ||
            decoded['appointment_time'] != time;
      } catch (_) {
        return false;
      }
    }).toList();
    filtered.add(jsonEncode(nextEvent));
    await prefs.setStringList(
      'reminder_notifications',
      filtered.length > 20 ? filtered.sublist(filtered.length - 20) : filtered,
    );
    if (!scheduledFor.isAfter(DateTime.now())) {
      await markNotificationsUnread();
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

  Future<void> cancelAppointmentReminder(String appointmentId) async {
    if (kIsWeb) return;
    return _flutterLocalNotificationsPlugin.cancel(
      _notificationId(appointmentId),
    );
  }

  Future<void> cancelAllAppointmentReminders() async {
    if (kIsWeb) return;
    try {
      final pending = await _flutterLocalNotificationsPlugin
          .pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.payload?.startsWith('appointment:') ?? false) {
        await _flutterLocalNotificationsPlugin.cancel(notification.id);
      }
      if (notification.payload?.startsWith('expired:') ?? false) {
        await _flutterLocalNotificationsPlugin.cancel(notification.id);
      }
    }
    } catch (_) {}
  }

  int _notificationId(String appointmentId) {
    var hash = 2166136261;
    for (final codeUnit in appointmentId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  int _expirationNotificationId(String appointmentId) =>
      _notificationId('$appointmentId:expired');

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
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
    await markNotificationsUnread();
  }

  Future<void> _openAppointmentPayment(String appointmentId) async {
    if (appointmentId.isEmpty) return;
    try {
      final row = await Supabase.instance.client
          .from('appointments')
          .select()
          .eq('id', appointmentId)
          .maybeSingle();
      if (row == null) return;

      final item = _appointmentFromRow(row, appointmentId);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = appNavigatorKey.currentState;
        if (navigator == null) return;
        navigator.push(
          MaterialPageRoute(
            builder: (_) => SettlePaymentScreen(appointment: item),
          ),
        );
      });
    } catch (error) {
      developer.log('Notification deep link failed: $error');
    }
  }

  Future<void> _openAppointmentDetail(String appointmentId) async {
    if (appointmentId.isEmpty) return;
    try {
      final service = SupabaseAuthService();
      await service.expireOverdueAppointments();
      final row = await Supabase.instance.client
          .from('appointments')
          .select()
          .eq('id', appointmentId)
          .maybeSingle();
      if (row == null) return;
      final item = _appointmentFromRow(row, appointmentId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => AppointmentDetailScreen(item: item),
          ),
        );
      });
    } catch (error) {
      developer.log('Expired appointment deep link failed: $error');
    }
  }

  void _openReservation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const ReservationFlowScreen(),
        ),
      );
    });
  }

  Future<void> showReviewPromptNotification({
    required String appointmentId,
    required String therapistName,
    required String title,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('pref_notif_push') ?? true)) return;
    await showNotification(
      id: _notificationId('review:$appointmentId'),
      title: title,
      body: body,
      payload: 'review:$appointmentId',
    );
  }

  Future<void> showTherapistOnTheWayNotification({
    required String appointmentId,
    required String therapistName,
    required String title,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('pref_notif_push') ?? true)) return;
    await showNotification(
      id: _notificationId('therapist_otw:$appointmentId'),
      title: title,
      body: body,
      payload: 'therapist:$appointmentId',
    );
  }

  Future<void> showTherapistArrivedNotification({
    required String appointmentId,
    required String therapistName,
    required String title,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('pref_notif_push') ?? true)) return;
    await showNotification(
      id: _notificationId('therapist_arrived:$appointmentId'),
      title: title,
      body: body,
      payload: 'therapist:$appointmentId',
    );
  }

  Future<void> showExerciseNotesNotification({
    required String appointmentId,
    required String therapistName,
    required String title,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('pref_notif_push') ?? true)) return;
    await showNotification(
      id: _notificationId('exercise:$appointmentId'),
      title: title,
      body: body,
      payload: 'exercise:$appointmentId',
    );
  }

  Future<void> showFollowUpReminderNotification({
    required String title,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('pref_notif_push') ?? true) ||
        !(prefs.getBool('pref_notif_reminder') ?? true)) {
      return;
    }
    await showNotification(
      id: 300,
      title: title,
      body: body,
      payload: 'follow_up:',
    );
  }

  Future<void> showSecurityAlertNotification({
    required String title,
    required String body,
  }) async {
    await showNotification(
      id: 400 + DateTime.now().second,
      title: title,
      body: body,
      payload: 'security:',
    );
  }

  /// Jadwalkan tips kesehatan berkala dengan rotasi tips yang berganti-ganti secara berurutan
  Future<void> scheduleRotatingHealthTip({
    required List<Map<String, String>> tips,
  }) async {
    if (kIsWeb || tips.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('pref_notif_push') ?? true) ||
        !(prefs.getBool('pref_notif_promo') ?? true)) {
      return;
    }

    final lastScheduled = prefs.getString('last_weekly_tip_scheduled');
    final now = DateTime.now();
    if (lastScheduled != null) {
      final lastDate = DateTime.tryParse(lastScheduled);
      if (lastDate != null && now.difference(lastDate).inDays < 3) {
        return;
      }
    }

    final lastIndex = prefs.getInt('last_health_tip_index') ?? -1;
    final nextIndex = (lastIndex + 1) % tips.length;
    final tip = tips[nextIndex];
    final title = tip['title'] ?? 'Kedota Care';
    final body = tip['body'] ?? '';

    final targetDate = now.add(const Duration(days: 3));
    final scheduledDate = tz.TZDateTime(
      tz.local,
      targetDate.year,
      targetDate.month,
      targetDate.day,
      14,
      0,
    );

    const androidDetails = AndroidNotificationDetails(
      'kedota_health_tips',
      'Tips Kesehatan & Edukasi',
      channelDescription: 'Edukasi dan tips fisioterapi berkala Kedota',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        999,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'health_tip:',
      );
      await prefs.setString('last_weekly_tip_scheduled', now.toIso8601String());
      await prefs.setInt('last_health_tip_index', nextIndex);
    } catch (_) {}
  }

  Future<void> scheduleWeeklyHealthTip({
    required String title,
    required String body,
  }) async {
    return scheduleRotatingHealthTip(tips: [
      {'title': title, 'body': body}
    ]);
  }

  AppointmentItem _appointmentFromRow(
    Map<String, dynamic> row,
    String fallbackId,
  ) {
    final rawStatus = row['appointment_status']?.toString();
    return AppointmentItem(
      id: row['id']?.toString() ?? fallbackId,
      therapistName: row['therapist_name']?.toString() ?? 'Kedota Therapist',
      serviceType: row['service_type']?.toString() ?? 'Home Care',
      date: row['appointment_date']?.toString() ?? '-',
      time: row['appointment_time']?.toString() ?? '- WIB',
      patientName: row['patient_full_name']?.toString() ?? '',
      medicalCode: row['patient_medical_code']?.toString() ?? '',
      address: row['address']?.toString() ?? '',
      complaint: row['patient_complaint']?.toString() ?? '',
      clinicName: row['clinic_name']?.toString() ?? '',
      sessionCount: int.tryParse(row['session_count']?.toString() ?? '') ?? 1,
      paymentStatus: row['payment_status']?.toString() ?? 'paid',
      paymentPlan: row['payment_plan']?.toString() ?? 'full',
      amountDue: int.tryParse(row['amount_due']?.toString() ?? '') ?? 0,
      bookedForOther: AppointmentItem.bookedForOtherFromRow(row),
      status: rawStatus == 'completed'
          ? AppointmentStatus.selesai
          : rawStatus == 'expired'
          ? AppointmentStatus.batasWaktu
          : AppointmentStatus.mendatang,
    );
  }
}
