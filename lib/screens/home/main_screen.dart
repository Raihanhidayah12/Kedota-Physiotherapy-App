import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Shell utama aplikasi dengan bottom navigation.
/// Semua tab dikelola di sini via [IndexedStack] sehingga
/// navigasi antar tab tidak kehilangan state.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialIndex = 0});

  /// Tentukan tab awal (0 = Beranda, 3 = Riwayat, dst.)
  final int initialIndex;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  static const _teal = Color(0xFF00A79D);

  // Dynamic tabs (tidak bisa static const karena pakai t())
  List<({IconData icon, String labelKey})> get _tabs => [
    (icon: Icons.home_rounded, labelKey: 'tabBeranda'),
    (icon: Icons.bar_chart, labelKey: 'tabProgress'),
    (icon: Icons.event_available_rounded, labelKey: 'tabReservasi'),
    (icon: Icons.history_rounded, labelKey: 'tabRiwayat'),
    (icon: Icons.settings_rounded, labelKey: 'tabPengaturan'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F8),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildCurrentTab(),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    final widget = switch (_currentIndex) {
      0 => const HomeBody(),
      1 => const _PlaceholderBody(label: 'Progress'),
      2 => const _PlaceholderBody(label: 'Reservasi'),
      3 => const HistoryBody(),
      _ => const SettingsBody(),
    };
    // Key unique per tab → rebuild & re-init animation setiap kali berubah
    return _AnimatedTab(
      key: ValueKey(_currentIndex),
      child: widget,
    );
  }

  Widget _buildBottomNav() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
        margin: EdgeInsets.fromLTRB(20, 0, 20, bottomPad > 0 ? bottomPad : 12),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final tab  = _tabs[i];
            final active = i == _currentIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentIndex = i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        size: 18,
                        color: active ? _teal : Colors.blueGrey.shade300,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        t(context, tab.labelKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: active ? _teal : Colors.blueGrey.shade300,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      );
  }
}

/// Wrapper animasi untuk tiap tab — trigger ulang animasi saat tab berubah.
class _AnimatedTab extends StatefulWidget {
  final Widget child;
  const _AnimatedTab({super.key, required this.child});

  @override
  State<_AnimatedTab> createState() => _AnimatedTabState();
}

class _AnimatedTabState extends State<_AnimatedTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeFade;
  late Animation<Offset> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeFade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeSlide = Tween<Offset>(
            begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fadeFade,
        child: SlideTransition(position: _fadeSlide, child: widget.child),
      );
}

/// Placeholder untuk tab yang belum diimplementasi.
class _PlaceholderBody extends StatelessWidget {
  final String label;
  const _PlaceholderBody({required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF789095),
          ),
        ),
      );
}
