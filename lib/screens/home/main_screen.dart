import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_language.dart';
import 'history_screen.dart';
import 'home_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });
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
    (icon: Icons.home_rounded,       labelKey: 'tabBeranda'),
    (icon: Icons.bar_chart_rounded,  labelKey: 'tabProgress'),
    (icon: Icons.event_note_rounded, labelKey: 'tabJanjiTemu'),
    (icon: Icons.person_rounded,     labelKey: 'tabProfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F8),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildCurrentTab()),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

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
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, bottomPad > 0 ? bottomPad : 12),
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
              final tab    = _tabs[i];
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
                      Icon(
                        tab.icon,
                        size: 22,
                        color: active ? _teal : _grey,
                      ),
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
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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

