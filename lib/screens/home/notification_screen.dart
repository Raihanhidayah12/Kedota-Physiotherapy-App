import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import 'appointment_detail_screen.dart';
import 'history_screen.dart';
import 'settle_payment_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Theme colors
  static const _c700 = Color(0xFF007F78);
  static const _c500 = Color(0xFF00A79D);
  static const _bg = Color(0xFFF0F7F7);
  static const _ink = Color(0xFF0E2C2F);
  static const _ink2 = Color(0xFF436569);
  static const _ink3 = Color(0xFF8AA8AC);
  List<Map<String, dynamic>> _appointmentNotifications = [];
  bool _showWelcomeNotification = false;
  DateTime? _welcomeNotificationCreatedAt;
  int _welcomeIndex = -1;
  bool _loading = true;
  bool _notificationsRead = false;

  @override
  void initState() {
    super.initState();
    _loadAppointmentNotifications();
  }

  Future<void> _loadAppointmentNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final welcomeSent = prefs.getBool('welcome_notification_sent') ?? false;
      final welcomeCreatedAt = DateTime.tryParse(
        prefs.getString('welcome_notification_created_at') ?? '',
      );
      final notificationsRead =
          prefs.getBool('notifications_marked_as_read') ?? false;
      final service = SupabaseAuthService();
      final user = service.client.auth.currentUser;
      if (user == null) {
        return;
      }
      await service.expireOverdueAppointments();
      final rows = await service.client
          .from('appointments')
          .select()
          .eq('booker_id', user.id);
      final rescheduleEvents =
          (prefs.getStringList('reschedule_notifications') ?? [])
              .map((event) {
                try {
                  final decoded = jsonDecode(event);
                  return decoded is Map<String, dynamic> ? decoded : null;
                } catch (_) {
                  return null;
                }
              })
              .whereType<Map<String, dynamic>>()
              .where((event) => event['booker_id'] == user.id)
              .where((event) {
                final scheduledFor = DateTime.tryParse(
                  event['scheduled_for']?.toString() ?? '',
                );
                return scheduledFor == null ||
                    !scheduledFor.isAfter(DateTime.now());
              })
              .map(
                (event) => <String, dynamic>{
                  ...event,
                  'id': event['appointment_id'],
                  'notification_type': 'rescheduled',
                },
              )
              .toList()
              .reversed
              .toList();
      final paymentEvents = (prefs.getStringList('payment_notifications') ?? [])
          .map((event) {
            try {
              final decoded = jsonDecode(event);
              return decoded is Map<String, dynamic> ? decoded : null;
            } catch (_) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .where((event) => event['booker_id'] == user.id)
          .map(
            (event) => <String, dynamic>{
              ...event,
              'id': event['appointment_id'],
              'notification_type': 'payment_completed',
            },
          )
          .toList()
          .reversed
          .toList();
      final reminderEvents =
          (prefs.getStringList('reminder_notifications') ?? [])
              .map((event) {
                try {
                  final decoded = jsonDecode(event);
                  return decoded is Map<String, dynamic> ? decoded : null;
                } catch (_) {
                  return null;
                }
              })
              .whereType<Map<String, dynamic>>()
              .where((event) => event['booker_id'] == user.id)
              .map(
                (event) => <String, dynamic>{
                  ...event,
                  'id': event['appointment_id'],
                  'notification_type': 'reminder',
                },
              )
              .toList()
              .reversed
              .toList();
      final notifications = [
        ...paymentEvents,
        ...rescheduleEvents,
        ...reminderEvents,
        ...(rows as List).map((row) => row as Map<String, dynamic>),
      ];
      notifications.sort(
        (first, second) => _notificationCreatedAt(
          second,
        ).compareTo(_notificationCreatedAt(first)),
      );
      final welcomeIndex = welcomeSent
          ? welcomeCreatedAt == null
                ? 0
                : notifications
                      .where(
                        (notification) => _notificationCreatedAt(
                          notification,
                        ).isAfter(welcomeCreatedAt),
                      )
                      .length
          : -1;
      if (mounted) {
        setState(() {
          _showWelcomeNotification = welcomeSent;
          _welcomeNotificationCreatedAt = welcomeCreatedAt;
          _welcomeIndex = welcomeIndex;
          _notificationsRead = notificationsRead;
          _appointmentNotifications = notifications;
        });
      }
    } catch (error) {
      debugPrint('Notifications load failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_marked_as_read', true);
    await prefs.setInt(
      'notifications_last_read_at',
      DateTime.now().millisecondsSinceEpoch,
    );
    if (mounted) {
      setState(() => _notificationsRead = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'notificationsMarkedRead'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: _bg,
            foregroundColor: _ink,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(_notificationsRead),
            ),
            title: Text(
              t(context, 'notificationScreenTitle'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(
                  _notificationsRead
                      ? Icons.mark_email_read_outlined
                      : Icons.mark_email_unread_outlined,
                  color: _c700,
                ),
                onPressed: _notificationsRead ? null : _markAllAsRead,
                disabledColor: _c500,
                tooltip: t(context, 'markNotificationsRead'),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (_loading) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(
                        child: CircularProgressIndicator(color: _c500),
                      ),
                    );
                  }
                  if (_appointmentNotifications.isEmpty &&
                      !_showWelcomeNotification) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Center(
                        child: Text(
                          t(context, 'noNotifications'),
                          style: const TextStyle(color: _ink3),
                        ),
                      ),
                    );
                  }
                  final notif =
                      _showWelcomeNotification && index == _welcomeIndex
                      ? _buildWelcomeNotification(context)
                      : _buildAppointmentNotification(
                          context,
                          _appointmentNotifications[index -
                              (_showWelcomeNotification && index > _welcomeIndex
                                  ? 1
                                  : 0)],
                        );
                  return _buildNotificationCard(notif);
                },
                childCount:
                    _loading ||
                        (_appointmentNotifications.isEmpty &&
                            !_showWelcomeNotification)
                    ? 1
                    : _appointmentNotifications.length +
                          (_showWelcomeNotification ? 1 : 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildAppointmentNotification(
    BuildContext context,
    Map<String, dynamic> row,
  ) {
    final service = row['service_type']?.toString() ?? 'Home Care';
    final date = row['appointment_date']?.toString() ?? '-';
    final time = row['appointment_time']?.toString() ?? '-';
    final isRescheduled = row['notification_type'] == 'rescheduled';
    final isPaymentCompleted = row['notification_type'] == 'payment_completed';
    final isReminder = row['notification_type'] == 'reminder';
    final paymentStatus =
        row['payment_status']?.toString().toLowerCase() ?? 'paid';
    final paymentPlan = row['payment_plan']?.toString().toLowerCase() ?? 'full';
    final amountDue = int.tryParse(row['amount_due']?.toString() ?? '') ?? 0;
    final hasOutstandingPayment =
        (paymentPlan == 'deposit' && paymentStatus != 'paid') ||
        (amountDue > 0 && paymentStatus != 'paid');
    return {
      'appointment_id': row['id']?.toString() ?? '',
      'title': isReminder
          ? row['title']?.toString() ?? t(context, 'appointmentReminderTitle')
          : isPaymentCompleted
          ? t(context, 'paymentSuccessTitle')
          : isRescheduled
          ? t(context, 'notificationScheduleUpdatedTitle')
          : hasOutstandingPayment
          ? t(context, 'paymentPendingNotificationTitle')
          : t(context, 'notificationReservationTitle'),
      'body': isReminder
          ? row['body']?.toString() ?? t(context, 'appointmentReminderBody')
          : isPaymentCompleted
          ? t(context, 'paymentSuccessDesc')
                .replaceFirst('{date}', date)
                .replaceFirst(
                  '{clinic}',
                  row['clinic_name']?.toString().isNotEmpty == true
                      ? row['clinic_name'].toString()
                      : service,
                )
          : isRescheduled
          ? '${t(context, 'notificationScheduleUpdatedBody')} ${_formatDateTime(date, time)}'
          : hasOutstandingPayment
          ? '${t(context, 'paymentPendingNotificationBody')} ${_formatDateTime(date, time)}'
          : t(context, 'notificationReservationBody')
                .replaceFirst(
                  '{service}',
                  service == 'Klinik'
                      ? t(context, 'klinik')
                      : t(context, 'homeCare'),
                )
                .replaceFirst('{date}', date)
                .replaceFirst('{time}', time),
      'time': _formatRelativeTime(context, _notificationCreatedAt(row)),
      'icon': isReminder
          ? Icons.alarm_rounded
          : isPaymentCompleted
          ? Icons.check_circle_rounded
          : isRescheduled
          ? Icons.edit_calendar_rounded
          : hasOutstandingPayment
          ? Icons.account_balance_wallet_rounded
          : Icons.calendar_month_rounded,
      'color': isPaymentCompleted || isRescheduled
          ? _c500
          : hasOutstandingPayment
          ? const Color(0xFFD94F45)
          : _c500,
      'isUnread': !_notificationsRead,
      if (hasOutstandingPayment) 'appointment': row,
    };
  }

  String _formatDateTime(String date, String time) => '$date, $time WIB';

  DateTime _notificationCreatedAt(Map<String, dynamic> row) {
    return DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatRelativeTime(BuildContext context, DateTime createdAt) {
    final elapsed = DateTime.now().difference(createdAt);
    final duration = elapsed.isNegative ? Duration.zero : elapsed;
    if (duration.inMinutes < 1) return t(context, 'notificationJustNow');
    if (duration.inHours < 1) {
      return t(
        context,
        'notificationMinutesAgo',
      ).replaceFirst('{minutes}', '${duration.inMinutes}');
    }
    if (duration.inHours < 24) {
      return t(
        context,
        'notificationHoursAgo',
      ).replaceFirst('{hours}', '${duration.inHours}');
    }
    if (duration.inHours < 48) return t(context, 'notificationYesterday');
    return t(
      context,
      'notificationDaysAgo',
    ).replaceFirst('{days}', '${duration.inDays}');
  }

  Future<void> _openPayment(Map<String, dynamic> row) async {
    final item = AppointmentItem(
      id: row['id']?.toString() ?? '',
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
      paymentStatus: row['payment_status']?.toString() ?? 'pending',
      paymentPlan: row['payment_plan']?.toString() ?? 'deposit',
      amountDue: int.tryParse(row['amount_due']?.toString() ?? '') ?? 0,
      status: AppointmentStatus.mendatang,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettlePaymentScreen(appointment: item)),
    );
    if (mounted) _loadAppointmentNotifications();
  }

  Future<void> _openAppointmentDetail(String appointmentId) async {
    if (appointmentId.isEmpty) return;
    try {
      final row = await SupabaseAuthService().client
          .from('appointments')
          .select()
          .eq('id', appointmentId)
          .maybeSingle();
      if (row == null || !mounted) return;
      final rawStatus = row['appointment_status']?.toString();
      final scheduledAt = DateTime.tryParse(
        '${row['appointment_date']} ${row['appointment_time']}',
      );
      final locallyExpired =
          scheduledAt != null &&
          !scheduledAt.add(const Duration(minutes: 15)).isAfter(DateTime.now());
      final item = AppointmentItem(
        id: row['id']?.toString() ?? appointmentId,
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
        status: rawStatus == 'completed'
            ? AppointmentStatus.selesai
            : rawStatus == 'expired'
            ? AppointmentStatus.batasWaktu
            : locallyExpired
            ? AppointmentStatus.batasWaktu
            : AppointmentStatus.mendatang,
      );
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AppointmentDetailScreen(item: item)),
      );
    } catch (error) {
      debugPrint('Notification appointment detail load failed: $error');
    }
  }

  Map<String, dynamic> _buildWelcomeNotification(BuildContext context) => {
    'title': t(context, 'welcomeNotificationTitle'),
    'body': t(context, 'welcomeNotificationBody'),
    'time': _formatRelativeTime(
      context,
      _welcomeNotificationCreatedAt ?? DateTime.now(),
    ),
    'icon': Icons.celebration_rounded,
    'color': _c500,
    'isUnread': !_notificationsRead,
  };

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final bool isUnread = notif['isUnread'];
    final appointment = notif['appointment'];
    final appointmentId = notif['appointment_id']?.toString() ?? '';

    return GestureDetector(
      onTap: appointment is Map<String, dynamic>
          ? () => _openPayment(appointment)
          : appointmentId.isNotEmpty
          ? () => _openAppointmentDetail(appointmentId)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: appointment is Map<String, dynamic>
              ? Border.all(color: const Color(0xFFFFD5D2))
              : null,
          boxShadow: [
            BoxShadow(
              color: _ink.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: notif['color'].withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(notif['icon'], color: notif['color'], size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif['title'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isUnread
                                ? FontWeight.w800
                                : FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notif['body'],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _ink2,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    notif['time'],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _ink3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
