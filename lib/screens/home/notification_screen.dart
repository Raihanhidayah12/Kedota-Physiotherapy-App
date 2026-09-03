import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Theme colors
  static const _c900 = Color(0xFF004D47);
  static const _c700 = Color(0xFF007F78);
  static const _c500 = Color(0xFF00A79D);
  static const _c100 = Color(0xFFD4F5F3);
  static const _bg   = Color(0xFFF0F7F7);
  static const _ink  = Color(0xFF0E2C2F);
  static const _ink2 = Color(0xFF436569);
  static const _ink3 = Color(0xFF8AA8AC);

  // Dummy notifications
  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Jadwal Fisioterapi Besok',
      'body': 'Jangan lupa jadwal sesi terapi Anda besok jam 10:00 WIB di Klinik Pusat.',
      'time': 'Baru saja',
      'icon': Icons.calendar_month_rounded,
      'color': _c500,
      'isUnread': true,
    },
    {
      'title': 'Update Profil Berhasil',
      'body': 'Data profil Anda telah berhasil diperbarui ke sistem kami.',
      'time': '2 jam yang lalu',
      'icon': Icons.check_circle_rounded,
      'color': Colors.green,
      'isUnread': true,
    },
    {
      'title': 'Promo Spesial 20%',
      'body': 'Dapatkan diskon 20% untuk paket terapi punggung. Berlaku hingga akhir bulan!',
      'time': 'Kemarin',
      'icon': Icons.local_offer_rounded,
      'color': Colors.orange,
      'isUnread': false,
    },
  ];

  void _triggerTestNotification() async {
    await NotificationService().showNotification(
      id: 101,
      title: 'Halo dari Kedota!',
      body: 'Ini adalah contoh notifikasi langsung dari aplikasi Anda.',
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
            title: const Text('Notifikasi',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.notification_add_rounded, color: _c700),
                onPressed: _triggerTestNotification,
                tooltip: 'Test Notifikasi',
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final notif = _notifications[index];
                  return _buildNotificationCard(notif);
                },
                childCount: _notifications.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          )
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
                          fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
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
