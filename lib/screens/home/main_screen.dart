import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_language.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_auth_service.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'edit_profile_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

/// Shell utama aplikasi dengan bottom navigation.
class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    this.initialIndex = 0,
    this.initialHistoryFilter = 0,
  });

  /// 0 = Beranda, 1 = Progress, 2 = Janji Temu, 3 = Profil
  final int initialIndex;
  final int initialHistoryFilter;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  bool _showProfileNotice = false;
  bool _isCheckingProfile = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    appLanguageNotifier.addListener(_handleLanguageChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
      _syncAppointmentReminders();
      _checkProfileForHomeNotice();
    });
  }

  void _handleLanguageChanged() {
    if (mounted) _syncAppointmentReminders();
  }

  @override
  void dispose() {
    appLanguageNotifier.removeListener(_handleLanguageChanged);
    super.dispose();
  }

  Future<void> _checkProfileForHomeNotice() async {
    if (_isCheckingProfile) return;
    _isCheckingProfile = true;
    try {
      final service = SupabaseAuthService();
      if (service.client.auth.currentUser == null) return;
      final profile = await service.checkUserProfileExists();
      final nik = profile?['nik']?.toString().trim() ?? '';
      final address = profile?['address']?.toString().trim() ?? '';
      if (!mounted ||
          profile == null ||
          (RegExp(r'^\d{16}$').hasMatch(nik) && address.isNotEmpty)) {
        return;
      }
      setState(() => _showProfileNotice = true);
    } catch (error) {
      debugPrint('Home profile notice check failed: $error');
    } finally {
      _isCheckingProfile = false;
    }
  }

  Future<void> _openProfileFromHomeNotice() async {
    setState(() => _showProfileNotice = false);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (mounted) _checkProfileForHomeNotice();
  }

  Future<void> _syncAppointmentReminders() async {
    final service = SupabaseAuthService();
    final user = service.client.auth.currentUser;
    if (user == null) return;
    try {
      final expiredTitle = t(context, 'expiredAppointmentTitle');
      final expiredBody = t(context, 'expiredAppointmentBody');
      final now = DateTime.now();
      final rowsBeforeExpire = await service.client
          .from('appointments')
          .select('id, appointment_date, appointment_time, appointment_status')
          .eq('booker_id', user.id)
          .eq('appointment_status', 'upcoming');
      final expiredCandidates = (rowsBeforeExpire as List)
          .cast<Map<String, dynamic>>()
          .where((row) {
            final scheduled = DateTime.tryParse(
              '${row['appointment_date']} ${row['appointment_time']}',
            );
            return scheduled != null &&
                !scheduled.add(const Duration(minutes: 15)).isAfter(now);
          })
          .toList();
      await service.expireOverdueAppointments();
      final prefs = await SharedPreferences.getInstance();
      final notifiedExpired =
          prefs.getStringList('expired_notifications_sent')?.toSet() ?? {};
      for (final row in expiredCandidates) {
        final id = row['id']?.toString() ?? '';
        if (id.isEmpty || notifiedExpired.contains(id)) continue;
        await NotificationService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
          title: expiredTitle,
          body: expiredBody,
          payload: 'expired:$id',
        );
        notifiedExpired.add(id);
      }
      await prefs.setStringList(
        'expired_notifications_sent',
        notifiedExpired.toList(),
      );
      await NotificationService().cancelAllAppointmentReminders();
      final rows = await service.client
          .from('appointments')
          .select('id, appointment_date, appointment_time, appointment_status')
          .eq('booker_id', user.id)
          .eq('appointment_status', 'upcoming');
      if (!mounted) return;
      final reminderTitle = t(context, 'appointmentReminderTitle');
      final reminderBody = t(context, 'appointmentReminderBody');
      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        await NotificationService().scheduleAppointmentReminder(
          appointmentId: row['id'].toString(),
          date: row['appointment_date'].toString(),
          time: row['appointment_time'].toString(),
          title: reminderTitle,
          body: reminderBody.replaceFirst(
            '{time}',
            row['appointment_time'].toString(),
          ),
        );
        await NotificationService().scheduleExpirationNotice(
          appointmentId: row['id'].toString(),
          date: row['appointment_date'].toString(),
          time: row['appointment_time'].toString(),
          title: expiredTitle,
          body: expiredBody,
        );
      }
    } catch (error) {
      debugPrint('Startup appointment reminder sync failed: $error');
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notification_permission_prompted') ?? false) return;
    await Permission.notification.request();
    await prefs.setBool('notification_permission_prompted', true);
  }

  static const _teal = Color(0xFF00A79D);
  static const _grey = Color(0xFFB0BEC5);

  List<({IconData icon, String labelKey})> get _tabs => [
    (icon: Icons.home_rounded, labelKey: 'tabBeranda'),
    (icon: Icons.bar_chart_rounded, labelKey: 'tabProgress'),
    (icon: Icons.event_note_rounded, labelKey: 'tabJanjiTemu'),
    (icon: Icons.person_rounded, labelKey: 'tabProfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F8),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(child: _buildCurrentTab()),
                _buildBottomNav(),
              ],
            ),
          ),
          if (_showProfileNotice) _buildProfileNoticeOverlay(),
        ],
      ),
    );
  }

  Widget _buildProfileNoticeOverlay() => Positioned.fill(
    child: Material(
      color: const Color(0x990E2C2F),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x45000000),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
                border: Border.all(color: Color(0xFFE6EEEE), width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4D8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFE3A1),
                        width: 5,
                      ),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFE59D2A),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t(context, 'profileRequiredBadge'),
                      style: TextStyle(
                        color: _teal,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t(context, 'incompleteProfileTitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF0E2C2F),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(context, 'profileRequiredMessage'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF3D6065),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _openProfileFromHomeNotice,
                      style: FilledButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(t(context, 'profileRequiredAction')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildCurrentTab() {
    final child = switch (_currentIndex) {
      0 => const HomeBody(),
      1 => const ProgressBody(),
      2 => HistoryBody(initialFilterIndex: widget.initialHistoryFilter),
      _ => const SettingsBody(),
    };
    return _AnimatedTab(key: ValueKey(_currentIndex), child: child);
  }

  Widget _buildBottomNav() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    const navHeight = 64.0;

    return SizedBox(
      height: navHeight + (bottomPad > 0 ? bottomPad : 12),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad > 0 ? bottomPad : 12),
        child: Container(
          height: navHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final active = i == _currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Indicator garis teal di atas saat aktif
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        height: 3,
                        width: active ? 28 : 0,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: _teal,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Icon(tab.icon, size: 22, color: active ? _teal : _grey),
                      const SizedBox(height: 3),
                      Text(
                        t(context, tab.labelKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: active ? _teal : _grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Wrapper animasi tab ───────────────────────────────────────────────────────

class _AnimatedTab extends StatefulWidget {
  final Widget child;
  const _AnimatedTab({super.key, required this.child});

  @override
  State<_AnimatedTab> createState() => _AnimatedTabState();
}

class _AnimatedTabState extends State<_AnimatedTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}
