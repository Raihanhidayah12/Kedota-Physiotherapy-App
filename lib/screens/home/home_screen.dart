import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import 'edit_profile_screen.dart';
import 'notification_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _c900 = Color(0xFF004D47);
const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _c300 = Color(0xFF5ECFC9);
const _c100 = Color(0xFFD4F5F3);
const _bg   = Color(0xFFF0F7F7);
const _ink  = Color(0xFF0E2C2F);
const _ink3 = Color(0xFF8AA8AC);

/// Konten tab Beranda — dirender oleh [MainScreen] di dalam IndexedStack.
class HomeBody extends StatefulWidget {
  const HomeBody({super.key});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody>
    with TickerProviderStateMixin {
  String _fullName = 'Pasien Kedota';
  String? _profileImageUrl;
  bool _isProfileIncomplete = false;
  // header expand animation
  late AnimationController _headerCtrl;
  late Animation<double> _headerExpand; // height expand from top-to-bottom
  // header sub-element animations
  late Animation<double>  _greetFade;
  late Animation<Offset>  _greetSlide;
  late Animation<double>  _avatarFade;
  late Animation<Offset>  _avatarSlide;
  late Animation<double>  _searchFadeAnim;
  late Animation<Offset>  _searchSlide;
  // staggered section animations
  late AnimationController _staggerCtrl;
  late List<Animation<double>> _sectionFades;
  late List<Animation<Offset>> _sectionSlides;
  // promo / search
  late PageController _promoCtrl;
  late TextEditingController _searchCtrl;
  late FocusNode _searchFocus;
  int _promoPage = 0;
  bool _isSearching = false;
  String _searchQuery = '';

  // number of staggered sections:
  // 0=promo, 1=appointment, 2=services, 3=progress, 4=tips
  static const _kSections = 5;

  @override
  void initState() {
    super.initState();

    // header
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _headerExpand = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic),
    );

    // greeting: slides in from left, starts at 0ms, ends at 500ms
    _greetFade = CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _greetSlide = Tween<Offset>(
      begin: const Offset(-0.25, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    ));

    // avatar + notif: slides in from right, starts at 100ms (0.11), ends at 600ms
    _avatarFade = CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.11, 0.66, curve: Curves.easeOut),
    );
    _avatarSlide = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.11, 0.66, curve: Curves.easeOutCubic),
    ));

    // search bar: slides in from bottom, starts at 250ms (0.28), ends at 900ms
    _searchFadeAnim = CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.28, 1.0, curve: Curves.easeOut),
    );
    _searchSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.28, 1.0, curve: Curves.easeOutCubic),
    ));

    // stagger: total 900 ms, each section 300 ms window, offset 120 ms
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));

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
      ).animate(CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ));
    });

    _promoCtrl = PageController();
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
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _staggerCtrl.dispose();
    _promoCtrl.dispose();
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
      final metadataName =
          (metadata['full_name'] ?? metadata['name'])?.toString().trim();
      final persistedImageUrl =
          profile?['profile_photo_url']?.toString().trim();
      final stableImageUrl =
          persistedImageUrl?.isNotEmpty == true &&
              !_isRateLimitedImageHost(persistedImageUrl!)
          ? persistedImageUrl
          : null;
      final imageUrl = stableImageUrl ??
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
            : (metadataName?.isNotEmpty == true ? metadataName! : _fullName);
        _profileImageUrl = imageUrl;
        final nik     = profile?['nik']?.toString().trim() ?? '';
        final address = profile?['address']?.toString().trim() ?? '';
        _isProfileIncomplete = nik.isEmpty || address.isEmpty;
      });
    } catch (e) {
      debugPrint('Home profile load failed: $e');
    }
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      final t = v?.toString().trim() ?? '';
      if (t.isNotEmpty && !_isRateLimitedImageHost(t)) return t;
    }
    return null;
  }

  bool _isRateLimitedImageHost(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host == 'googleusercontent.com' ||
        host.endsWith('.googleusercontent.com');
  }

  void _handleProfileImageError() {
    if (!mounted || _profileImageUrl == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _profileImageUrl = null);
    });
  }

  // ── incomplete profile banner ────────────────────────────────────────────
  Widget _buildIncompleteProfileBanner() {
    return GestureDetector(
      onTap: () async {
        final refreshed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
        );
        if (refreshed == true && mounted) _loadProfile();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFCC02), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEE82),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFB7820A),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'incompleteProfileTitle'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7A5800),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t(context, 'incompleteProfileDesc'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A7000),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Tombol langsung ke Informasi Akun
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC02),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                t(context, 'incompleteProfileBtn'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7A5800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── greeting helper ─────────────────────────────────────────────────────────
  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    if (h < 12) return t(context, 'greetingMorning');
    if (h < 15) return t(context, 'greetingAfternoon');
    if (h < 18) return t(context, 'greetingEvening');
    return t(context, 'greetingNight');
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
                      // Banner kelengkapan profil
                      if (_isProfileIncomplete) ...[
                        _buildIncompleteProfileBanner(),
                        const SizedBox(height: 16),
                      ],
                      _fadeSlide(0, _buildPromoBanner()),
                      const SizedBox(height: 28),
                      _fadeSlide(1, _buildSectionRow(t(context, 'upcomingAppointment'), t(context, 'seeAll'))),
                      const SizedBox(height: 12),
                      _fadeSlide(1, _buildAppointmentCard()),
                      const SizedBox(height: 28),
                      _fadeSlide(2, _buildSectionRow(t(context, 'ourServices'), null)),
                      const SizedBox(height: 14),
                      _fadeSlide(2, _buildServicesGrid()),
                      const SizedBox(height: 28),
                      _fadeSlide(3, _buildSectionRow(t(context, 'rehabProgress'), t(context, 'detail'))),
                      const SizedBox(height: 12),
                      _fadeSlide(3, _buildProgressCard()),
                      const SizedBox(height: 28),
                      _fadeSlide(4, _buildTipsCard()),
                    ]),
                  ),
                ),
              ],
            ),
            // search results overlay
            if (_isSearching)
              _buildSearchOverlay(),
          ],
        ),
      ),
    );
  }

  // ── stagger helper ────────────────────────────────────────────────────────
  Widget _fadeSlide(int index, Widget child) => FadeTransition(
        opacity: _sectionFades[index],
        child: SlideTransition(
          position: _sectionSlides[index],
          child: child,
        ),
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_c900, _c700, _c500],
                ),
              ),
              child: Stack(
                children: [
                  // decorative circles
                  Positioned(
                    right: -60,
                    top: -60,
                    child: _circle(220, Colors.white, 0.05),
                  ),
                  Positioned(
                    right: 40,
                    top: 20,
                    child: _circle(100, Colors.white, 0.07),
                  ),
                  Positioned(
                    left: -40,
                    bottom: -30,
                    child: _circle(130, _c300, 0.15),
                  ),
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
                            // greeting — slides from left
                            Expanded(
                              child: FadeTransition(
                                opacity: _greetFade,
                                child: SlideTransition(
                                  position: _greetSlide,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_greeting(context)},',
                                        style: const TextStyle(
                                          color: _c100,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _firstName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // avatar + notif — slides from right
                            FadeTransition(
                              opacity: _avatarFade,
                              child: SlideTransition(
                                position: _avatarSlide,
                                child: Row(
                                  children: [
                                    _buildNotifButton(),
                                    const SizedBox(width: 10),
                                    _buildAvatar(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        // search bar — slides from bottom
                        FadeTransition(
                          opacity: _searchFadeAnim,
                          child: SlideTransition(
                            position: _searchSlide,
                            child: _buildSearchBar(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _circle(double size, Color color, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      );

  Widget _buildNotifButton() => GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationScreen()),
          );
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_outlined,
                  color: Colors.white, size: 20),
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
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: _c900.withValues(alpha: 0.3),
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

  Widget _buildSearchBar() => TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: t(context, 'searchHint'),
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.7), size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    _searchFocus.unfocus();
                  },
                  child: Icon(Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.7), size: 18),
                )
              : null,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.15),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.25)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.25)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
          ),
        ),
      );

  // ── search data & overlay ─────────────────────────────────────────────────

  List<({IconData icon, String label, String desc, Color color})> get _searchableServices => [
    (icon: Icons.home_rounded,           label: t(context, 'homeCare'),  desc: t(context, 'homeCareDesc'),  color: const Color(0xFF007F78)),
    (icon: Icons.local_hospital_rounded, label: t(context, 'klinik'),    desc: t(context, 'klinikDesc'),    color: const Color(0xFF5B5FC8)),
    (icon: Icons.directions_run_rounded, label: t(context, 'rehab'),     desc: t(context, 'rehabDesc'),     color: const Color(0xFFE87040)),
    (icon: Icons.favorite_rounded,       label: t(context, 'wellness'),  desc: t(context, 'wellnessDesc'),  color: const Color(0xFFD04080)),
  ];

  List<({String name, String spec})> get _searchableTherapists => [
    (name: 'Marvin McKinney', spec: '${t(context, 'homeCare')} · Fisioterapi Umum'),
    (name: 'Sinta Dewi',      spec: '${t(context, 'klinik')} · Rehabilitasi Pasca Operasi'),
    (name: 'Budi Santoso',    spec: '${t(context, 'homeCare')} · Fisioterapi Olahraga'),
    (name: 'Rina Kusuma',     spec: '${t(context, 'wellness')} · Terapi Relaksasi'),
  ];

  List<({String title, String body})> get _searchableTips => [
    (title: t(context, 'tipsStretch'), body: t(context, 'tipsStretchBody')),
    (title: t(context, 'tipsWater'),   body: t(context, 'tipsWaterBody')),
    (title: t(context, 'tipsRest'),    body: t(context, 'tipsRestBody')),
  ];

  List<_SearchResult> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery;
    final results = <_SearchResult>[];

    for (final s in _searchableServices) {
      if (s.label.toLowerCase().contains(q) || s.desc.toLowerCase().contains(q)) {
        results.add(_SearchResult(
          icon: s.icon, iconColor: s.color,
          iconBg: s.color.withValues(alpha: 0.1),
          title: s.label, subtitle: s.desc,
          type: t(context, 'serviceCat'),
        ));
      }
    }
    for (final th in _searchableTherapists) {
      if (th.name.toLowerCase().contains(q) || th.spec.toLowerCase().contains(q)) {
        results.add(_SearchResult(
          icon: Icons.person_rounded, iconColor: _c700, iconBg: _c100,
          title: th.name, subtitle: th.spec,
          type: t(context, 'therapistCat'),
        ));
      }
    }
    for (final tip in _searchableTips) {
      if (tip.title.toLowerCase().contains(q) || tip.body.toLowerCase().contains(q)) {
        results.add(_SearchResult(
          icon: Icons.lightbulb_rounded,
          iconColor: const Color(0xFFD4920A), iconBg: const Color(0xFFFFEEB0),
          title: tip.title, subtitle: tip.body,
          type: t(context, 'tipsCat'),
        ));
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
                      bottom: Radius.circular(24)),
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
            Text(t(context, 'popularSearch'),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                t(context, 'homeCare'),
                t(context, 'rehab'),
                t(context, 'wellness'),
                t(context, 'klinik'),
                'Marvin McKinney',
              ]
                  .map((s) => GestureDetector(
                        onTap: () {
                          _searchCtrl.text = s;
                          _searchCtrl.selection = TextSelection.fromPosition(
                              TextPosition(offset: s.length));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _c100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(s,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _c700)),
                        ),
                      ))
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
              Icon(Icons.search_off_rounded,
                  size: 42, color: _ink3.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text('${t(context, 'noResultFor')} "$_searchQuery"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: _ink3)),
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
            child: Text(entry.key,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _ink3,
                    letterSpacing: 0.5)),
          ),
          for (final r in entry.value)
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: r.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(r.icon, color: r.iconColor, size: 20),
              ),
              title: Text(r.title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink)),
              subtitle: Text(r.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _ink3)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: _ink3),
              onTap: () => _searchFocus.unfocus(),
            ),
        ],
      ],
    );
  }

  // ── promo banner ─────────────────────────────────────────────────────────
  static const _promos = [
    (
      tag: 'PROMO SPESIAL',
      title: 'Diskon 30%\nHome Care',
      subtitle: 'Berlaku sampai 31 Agustus 2026',
      colors: [Color(0xFF007F78), Color(0xFF00C4B8)],
      accentIcon: Icons.discount_rounded,
    ),
    (
      tag: 'PAKET BARU',
      title: 'Paket Rehab\nKomprehensif',
      subtitle: '10 sesi dengan harga spesial',
      colors: [Color(0xFF3D56B2), Color(0xFF6A82FB)],
      accentIcon: Icons.auto_awesome_rounded,
    ),
    (
      tag: 'REFERRAL',
      title: 'Ajak Teman,\nDapat Bonus',
      subtitle: 'Dapatkan 1 sesi gratis per referral',
      colors: [Color(0xFFBF360C), Color(0xFFE87040)],
      accentIcon: Icons.people_rounded,
    ),
  ];

  Widget _buildPromoBanner() {
    final screenW = MediaQuery.of(context).size.width;
    final bannerH = (screenW * 0.45).clamp(155.0, 190.0);
    return Column(
        children: [
          SizedBox(
            height: bannerH,
            child: PageView.builder(
              controller: _promoCtrl,
              itemCount: _promos.length,
              onPageChanged: (i) => setState(() => _promoPage = i),
              itemBuilder: (_, i) {
                final p = _promos[i];
                return _buildPromoItem(
                  tag: p.tag,
                  title: p.title,
                  subtitle: p.subtitle,
                  colors: p.colors,
                  accentIcon: p.accentIcon,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_promos.length, (i) {
              final active = i == _promoPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? _c500 : _c100,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      );
  }

  Widget _buildPromoItem({
    required String tag,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required IconData accentIcon,
  }) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: 28,
              bottom: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.center,
                child: Icon(
                  accentIcon,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(accentIcon,
                            size: 10,
                            color: Colors.white.withValues(alpha: 0.9)),
                        const SizedBox(width: 5),
                        Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Klaim',
                          style: TextStyle(
                            color: colors.first,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ),
             ),
            ),
          ],
        ),
      );

  // ── section row ───────────────────────────────────────────────────────────
  Widget _buildSectionRow(String title, String? action) => Row(
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
            Text(
              action,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _c500,
              ),
            ),
        ],
      );

  // ── appointment card ──────────────────────────────────────────────────────
  Widget _buildAppointmentCard() => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_c700, _c500],
          ),
          boxShadow: [
            BoxShadow(
              color: _c700.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
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
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.medical_services_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Terapis Marvin McKinney',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                t(context, 'homeCare'),
                                style: TextStyle(
                                  color: Colors.white,
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
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          t(context, 'statusUpcoming'),
                          style: const TextStyle(
                            color: _c700,
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
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 10,
                          child: _apptInfoItem(
                            Icons.calendar_month_outlined,
                            'Selasa',
                            '18 Agu 2026',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: Colors.white.withValues(alpha: 0.25),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        Expanded(
                          flex: 9,
                          child: _apptInfoItem(
                            Icons.access_time_rounded,
                            '11:00',
                            '12:00 WIB',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: _c700,
                            size: 18,
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
      );

  Widget _apptInfoItem(IconData icon, String top, String bottom) => Row(
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  top,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  bottom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  // ── services grid ─────────────────────────────────────────────────────────
  Widget _buildServicesGrid() {
    final services = [
      (icon: Icons.home_rounded,           label: t(context, 'homeCare'),  color: const Color(0xFF007F78)),
      (icon: Icons.local_hospital_rounded, label: t(context, 'klinik'),    color: const Color(0xFF5B5FC8)),
      (icon: Icons.directions_run_rounded, label: t(context, 'rehab'),     color: const Color(0xFFE87040)),
      (icon: Icons.favorite_rounded,       label: t(context, 'wellness'),  color: const Color(0xFFD04080)),
    ];
    return Row(
      children: services.map((s) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: s == services.last ? 0 : 10),
            child: _buildServiceItem(s.icon, s.label, s.color),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServiceItem(IconData icon, String label, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.2,
              ),
            ),
          ],
        ),
      );

  // ── progress card ─────────────────────────────────────────────────────────
  Widget _buildProgressCard() => Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Pain Score',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const Spacer(),
                _weekChip(t(context, 'weeklyProgress'), true),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              t(context, 'tipsStretchBody'),
              style: const TextStyle(fontSize: 11, color: _ink3),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 130,
              child: CustomPaint(
                painter: _ModernProgressPainter(),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      );

  Widget _weekChip(String label, bool active) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _c100 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: active ? _c700 : _ink3,
          ),
        ),
      );

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

// ─── Modern Progress Painter ──────────────────────────────────────────────────

class _ModernProgressPainter extends CustomPainter {
  static const _data = [7.5, 6.0, 6.5, 4.5, 5.0, 3.5, 4.0];
  // Days are kept short codes — same in both languages
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 10.0;
    const padR = 10.0;
    const padT = 8.0;
    const padB = 24.0;
    final chartW = size.width - padL - padR;
    final chartH = size.height - padT - padB;

    final maxVal = 10.0;
    final minVal = 0.0;

    double xOf(int i) => padL + i * chartW / (_data.length - 1);
    double yOf(double v) =>
        padT + chartH - (v - minVal) / (maxVal - minVal) * chartH;

    // grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFF0F5F5)
      ..strokeWidth = 1;
    for (var i = 0; i <= 5; i++) {
      final y = padT + i * chartH / 5;
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);
    }

    // gradient fill
    final fillPath = Path();
    fillPath.moveTo(xOf(0), yOf(_data[0]));
    for (var i = 1; i < _data.length; i++) {
      final cpx = (xOf(i - 1) + xOf(i)) / 2;
      fillPath.cubicTo(
        cpx, yOf(_data[i - 1]),
        cpx, yOf(_data[i]),
        xOf(i), yOf(_data[i]),
      );
    }
    fillPath.lineTo(xOf(_data.length - 1), padT + chartH);
    fillPath.lineTo(xOf(0), padT + chartH);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _c500.withValues(alpha: 0.25),
          _c500.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, padT, size.width, chartH));
    canvas.drawPath(fillPath, fillPaint);

    // line
    final linePath = Path();
    linePath.moveTo(xOf(0), yOf(_data[0]));
    for (var i = 1; i < _data.length; i++) {
      final cpx = (xOf(i - 1) + xOf(i)) / 2;
      linePath.cubicTo(
        cpx, yOf(_data[i - 1]),
        cpx, yOf(_data[i]),
        xOf(i), yOf(_data[i]),
      );
    }
    final linePaint = Paint()
      ..color = _c500
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // dots + highlight last
    for (var i = 0; i < _data.length; i++) {
      final cx = xOf(i);
      final cy = yOf(_data[i]);
      final isLast = i == _data.length - 1;

      if (isLast) {
        canvas.drawCircle(
          Offset(cx, cy),
          8,
          Paint()..color = _c500.withValues(alpha: 0.2),
        );
      }
      canvas.drawCircle(
        Offset(cx, cy),
        isLast ? 5 : 3.5,
        Paint()..color = isLast ? _c700 : _c300,
      );
      canvas.drawCircle(
        Offset(cx, cy),
        isLast ? 2.5 : 1.5,
        Paint()..color = Colors.white,
      );
    }

    // day labels
    for (var i = 0; i < _days.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: _days[i],
          style: const TextStyle(fontSize: 9, color: _ink3),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(xOf(i) - tp.width / 2, size.height - padB + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
