import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import 'notification_screen.dart';
import 'main_screen.dart';
import 'appointment_detail_screen.dart';
import 'history_screen.dart';
import 'settle_payment_screen.dart';
import 'upcoming_appointment_card.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _c300 = Color(0xFF5ECFC9);
const _c100 = Color(0xFFD4F5F3);
const _bg = Color(0xFFF0F7F7);
const _ink = Color(0xFF0E2C2F);
const _ink2 = Color(0xFF3D6065);
const _ink3 = Color(0xFF8AA8AC);

/// Konten tab Beranda — dirender oleh [MainScreen] di dalam IndexedStack.
class HomeBody extends StatefulWidget {
  const HomeBody({super.key});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> with TickerProviderStateMixin {
  String _fullName = '';
  String? _profileImageUrl;
  // header expand animation
  late AnimationController _headerCtrl;
  late Animation<double> _headerExpand; // height expand from top-to-bottom
  // header sub-element animations
  late Animation<double> _greetFade;
  late Animation<Offset> _greetSlide;
  late Animation<double> _avatarFade;
  late Animation<Offset> _avatarSlide;
  // staggered section animations
  late AnimationController _staggerCtrl;
  late List<Animation<double>> _sectionFades;
  late List<Animation<Offset>> _sectionSlides;
  // promo / search
  Timer? _promoTimer;
  late TextEditingController _searchCtrl;
  late FocusNode _searchFocus;
  int _promoPage = 0;
  bool _isSearching = false;
  String _searchQuery = '';
  Map<String, dynamic>? _upcomingAppointment;
  bool _hasUnreadNotifications = true;
  int _progressMetricIndex = 0;
  final Set<int> _completedTasks = {0};

  // number of staggered sections:
  // 0=promo, 1=appointment, 2=services, 3=progress, 4=tips
  static const _kSections = 5;

  @override
  void initState() {
    super.initState();

    // header
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _headerExpand = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));

    _greetFade = CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _greetSlide = Tween<Offset>(begin: const Offset(-0.25, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _headerCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
          ),
        );

    // avatar + notif: slides in from right, starts at 100ms (0.11), ends at 600ms
    _avatarFade = CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.11, 0.66, curve: Curves.easeOut),
    );
    _avatarSlide = Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _headerCtrl,
            curve: const Interval(0.11, 0.66, curve: Curves.easeOutCubic),
          ),
        );

    // stagger: total 900 ms, each section 300 ms window, offset 120 ms
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _sectionFades = List.generate(_kSections, (i) {
      final start = (i * 0.18).clamp(0.0, 1.0);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _sectionSlides = List.generate(_kSections, (i) {
      final start = (i * 0.18).clamp(0.0, 1.0);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    _promoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _promoPage = (_promoPage + 1) % 2);
    });
    _searchCtrl = TextEditingController();
    _searchFocus = FocusNode();

    _searchFocus.addListener(() {
      setState(() => _isSearching = _searchFocus.hasFocus);
    });
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });

    _headerCtrl.forward();
    // slight delay so header finishes before sections start
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _staggerCtrl.forward();
    });
    _loadProfile();
    _loadUpcomingAppointment();
    _loadNotificationReadState();
  }

  Future<void> _loadNotificationReadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final globalRead = prefs.getBool('notifications_marked_as_read') ?? false;
      final readKeys =
          prefs.getStringList('read_notification_keys')?.toSet() ?? {};
      if (globalRead && readKeys.isEmpty) {
        if (mounted) setState(() => _hasUnreadNotifications = false);
        return;
      }

      final user = SupabaseAuthService().client.auth.currentUser;
      if (user == null) return;
      final rows = await SupabaseAuthService().client
          .from('appointments')
          .select('id, created_at')
          .eq('booker_id', user.id);
      final notificationKeys = <String>{
        ...(rows as List).map(
          (row) => 'appointment:${row['id'] ?? ''}:${row['created_at'] ?? ''}',
        ),
      };

      void addLocalKeys(String preferenceKey, String notificationType) {
        for (final rawEvent in prefs.getStringList(preferenceKey) ?? []) {
          try {
            final event = jsonDecode(rawEvent);
            if (event is Map<String, dynamic> &&
                event['booker_id'] == user.id) {
              notificationKeys.add(
                '$notificationType:${event['appointment_id'] ?? ''}:${event['created_at'] ?? ''}',
              );
            }
          } catch (_) {}
        }
      }

      addLocalKeys('reschedule_notifications', 'rescheduled');
      addLocalKeys('payment_notifications', 'payment_completed');
      addLocalKeys('reminder_notifications', 'reminder');
      if (prefs.getBool('welcome_notification_sent') ?? false) {
        notificationKeys.add(
          'welcome:${prefs.getString('welcome_notification_created_at') ?? 'default'}',
        );
      }
      if (!mounted) return;
      setState(() {
        _hasUnreadNotifications = notificationKeys.any(
          (key) => !readKeys.contains(key),
        );
      });
    } catch (error) {
      debugPrint('Notification read state load failed: $error');
    }
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _staggerCtrl.dispose();
    _promoTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HomeBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger ulang animasi saat widget key berubah
    _headerCtrl.reset();
    _staggerCtrl.reset();
    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _staggerCtrl.forward();
    });
  }

  Future<void> _loadProfile() async {
    try {
      final service = SupabaseAuthService();
      final user = service.client.auth.currentUser;
      final profile = await service.checkUserProfileExists();
      final metadata = user?.userMetadata ?? <String, dynamic>{};
      final profileName = profile?['full_name']?.toString().trim() ?? '';
      final metadataName = (metadata['full_name'] ?? metadata['name'])
          ?.toString()
          .trim();
      final persistedImageUrl = profile?['profile_photo_url']
          ?.toString()
          .trim();
      final stableImageUrl = persistedImageUrl?.isNotEmpty == true
          ? persistedImageUrl
          : null;
      final imageUrl =
          stableImageUrl ??
          _firstNonEmpty([
            profile?['avatar_url'],
            profile?['photo_url'],
            profile?['profile_image_url'],
            profile?['image_url'],
            metadata['avatar_url'],
            metadata['picture'],
            metadata['photo_url'],
          ]);
      if (!mounted) return;
      setState(() {
        _fullName = profileName.isNotEmpty
            ? profileName
            : (metadataName?.isNotEmpty == true
                  ? metadataName!
                  : t(context, 'patientName'));
        _profileImageUrl = imageUrl;
      });
    } catch (e) {
      debugPrint('Home profile load failed: $e');
    }
  }

  Future<void> _loadUpcomingAppointment() async {
    try {
      final service = SupabaseAuthService();
      final user = service.client.auth.currentUser;
      if (user == null) return;
      await service.expireOverdueAppointments();
      final rows = await service.client
          .from('appointments')
          .select()
          .eq('booker_id', user.id)
          .order('appointment_date', ascending: true)
          .order('appointment_time', ascending: true);
      final now = DateTime.now();
      Map<String, dynamic>? upcoming;
      for (final raw in rows as List) {
        final row = raw as Map<String, dynamic>;
        final status = row['appointment_status']?.toString() ?? 'upcoming';
        if (status == 'completed' ||
            status == 'expired' ||
            status == 'cancelled') {
          continue;
        }
        final date = DateTime.tryParse(
          row['appointment_date']?.toString() ?? '',
        );
        if (date == null) continue;
        final timeParts = (row['appointment_time']?.toString() ?? '00:00')
            .split(':');
        final appointment = DateTime(
          date.year,
          date.month,
          date.day,
          int.tryParse(timeParts.first) ?? 0,
          int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0,
        );
        if (appointment.isAfter(now)) {
          upcoming = row;
          break;
        }
      }
      if (mounted) setState(() => _upcomingAppointment = upcoming);
    } catch (error) {
      debugPrint('Home upcoming appointment load failed: $error');
    }
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      final t = v?.toString().trim() ?? '';
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  void _handleProfileImageError() {
    if (!mounted || _profileImageUrl == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _profileImageUrl = null);
    });
  }

  String get _firstName => _fullName.split(' ').first;

  // ── build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _searchFocus.unfocus();
      },
      child: ColoredBox(
        color: _bg,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                _buildSliverHeader(),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 20),
                      _fadeSlide(0, _buildPromoTicker()),
                      const SizedBox(height: 28),
                      _fadeSlide(
                        1,
                        _buildSectionRow(
                          t(context, 'upcomingAppointment'),
                          t(context, 'seeAll'),
                          onAction: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MainScreen(
                                initialIndex: 1,
                                initialHistoryFilter: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _fadeSlide(1, _buildAppointmentCard()),
                      const SizedBox(height: 28),
                      _fadeSlide(
                        2,
                        _buildSectionRow(t(context, 'independentTasks'), null),
                      ),
                      const SizedBox(height: 14),
                      _fadeSlide(2, _buildTasksCard()),
                      const SizedBox(height: 28),
                      _fadeSlide(3, _buildProgressCard()),
                      const SizedBox(height: 28),
                      _fadeSlide(4, _buildTipsCard()),
                    ]),
                  ),
                ),
              ],
            ),
            // search results overlay
            if (_isSearching) _buildSearchOverlay(),
          ],
        ),
      ),
    );
  }

  // ── stagger helper ────────────────────────────────────────────────────────
  Widget _fadeSlide(int index, Widget child) => FadeTransition(
    opacity: _sectionFades[index],
    child: SlideTransition(position: _sectionSlides[index], child: child),
  );

  // ── sliver header ─────────────────────────────────────────────────────────
  Widget _buildSliverHeader() => SliverToBoxAdapter(
    child: ClipRect(
      child: AnimatedBuilder(
        animation: _headerExpand,
        builder: (context, child) {
          return Align(
            alignment: Alignment.topCenter,
            heightFactor: _headerExpand.value,
            child: child,
          );
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _ink.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + 16,
                  20,
                  28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Avatar sits beside the greeting, matching the reference layout.
                        FadeTransition(
                          opacity: _avatarFade,
                          child: SlideTransition(
                            position: _avatarSlide,
                            child: _buildAvatar(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FadeTransition(
                            opacity: _greetFade,
                            child: SlideTransition(
                              position: _greetSlide,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t(context, 'welcomeGreeting'),
                                    style: const TextStyle(
                                      color: _c700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _firstName,
                                    style: const TextStyle(
                                      color: _ink,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FadeTransition(
                          opacity: _avatarFade,
                          child: SlideTransition(
                            position: _avatarSlide,
                            child: _buildNotifButton(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildNotifButton() => GestureDetector(
    onTap: () async {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const NotificationScreen()),
      );
      if (mounted) _loadNotificationReadState();
    },
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _c100,
        shape: BoxShape.circle,
        border: Border.all(color: _c500.withValues(alpha: 0.2)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.notifications_outlined, color: _c700, size: 20),
          if (_hasUnreadNotifications)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6B6B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _buildAvatar() => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: _c100, width: 2),
      boxShadow: [
        BoxShadow(
          color: _ink.withValues(alpha: 0.12),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: CircleAvatar(
      radius: 20,
      backgroundColor: _c300,
      backgroundImage: _profileImageUrl == null
          ? null
          : NetworkImage(_profileImageUrl!),
      onBackgroundImageError: _profileImageUrl == null
          ? null
          : (_, _) => _handleProfileImageError(),
      child: _profileImageUrl == null
          ? const Icon(Icons.person, color: Colors.white, size: 22)
          : null,
    ),
  );

  // ── search data & overlay ─────────────────────────────────────────────────

  List<({IconData icon, String label, String desc, Color color})>
  get _searchableServices => [
    (
      icon: Icons.home_rounded,
      label: t(context, 'homeCare'),
      desc: t(context, 'homeCareDesc'),
      color: const Color(0xFF007F78),
    ),
    (
      icon: Icons.local_hospital_rounded,
      label: t(context, 'klinik'),
      desc: t(context, 'klinikDesc'),
      color: const Color(0xFF5B5FC8),
    ),
    (
      icon: Icons.directions_run_rounded,
      label: t(context, 'rehab'),
      desc: t(context, 'rehabDesc'),
      color: const Color(0xFFE87040),
    ),
    (
      icon: Icons.favorite_rounded,
      label: t(context, 'wellness'),
      desc: t(context, 'wellnessDesc'),
      color: const Color(0xFFD04080),
    ),
  ];

  List<({String name, String spec})> get _searchableTherapists => [
    (
      name: 'Marvin McKinney',
      spec: t(context, 'specGeneralPhysio'),
    ),
    (
      name: 'Sinta Dewi',
      spec: t(context, 'specPostOpRehab'),
    ),
    (
      name: 'Budi Santoso',
      spec: t(context, 'specSportsPhysio'),
    ),
    (name: 'Rina Kusuma', spec: t(context, 'specRelaxation')),
  ];

  List<({String title, String body})> get _searchableTips => [
    (title: t(context, 'tipsStretch'), body: t(context, 'tipsStretchBody')),
    (title: t(context, 'tipsWater'), body: t(context, 'tipsWaterBody')),
    (title: t(context, 'tipsRest'), body: t(context, 'tipsRestBody')),
  ];

  List<_SearchResult> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery;
    final results = <_SearchResult>[];

    for (final s in _searchableServices) {
      if (s.label.toLowerCase().contains(q) ||
          s.desc.toLowerCase().contains(q)) {
        results.add(
          _SearchResult(
            icon: s.icon,
            iconColor: s.color,
            iconBg: s.color.withValues(alpha: 0.1),
            title: s.label,
            subtitle: s.desc,
            type: t(context, 'serviceCat'),
          ),
        );
      }
    }
    for (final th in _searchableTherapists) {
      if (th.name.toLowerCase().contains(q) ||
          th.spec.toLowerCase().contains(q)) {
        results.add(
          _SearchResult(
            icon: Icons.person_rounded,
            iconColor: _c700,
            iconBg: _c100,
            title: th.name,
            subtitle: th.spec,
            type: t(context, 'therapistCat'),
          ),
        );
      }
    }
    for (final tip in _searchableTips) {
      if (tip.title.toLowerCase().contains(q) ||
          tip.body.toLowerCase().contains(q)) {
        results.add(
          _SearchResult(
            icon: Icons.lightbulb_rounded,
            iconColor: const Color(0xFFD4920A),
            iconBg: const Color(0xFFFFEEB0),
            title: tip.title,
            subtitle: tip.body,
            type: t(context, 'tipsCat'),
          ),
        );
      }
    }
    return results;
  }

  Widget _buildSearchOverlay() {
    final results = _searchResults;
    // Hitung tinggi header secara dinamis: status bar + padding atas + konten header
    final statusBarH = MediaQuery.of(context).padding.top;
    // header content: top padding (16) + greeting (~60) + search bar (~48) + bottom padding (28)
    final overlayTop = statusBarH + 16 + 60 + 48 + 28;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        // tap on backdrop = dismiss
        onTap: () => _searchFocus.unfocus(),
        child: Container(
          color: Colors.black.withValues(alpha: 0.35),
          child: GestureDetector(
            // absorb taps inside panel
            onTap: () {},
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: EdgeInsets.only(top: overlayTop),
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: _searchQuery.isEmpty
                    ? _buildSearchSuggestions()
                    : results.isEmpty
                    ? _buildEmptySearch()
                    : _buildResultsList(results),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          t(context, 'popularSearch'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                    t(context, 'homeCare'),
                    t(context, 'rehab'),
                    t(context, 'wellness'),
                    t(context, 'klinik'),
                    t(context, 'defaultTherapistName'),
                  ]
                  .map(
                    (s) => GestureDetector(
                      onTap: () {
                        _searchCtrl.text = s;
                        _searchCtrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: s.length),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _c100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _c700,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ],
    ),
  );

  Widget _buildEmptySearch() => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 42,
            color: _ink3.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '${t(context, 'noResultFor')} "$_searchQuery"',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _ink3),
          ),
        ],
      ),
    ),
  );

  Widget _buildResultsList(List<_SearchResult> results) {
    // group by type
    final grouped = <String, List<_SearchResult>>{};
    for (final r in results) {
      grouped.putIfAbsent(r.type, () => []).add(r);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: true,
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              entry.key,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _ink3,
                letterSpacing: 0.5,
              ),
            ),
          ),
          for (final r in entry.value)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 2,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: r.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(r.icon, color: r.iconColor, size: 20),
              ),
              title: Text(
                r.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              subtitle: Text(
                r.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: _ink3),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: _ink3,
              ),
              onTap: () => _searchFocus.unfocus(),
            ),
        ],
      ],
    );
  }

  // ── promo ticker ──────────────────────────────────────────────────────────
  Widget _buildPromoTicker() => SizedBox(
    height: 22,
    child: Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.35),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Text(
          _promoPage == 0
              ? t(context, 'promoTickerPackage')
              : t(context, 'promoTickerConsultation'),
          key: ValueKey(_promoPage),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _c500,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );

  // ── section row ───────────────────────────────────────────────────────────
  Widget _buildSectionRow(
    String title,
    String? action, {
    VoidCallback? onAction,
  }) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(
            action,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _c500,
            ),
          ),
        ),
    ],
  );

  // ── appointment card ──────────────────────────────────────────────────────
  Widget _buildAppointmentCard() {
    final appointment = _upcomingAppointment;
    if (appointment == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE1E9E8)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_available_rounded, color: _ink3, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t(context, 'noAppointments'),
                style: const TextStyle(color: _ink3),
              ),
            ),
          ],
        ),
      );
    }
    final item = _appointmentItemFromRow(appointment);
    return UpcomingAppointmentCard(
      item: item,
      onTap: () => _openUpcomingDetail(appointment),
      onSettlePayment: () => _openSettlePayment(appointment),
    );
    /*
    final serviceType = appointment['service_type']?.toString() ?? 'Home Care';
    final isClinic = serviceType == 'Klinik';
    final paymentStatus =
        appointment['payment_status']?.toString().toLowerCase() ?? 'paid';
    final paymentPlan =
        appointment['payment_plan']?.toString().toLowerCase() ?? 'full';
    final amountDue =
        int.tryParse(appointment['amount_due']?.toString() ?? '') ?? 0;
    final hasOutstandingPayment =
        (paymentPlan == 'deposit' && paymentStatus != 'paid') ||
        (amountDue > 0 && paymentStatus != 'paid');
    final date = DateTime.tryParse(
      appointment['appointment_date']?.toString() ?? '',
    );
    final dateLabel = date == null
        ? '-'
        : '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}';
    final rawTime = appointment['appointment_time']?.toString() ?? '-';
    final timeLabel = rawTime.length >= 5
        ? '${rawTime.substring(0, 5)} WIB'
        : rawTime;
    return GestureDetector(
      onTap: () => _openUpcomingDetail(appointment),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          border: Border.all(
            color: hasOutstandingPayment ? const Color(0xFFD94F45) : _c500,
            width: hasOutstandingPayment ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _ink.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: _circle(110, Colors.white, 0.06),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _c100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.medical_services_rounded,
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
                              appointment['therapist_name']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true
                                  ? appointment['therapist_name'].toString()
                                  : t(context, 'therapistDefault'),
                              style: TextStyle(
                                color: _ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _c100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isClinic
                                    ? t(context, 'klinik')
                                    : t(context, 'homeCare'),
                                style: TextStyle(
                                  color: _c700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: hasOutstandingPayment
                              ? const Color(0xFFD94F45)
                              : _c500,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          hasOutstandingPayment
                              ? t(context, 'paymentPending')
                              : t(context, 'statusUpcoming'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 10,
                          child: _apptInfoItem(
                            Icons.calendar_month_outlined,
                            date == null ? '-' : _weekdayName(date.weekday),
                            dateLabel,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: const Color(0xFFE0EAEA),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        Expanded(
                          flex: 9,
                          child: _apptInfoItem(
                            Icons.access_time_rounded,
                            timeLabel,
                            isClinic
                                ? t(context, 'klinik')
                                : t(context, 'homeCare'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _openUpcomingDetail(appointment),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _c100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: _c700,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    */
  }

  // ── helpers for reading nullable clinical columns ─────────────────────────
  static String? _nullIfEmpty(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();
  static int? _nullableInt(dynamic v) =>
      v == null ? null : int.tryParse(v.toString());

  AppointmentItem _appointmentItemFromRow(Map<String, dynamic> appointment) {
    final appointmentDate = appointment['appointment_date']?.toString() ?? '';
    final appointmentTime = appointment['appointment_time']?.toString() ?? '';
    final scheduledAt = DateTime.tryParse('$appointmentDate $appointmentTime');
    final locallyExpired =
        scheduledAt != null &&
        !scheduledAt.add(const Duration(minutes: 15)).isAfter(DateTime.now());
    final rawStatus = appointment['appointment_status']?.toString();
    final status = rawStatus == 'completed'
        ? AppointmentStatus.selesai
        : rawStatus == 'expired' || rawStatus == 'cancelled'
        ? AppointmentStatus.batasWaktu
        : locallyExpired
        ? AppointmentStatus.batasWaktu
        : AppointmentStatus.mendatang;
    return AppointmentItem(
      id: appointment['id']?.toString() ?? '',
      therapistName:
          appointment['therapist_name']?.toString().isNotEmpty == true
          ? appointment['therapist_name'].toString()
          : t(context, 'therapistDefault'),
      serviceType: appointment['service_type']?.toString() ?? 'Home Care',
      date: appointmentDate,
      time: appointmentTime,
      patientName: appointment['patient_full_name']?.toString() ?? '',
      sessionCount:
          int.tryParse(appointment['session_count']?.toString() ?? '') ?? 1,
      paymentStatus: appointment['payment_status']?.toString() ?? 'paid',
      paymentPlan: appointment['payment_plan']?.toString() ?? 'full',
      amountDue: int.tryParse(appointment['amount_due']?.toString() ?? '') ?? 0,
      bookedForOther: AppointmentItem.bookedForOtherFromRow(appointment),
      status: status,
      profilePhotoUrl: _profileImageUrl,
      clinicalNote: _nullIfEmpty(appointment['clinical_note']?.toString()),
      vasScore: _nullableInt(appointment['vas_score']),
      romScore: _nullableInt(appointment['rom_score']),
      mmtScore: _nullableInt(appointment['mmt_score']),
      odiScore: _nullableInt(appointment['odi_score']),
      therapistRecommendation: _nullIfEmpty(appointment['therapist_recommendation']?.toString()),
      therapistSipf: _nullIfEmpty(appointment['therapist_sipf']?.toString()),
      therapistPhotoUrl: _nullIfEmpty(appointment['therapist_photo_url']?.toString()),
    );
  }

  Future<void> _openUpcomingDetail(Map<String, dynamic> appointment) async {
    final rawStatus = appointment['appointment_status']?.toString();
    final scheduledAt = DateTime.tryParse(
      '${appointment['appointment_date']} ${appointment['appointment_time']}',
    );
    final locallyExpired =
        scheduledAt != null &&
        !scheduledAt.add(const Duration(minutes: 15)).isAfter(DateTime.now());
    final item = AppointmentItem(
      id: appointment['id']?.toString() ?? '',
      therapistName:
          appointment['therapist_name']?.toString().isNotEmpty == true
          ? appointment['therapist_name'].toString()
          : t(context, 'therapistDefault'),
      serviceType: appointment['service_type']?.toString() ?? 'Home Care',
      date: appointment['appointment_date']?.toString() ?? '-',
      time: appointment['appointment_time']?.toString() ?? '- WIB',
      patientName: appointment['patient_full_name']?.toString() ?? '',
      medicalCode: appointment['patient_medical_code']?.toString() ?? '',
      address: appointment['address']?.toString() ?? '',
      complaint: appointment['patient_complaint']?.toString() ?? '',
      clinicName: appointment['clinic_name']?.toString() ?? '',
      sessionCount:
          int.tryParse(appointment['session_count']?.toString() ?? '') ?? 1,
      paymentStatus: appointment['payment_status']?.toString() ?? 'paid',
      paymentPlan: appointment['payment_plan']?.toString() ?? 'full',
      amountDue: int.tryParse(appointment['amount_due']?.toString() ?? '') ?? 0,
      bookingCode: appointment['booking_code']?.toString() ?? '',
      bookedForOther: AppointmentItem.bookedForOtherFromRow(appointment),
      status: rawStatus == 'completed'
          ? AppointmentStatus.selesai
          : rawStatus == 'expired'
          ? AppointmentStatus.batasWaktu
          : locallyExpired
          ? AppointmentStatus.batasWaktu
          : AppointmentStatus.mendatang,
      profilePhotoUrl: _profileImageUrl,
      clinicalNote: _nullIfEmpty(appointment['clinical_note']?.toString()),
      vasScore: _nullableInt(appointment['vas_score']),
      romScore: _nullableInt(appointment['rom_score']),
      mmtScore: _nullableInt(appointment['mmt_score']),
      odiScore: _nullableInt(appointment['odi_score']),
      therapistRecommendation: _nullIfEmpty(appointment['therapist_recommendation']?.toString()),
      therapistSipf: _nullIfEmpty(appointment['therapist_sipf']?.toString()),
      therapistPhotoUrl: _nullIfEmpty(appointment['therapist_photo_url']?.toString()),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AppointmentDetailScreen(item: item)),
    );
    if (mounted) _loadUpcomingAppointment();
  }

  Future<void> _openSettlePayment(Map<String, dynamic> appointment) async {
    final rawStatus = appointment['appointment_status']?.toString();
    final scheduledAt = DateTime.tryParse(
      '${appointment['appointment_date']} ${appointment['appointment_time']}',
    );
    final locallyExpired =
        scheduledAt != null &&
        !scheduledAt.add(const Duration(minutes: 15)).isAfter(DateTime.now());
    final item = AppointmentItem(
      id: appointment['id']?.toString() ?? '',
      therapistName:
          appointment['therapist_name']?.toString().isNotEmpty == true
          ? appointment['therapist_name'].toString()
          : t(context, 'therapistDefault'),
      serviceType: appointment['service_type']?.toString() ?? 'Home Care',
      date: appointment['appointment_date']?.toString() ?? '-',
      time: appointment['appointment_time']?.toString() ?? '- WIB',
      patientName: appointment['patient_full_name']?.toString() ?? '',
      medicalCode: appointment['patient_medical_code']?.toString() ?? '',
      address: appointment['address']?.toString() ?? '',
      complaint: appointment['patient_complaint']?.toString() ?? '',
      clinicName: appointment['clinic_name']?.toString() ?? '',
      sessionCount:
          int.tryParse(appointment['session_count']?.toString() ?? '') ?? 1,
      paymentStatus: appointment['payment_status']?.toString() ?? 'paid',
      paymentPlan: appointment['payment_plan']?.toString() ?? 'full',
      amountDue: int.tryParse(appointment['amount_due']?.toString() ?? '') ?? 0,
      bookingCode: appointment['booking_code']?.toString() ?? '',
      bookedForOther: AppointmentItem.bookedForOtherFromRow(appointment),
      status: rawStatus == 'completed'
          ? AppointmentStatus.selesai
          : rawStatus == 'expired'
          ? AppointmentStatus.batasWaktu
          : locallyExpired
          ? AppointmentStatus.batasWaktu
          : AppointmentStatus.mendatang,
      profilePhotoUrl: _profileImageUrl,
      clinicalNote: _nullIfEmpty(appointment['clinical_note']?.toString()),
      vasScore: _nullableInt(appointment['vas_score']),
      romScore: _nullableInt(appointment['rom_score']),
      mmtScore: _nullableInt(appointment['mmt_score']),
      odiScore: _nullableInt(appointment['odi_score']),
      therapistRecommendation: _nullIfEmpty(appointment['therapist_recommendation']?.toString()),
      therapistSipf: _nullIfEmpty(appointment['therapist_sipf']?.toString()),
      therapistPhotoUrl: _nullIfEmpty(appointment['therapist_photo_url']?.toString()),
    );
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SettlePaymentScreen(appointment: item)),
    );
    if (paid == true && mounted) _loadUpcomingAppointment();
  }

  // ── independent tasks ────────────────────────────────────────────────────
  Widget _buildTasksCard() {
    final tasks = [
      (t(context, 'taskStretch'), '2 set × 10 kali'),
      (t(context, 'taskLatihanOtot'), '3 set × 8 kali'),
      (t(context, 'taskPanggul'), '3 set × 10 kali'),
      (t(context, 'taskJalan'), '15–20 menit'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < tasks.length; index++)
            InkWell(
              onTap: () => setState(() {
                if (_completedTasks.contains(index)) {
                  _completedTasks.remove(index);
                } else {
                  _completedTasks.add(index);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                child: Row(
                  children: [
                    Icon(
                      _completedTasks.contains(index)
                          ? Icons.check_box_outlined
                          : Icons.check_box_outline_blank,
                      color: _completedTasks.contains(index) ? _c500 : _ink3,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tasks[index].$1,
                        style: TextStyle(
                          color: _completedTasks.contains(index) ? _ink : _ink2,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      tasks[index].$2,
                      style: const TextStyle(fontSize: 12, color: _ink2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── progress card ─────────────────────────────────────────────────────────

  // Data per metrik: tren menurun (nyeri, ODI) atau naik (ROM, kekuatan)
  static const _progressMetrics = [
    _ProgressMetric(
      key: 'painScaleDropdown',
      yLabelKey: 'painLevel',
      data: [9.0, 8.5, 7.8, 7.0, 6.0, 5.0, 4.2, 3.5, 2.8],
      trendDown: true,  // nilai makin kecil = makin baik
    ),
    _ProgressMetric(
      key: 'romLabel',
      yLabelKey: 'romLabel',
      data: [40.0, 50.0, 58.0, 68.0, 76.0, 84.0, 90.0, 100.0, 110.0],
      trendDown: false, // nilai makin besar = makin baik
    ),
    _ProgressMetric(
      key: 'muscleStrength',
      yLabelKey: 'muscleStrength',
      data: [1.5, 2.0, 2.5, 2.8, 3.2, 3.5, 3.8, 4.0, 4.5],
      trendDown: false,
    ),
    _ProgressMetric(
      key: 'odiLabel',
      yLabelKey: 'odiLabel',
      data: [42.0, 38.0, 34.0, 30.0, 26.0, 22.0, 17.0, 12.0, 8.0],
      trendDown: true,
    ),
  ];

  Widget _buildProgressCard() {
    final metric = _progressMetrics[_progressMetricIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header + dropdown DI LUAR card ───────────────────────────────
        Row(
          children: [
            Text(
              t(context, 'rehabProgress'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const Spacer(),
            PopupMenuButton<int>(
              initialValue: _progressMetricIndex,
              onSelected: (i) => setState(() => _progressMetricIndex = i),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: Colors.white,
              elevation: 4,
              itemBuilder: (_) => List.generate(
                _progressMetrics.length,
                (i) => PopupMenuItem<int>(
                  value: i,
                  child: Text(
                    t(context, _progressMetrics[i].key),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _progressMetricIndex == i
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: _progressMetricIndex == i ? _c700 : _ink,
                    ),
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD4E8E8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t(context, metric.key),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _c700,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: _c700,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // ── Grafik DI DALAM card ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _ink.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SizedBox(
            height: 185,
            child: CustomPaint(
              painter: _RehabProgressPainter(
                yLabel: t(context, metric.yLabelKey),
                xLabel: t(context, 'session'),
                data: metric.data,
                trendDown: metric.trendDown,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }


  // ── tips card ─────────────────────────────────────────────────────────────
  Widget _buildTipsCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBF0),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFFFE5A0)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFFD700).withValues(alpha: 0.1),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEEB0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.lightbulb_rounded,
            color: Color(0xFFD4920A),
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(context, 'tipsTitle'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7A5500),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                t(context, 'tipsStretchBody'),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9A7020),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Search result model ──────────────────────────────────────────────────────

class _SearchResult {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String type;

  const _SearchResult({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.type,
  });
}

// ─── Progress metric model ────────────────────────────────────────────────────

class _ProgressMetric {
  final String key;       // localization key untuk label dropdown
  final String yLabelKey; // localization key untuk Y-axis label
  final List<double> data;
  final bool trendDown;   // true = nilai kecil lebih baik (nyeri, ODI)

  const _ProgressMetric({
    required this.key,
    required this.yLabelKey,
    required this.data,
    required this.trendDown,
  });
}

// ─── Rehab Progress Painter ───────────────────────────────────────────────────

class _RehabProgressPainter extends CustomPainter {
  final String yLabel;
  final String xLabel;
  final List<double> data;
  final bool trendDown;

  const _RehabProgressPainter({
    required this.yLabel,
    required this.xLabel,
    required this.data,
    required this.trendDown,
  });

  static const _sessions = ['S1','S2','S3','S4','S5','S6','S7','S8','S9'];

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 42.0; // ruang untuk label Y + judul rotated
    const padR = 10.0;
    const padT = 8.0;
    const padB = 32.0;
    final chartW = size.width - padL - padR;
    final chartH = size.height - padT - padB;

    // Hitung min/max dari data aktual dengan sedikit padding
    final dataMax = data.reduce((a, b) => a > b ? a : b);
    final dataMin = data.reduce((a, b) => a < b ? a : b);
    final range = (dataMax - dataMin).clamp(1.0, double.infinity);
    final maxVal = dataMax + range * 0.1;
    final minVal = (dataMin - range * 0.1).clamp(0.0, double.infinity);
    const steps = 5;

    double xOf(int i) => padL + i * chartW / (data.length - 1);
    double yOf(double v) =>
        padT + chartH - (v - minVal) / (maxVal - minVal) * chartH;

    // ── grid lines & Y axis labels ────────────────────────────────────────
    final gridPaint = Paint()
      ..color = const Color(0xFFEEF4F4)
      ..strokeWidth = 1;

    for (var i = 0; i <= steps; i++) {
      final y = padT + i * chartH / steps;
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);

      // Y label (10, 8, 6, 4, 2, 0)
      final val = maxVal - i * (maxVal / steps);
      final tp = TextPainter(
        text: TextSpan(
          text: val.toInt().toString(),
          style: const TextStyle(fontSize: 9, color: Color(0xFF8AA8AC)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(padL - tp.width - 4, y - tp.height / 2),
      );
    }

    // ── Y axis title (rotated) ────────────────────────────────────────────
    final yTitlePainter = TextPainter(
      text: TextSpan(
        text: yLabel,
        style: const TextStyle(fontSize: 8, color: Color(0xFF8AA8AC)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(8, padT + chartH / 2 + yTitlePainter.width / 2);
    canvas.rotate(-3.14159 / 2);
    yTitlePainter.paint(canvas, Offset.zero);
    canvas.restore();

    // ── gradient fill ─────────────────────────────────────────────────────
    final fillPath = Path();
    fillPath.moveTo(xOf(0), yOf(data[0]));
    for (var i = 1; i < data.length; i++) {
      final cpx = (xOf(i - 1) + xOf(i)) / 2;
      fillPath.cubicTo(
        cpx, yOf(data[i - 1]),
        cpx, yOf(data[i]),
        xOf(i), yOf(data[i]),
      );
    }
    fillPath.lineTo(xOf(data.length - 1), padT + chartH);
    fillPath.lineTo(xOf(0), padT + chartH);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00A79D).withValues(alpha: 0.22),
          const Color(0xFF00A79D).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, padT, size.width, chartH));
    canvas.drawPath(fillPath, fillPaint);

    // ── line ──────────────────────────────────────────────────────────────
    final linePath = Path();
    linePath.moveTo(xOf(0), yOf(data[0]));
    for (var i = 1; i < data.length; i++) {
      final cpx = (xOf(i - 1) + xOf(i)) / 2;
      linePath.cubicTo(
        cpx, yOf(data[i - 1]),
        cpx, yOf(data[i]),
        xOf(i), yOf(data[i]),
      );
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = const Color(0xFF00A79D)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // ── dots ──────────────────────────────────────────────────────────────
    for (var i = 0; i < data.length; i++) {
      final cx = xOf(i);
      final cy = yOf(data[i]);
      canvas.drawCircle(
        Offset(cx, cy),
        3.0,
        Paint()..color = const Color(0xFF007F78),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        1.5,
        Paint()..color = Colors.white,
      );
    }

    // ── X axis session labels ─────────────────────────────────────────────
    for (var i = 0; i < _sessions.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: _sessions[i],
          style: const TextStyle(fontSize: 8, color: Color(0xFF8AA8AC)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(xOf(i) - tp.width / 2, size.height - padB + 4),
      );
    }

    // ── X axis title "Sesi" ───────────────────────────────────────────────
    final xTitlePainter = TextPainter(
      text: TextSpan(
        text: xLabel,
        style: const TextStyle(fontSize: 8, color: Color(0xFF8AA8AC)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    xTitlePainter.paint(
      canvas,
      Offset(
        padL + chartW / 2 - xTitlePainter.width / 2,
        size.height - 10,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _RehabProgressPainter old) =>
      old.data != data || old.yLabel != yLabel;
}


