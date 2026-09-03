import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import '../../l10n/app_language.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen>
    with WidgetsBindingObserver {
  // Theme colors
  static const _c700 = Color(0xFF007F78);
  static const _c500 = Color(0xFF00A79D);
  static const _bg   = Color(0xFFF0F7F7);
  static const _ink  = Color(0xFF0E2C2F);
  static const _ink2 = Color(0xFF436569);
  static const _ink3 = Color(0xFF8AA8AC);

  bool _isLoading = true;
  bool _systemPermissionGranted = false;
  bool _pushEnabled = true;
  bool _promoEnabled = true;
  bool _reminderEnabled = true;
  bool _emailEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check system permission ketika user kembali dari Settings HP
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSystemPermission();
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _checkSystemPermission(),
      _loadPreferences(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _checkSystemPermission() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() => _systemPermissionGranted = status.isGranted);
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _pushEnabled     = prefs.getBool('pref_notif_push')     ?? true;
        _promoEnabled    = prefs.getBool('pref_notif_promo')    ?? true;
        _reminderEnabled = prefs.getBool('pref_notif_reminder') ?? true;
        _emailEnabled    = prefs.getBool('pref_notif_email')    ?? false;
      });
    }
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  /// Handle toggle utama "Izinkan Notifikasi"
  Future<void> _handlePushToggle(bool val) async {
    if (val) {
      // User mau nyalakan → minta izin ke sistem
      final status = await Permission.notification.request();
      if (status.isGranted) {
        setState(() {
          _systemPermissionGranted = true;
          _pushEnabled = true;
        });
        await _savePreference('pref_notif_push', true);
      } else if (status.isPermanentlyDenied) {
        // User sudah permanently denied → buka pengaturan HP
        if (mounted) _showGoToSettingsDialog();
      }
      // Kalau denied biasa, biarkan toggle tetap off
    } else {
      // User mau matikan → arahkan ke pengaturan HP
      if (mounted) _showGoToSettingsDialog(isDisabling: true);
    }
  }

  void _showGoToSettingsDialog({bool isDisabling = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isDisabling
              ? 'Matikan Notifikasi?'
              : 'Izin Notifikasi Diperlukan',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        content: Text(
          isDisabling
              ? 'Untuk mematikan notifikasi, buka Pengaturan HP dan nonaktifkan notifikasi untuk aplikasi ini.'
              : 'Izin notifikasi ditolak. Buka Pengaturan HP untuk mengaktifkannya secara manual.',
          style: const TextStyle(fontSize: 13, color: _ink2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: _ink3)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Buka halaman notifikasi langsung di pengaturan HP
              AppSettings.openAppSettings(type: AppSettingsType.notification);
            },
            child: Text(
              'Buka Pengaturan',
              style: TextStyle(
                color: _c700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool disabled = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFF5F8F8) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: disabled ? 0.02 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: disabled ? _ink3 : _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: disabled ? _ink3 : _ink2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          CupertinoSwitch(
            value: value && !disabled,
            activeTrackColor: _c500,
            inactiveTrackColor: disabled ? const Color(0xFFDDE5E6) : null,
            onChanged: disabled ? null : onChanged,
          ),
        ],
      ),
    );
  }

  /// Banner peringatan kalau izin sistem dicabut dari HP
  Widget _buildSystemDeniedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB74D), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifikasi diblokir di pengaturan HP',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Aktifkan izin notifikasi di Pengaturan HP agar notifikasi dapat diterima.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFBF360C)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => AppSettings.openAppSettings(type: AppSettingsType.notification),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Buka',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Efektif aktif = izin sistem granted DAN user mengaktifkan di app
    final bool effectivePushOn = _systemPermissionGranted && _pushEnabled;
    final bool subItemsDisabled = !effectivePushOn;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          t(context, 'menuNotificationSub'),
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: _ink),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _c700))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner peringatan kalau izin sistem dicabut
                  if (!_systemPermissionGranted) _buildSystemDeniedBanner(),

                  Text(
                    t(context, 'notifSectionPush'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: _c700),
                  ),
                  const SizedBox(height: 12),

                  // Toggle utama — terhubung langsung ke izin sistem HP
                  _buildSwitchItem(
                    title: t(context, 'notifPushTitle'),
                    subtitle: _systemPermissionGranted
                        ? t(context, 'notifPushSubtitle')
                        : 'Izin notifikasi diblokir di pengaturan HP',
                    value: effectivePushOn,
                    onChanged: _handlePushToggle,
                  ),

                  // Sub-item — disabled kalau push utama mati
                  _buildSwitchItem(
                    title: t(context, 'notifReminderTitle'),
                    subtitle: t(context, 'notifReminderSubtitle'),
                    value: _reminderEnabled,
                    disabled: subItemsDisabled,
                    onChanged: (val) {
                      setState(() => _reminderEnabled = val);
                      _savePreference('pref_notif_reminder', val);
                    },
                  ),
                  _buildSwitchItem(
                    title: t(context, 'notifPromoTitle'),
                    subtitle: t(context, 'notifPromoSubtitle'),
                    value: _promoEnabled,
                    disabled: subItemsDisabled,
                    onChanged: (val) {
                      setState(() => _promoEnabled = val);
                      _savePreference('pref_notif_promo', val);
                    },
                  ),

                  const SizedBox(height: 24),
                  Text(
                    t(context, 'notifSectionEmail'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: _c700),
                  ),
                  const SizedBox(height: 12),
                  _buildSwitchItem(
                    title: t(context, 'notifEmailTitle'),
                    subtitle: t(context, 'notifEmailSubtitle'),
                    value: _emailEnabled,
                    onChanged: (val) {
                      setState(() => _emailEnabled = val);
                      _savePreference('pref_notif_email', val);
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
