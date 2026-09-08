import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_language.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_auth_service.dart';

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
  bool _loading = true;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
    _loadAppointmentNotifications();
  }

  Future<void> _checkNotificationPermission() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        if (mounted) setState(() => _notificationsEnabled = true);
        return;
      }
      final permission = await Permission.notification.status;
      var enabled = permission.isGranted;
      if (Platform.isAndroid && enabled) {
        enabled =
            await FlutterLocalNotificationsPlugin()
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.areNotificationsEnabled() ??
            enabled;
      }
      if (mounted) setState(() => _notificationsEnabled = enabled);
    } catch (error) {
      debugPrint('Notification permission check failed: $error');
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    if (!enabled) {
      await openAppSettings();
      return;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      setState(() => _notificationsEnabled = true);
      return;
    }

    final permission = await Permission.notification.request();
    if (!mounted) return;
    if (permission.isGranted) {
      setState(() => _notificationsEnabled = true);
      return;
    }

    if (permission.isPermanentlyDenied) {
      await openAppSettings();
    }
    await _checkNotificationPermission();
  }

  Future<void> _loadAppointmentNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final welcomeSent = prefs.getBool('welcome_notification_sent') ?? false;
      final service = SupabaseAuthService();
      final user = service.client.auth.currentUser;
      if (user == null) {
        return;
      }
      final rows = await service.client
          .from('appointments')
          .select(
            'service_type, appointment_date, appointment_time, appointment_status, created_at',
          )
          .eq('booker_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _showWelcomeNotification = welcomeSent;
          _appointmentNotifications = (rows as List)
              .map((row) => row as Map<String, dynamic>)
              .toList();
        });
      }
    } catch (error) {
      debugPrint('Notifications load failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _triggerTestNotification() async {
    await NotificationService().showNotification(
      id: 101,
      title: t(context, 'notificationTestTitle'),
      body: t(context, 'notificationTestBody'),
      payload: 'test_payload',
    );
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
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Notifikasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.notification_add_rounded, color: _c700),
                onPressed: _triggerTestNotification,
                tooltip: 'Test Notifikasi',
              ),
            ],
          ),
          SliverToBoxAdapter(child: _buildNotificationToggle()),
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
                  final notif = _showWelcomeNotification && index == 0
                      ? _buildWelcomeNotification(context)
                      : _buildAppointmentNotification(
                          context,
                          _appointmentNotifications[index -
                              (_showWelcomeNotification ? 1 : 0)],
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

  Widget _buildNotificationToggle() => Container(
    margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: _ink.withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _c500.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_active_outlined,
            color: _c700,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(context, 'notifPushTitle'),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                t(context, 'notifPushSubtitle'),
                style: const TextStyle(color: _ink2, fontSize: 11),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: _notificationsEnabled,
          activeThumbColor: _c500,
          onChanged: _toggleNotifications,
        ),
      ],
    ),
  );

  Map<String, dynamic> _buildAppointmentNotification(
    BuildContext context,
    Map<String, dynamic> row,
  ) {
    final service = row['service_type']?.toString() ?? 'Home Care';
    final date = row['appointment_date']?.toString() ?? '-';
    final time = row['appointment_time']?.toString() ?? '-';
    final status = row['appointment_status']?.toString();
    return {
      'title': t(context, 'notificationReservationTitle'),
      'body': t(context, 'notificationReservationBody')
          .replaceFirst(
            '{service}',
            service == 'Klinik' ? t(context, 'klinik') : t(context, 'homeCare'),
          )
          .replaceFirst('{date}', date)
          .replaceFirst('{time}', time),
      'time': switch (status) {
        'completed' => t(context, 'statusDone'),
        'expired' => t(context, 'statusExpired'),
        'cancelled' => t(context, 'statusCancelled'),
        _ => t(context, 'statusUpcoming'),
      },
      'icon': Icons.calendar_month_rounded,
      'color': _c500,
      'isUnread': true,
    };
  }

  Map<String, dynamic> _buildWelcomeNotification(BuildContext context) => {
    'title': t(context, 'welcomeNotificationTitle'),
    'body': t(context, 'welcomeNotificationBody'),
    'time': t(context, 'notificationJustNow'),
    'icon': Icons.celebration_rounded,
    'color': _c500,
    'isUnread': true,
  };

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final bool isUnread = notif['isUnread'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
    );
  }
}
