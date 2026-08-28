import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _c900 = Color(0xFF004D47);
const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _c300 = Color(0xFF5ECFC9);
const _c100 = Color(0xFFD4F5F3);
const _bg   = Color(0xFFF0F7F7);
const _ink  = Color(0xFF0E2C2F);
const _ink2 = Color(0xFF3D6065);
const _ink3 = Color(0xFF8AA8AC);

// ─── Menu item model ──────────────────────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String labelKey;
  final String? subtitleKey;
  final bool isDanger;
  final bool isLanguageToggle;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.labelKey,
    this.subtitleKey,
    this.isDanger = false,
    this.isLanguageToggle = false,
    this.onTap,
  });
}

// ─── Body widget ──────────────────────────────────────────────────────────────

class SettingsBody extends StatefulWidget {
  const SettingsBody({super.key});

  @override
  State<SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<SettingsBody>
    with TickerProviderStateMixin {
  // ── State profil ──────────────────────────────────────────────────────────
  String _fullName = 'Pasien Kedota';
  String? _profileImageUrl;
  String _userId = '-';
  String _phone = '-';
  bool _emailVerified = false;

  // ── Animasi ───────────────────────────────────────────────────────────────
  late AnimationController _headerCtrl;
  late Animation<double>   _headerExpand;
  late Animation<double>   _avatarFade;
  late Animation<double>   _infoFade;
  late Animation<Offset>   _infoSlide;

  late AnimationController        _contentCtrl;
  static const _kSections = 4;
  late List<Animation<double>>    _sectionFades;
  late List<Animation<Offset>>    _sectionSlides;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _contentCtrl.forward();
    });
    _loadProfile();
  }

  void _setupAnimations() {
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));

    _headerExpand = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic),
    );
    _avatarFade = CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _infoFade = CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.15, 0.7, curve: Curves.easeOut),
    );
    _infoSlide = Tween<Offset>(begin: const Offset(-0.2, 0), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.15, 0.7, curve: Curves.easeOutCubic),
    ));

    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _sectionFades = List.generate(_kSections, (i) {
      final s = (i * 0.2).clamp(0.0, 1.0);
      final e = (s + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
          parent: _contentCtrl,
          curve: Interval(s, e, curve: Curves.easeOut));
    });
    _sectionSlides = List.generate(_kSections, (i) {
      final s = (i * 0.2).clamp(0.0, 1.0);
      final e = (s + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
          .animate(CurvedAnimation(
              parent: _contentCtrl,
              curve: Interval(s, e, curve: Curves.easeOutCubic)));
    });
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SettingsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _headerCtrl.reset();
    _contentCtrl.reset();
    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  // ── Load profil ───────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    try {
      final service = SupabaseAuthService();
      final user    = service.client.auth.currentUser;
      final profile = await service.checkUserProfileExists();
      final metadata    = user?.userMetadata ?? <String, dynamic>{};
      final profileName = profile?['full_name']?.toString().trim() ?? '';
      final metaName    = (metadata['full_name'] ?? metadata['name'])
          ?.toString().trim();
      final persistedUrl =
          profile?['profile_photo_url']?.toString().trim() ?? '';
      final imageUrl = persistedUrl.isNotEmpty && !_isRateLimitedHost(persistedUrl)
          ? persistedUrl
          : _firstNonEmpty([
              profile?['avatar_url'], profile?['photo_url'],
              metadata['avatar_url'], metadata['picture'],
            ]);
      if (!mounted) return;
      setState(() {
        _fullName = profileName.isNotEmpty
            ? profileName
            : (metaName?.isNotEmpty == true ? metaName! : _fullName);
        _profileImageUrl = imageUrl;
        _userId   = user?.id.substring(0, 8).toUpperCase() ?? '-';
        _phone    = profile?['phone']?.toString().trim() ??
            metadata['phone']?.toString().trim() ??
            user?.phone ?? '-';
        _emailVerified = user?.emailConfirmedAt != null;
      });
    } catch (e) {
      debugPrint('Settings profile load error: $e');
    }
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      final s = v?.toString().trim() ?? '';
      if (s.isNotEmpty && !_isRateLimitedHost(s)) return s;
    }
    return null;
  }

  bool _isRateLimitedHost(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host == 'googleusercontent.com' ||
        host.endsWith('.googleusercontent.com');
  }

  void _handleImageError() {
    if (!mounted || _profileImageUrl == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _profileImageUrl = null);
    });
  }

  // ── Daftar menu ───────────────────────────────────────────────────────────
  List<List<_MenuItem>> get _menuGroups => [
        // Grup 1: Akun
        [
          _MenuItem(
            icon: Icons.person_outline_rounded,
            iconColor: _c700,
            iconBg: _c100,
            labelKey: 'menuEditProfile',
            subtitleKey: 'menuEditProfileSub',
            onTap: () => _showSnackBar('menuEditProfile'),
          ),
          _MenuItem(
            icon: Icons.lock_outline_rounded,
            iconColor: const Color(0xFF5B5FC8),
            iconBg: const Color(0xFFEEEFFF),
            labelKey: 'menuChangePin',
            subtitleKey: 'menuChangePinSub',
            onTap: () => _showSnackBar('menuChangePin'),
          ),
          _MenuItem(
            icon: Icons.notifications_outlined,
            iconColor: const Color(0xFFD4920A),
            iconBg: const Color(0xFFFFEEB0),
            labelKey: 'menuNotification',
            subtitleKey: 'menuNotificationSub',
            onTap: () => _showSnackBar('menuNotification'),
          ),
        ],
        // Grup 2: Layanan
        [
          _MenuItem(
            icon: Icons.headset_mic_outlined,
            iconColor: const Color(0xFF00897B),
            iconBg: const Color(0xFFE0F5F3),
            labelKey: 'menuCS',
            subtitleKey: 'menuCSSub',
            onTap: () => _showSnackBar('menuCS'),
          ),
          _MenuItem(
            icon: Icons.location_on_outlined,
            iconColor: const Color(0xFFE87040),
            iconBg: const Color(0xFFFFEDE6),
            labelKey: 'menuAddress',
            subtitleKey: 'menuAddressSub',
            onTap: () => _showSnackBar('menuAddress'),
          ),
        ],
        // Grup 3: Informasi
        [
          _MenuItem(
            icon: Icons.help_outline_rounded,
            iconColor: const Color(0xFF5B5FC8),
            iconBg: const Color(0xFFEEEFFF),
            labelKey: 'menuFaq',
            subtitleKey: 'menuFaqSub',
            onTap: () => _showSnackBar('menuFaq'),
          ),
          _MenuItem(
            icon: Icons.article_outlined,
            iconColor: _c700,
            iconBg: _c100,
            labelKey: 'menuTerms',
            subtitleKey: 'menuTermsSub',
            onTap: () => _showSnackBar('menuTerms'),
          ),
          _MenuItem(
            icon: Icons.privacy_tip_outlined,
            iconColor: const Color(0xFF2196F3),
            iconBg: const Color(0xFFE3F2FD),
            labelKey: 'menuPrivacy',
            subtitleKey: 'menuPrivacySub',
            onTap: () => _showSnackBar('menuPrivacy'),
          ),
          _MenuItem(
            icon: Icons.info_outline_rounded,
            iconColor: _ink3,
            iconBg: const Color(0xFFECF1F2),
            labelKey: 'menuAbout',
            subtitleKey: 'menuAboutSub',
            onTap: () => _showAboutDialog(),
          ),
        ],
        // Grup 4: Lainnya
        [
          _MenuItem(
            icon: Icons.language_rounded,
            iconColor: _c700,
            iconBg: _c100,
            labelKey: 'languageToggle',
            subtitleKey: 'languageToggleSub',
            isLanguageToggle: true,
            onTap: () => AppLanguageScope.toggle(context),
          ),
          _MenuItem(
            icon: Icons.logout_rounded,
            iconColor: const Color(0xFFD94F45),
            iconBg: const Color(0xFFFFECEB),
            labelKey: 'menuLogout',
            subtitleKey: 'menuLogoutSub',
            isDanger: true,
            onTap: () => _confirmLogout(),
          ),
        ],
      ];

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _showSnackBar(String key) {
    final label = t(context, key);
    final soon  = t(context, 'comingSoon');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — $soon'),
        backgroundColor: _c700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAboutDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ───────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE5E6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // ── App icon + nama ───────────────────────────────────────
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _c500.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/image/logo 2.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, s) => Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_c900, _c500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.healing_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Kedota',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t(ctx, 'aboutAppDesc'),
              style: const TextStyle(fontSize: 13, color: _ink3),
            ),
            const SizedBox(height: 12),

            // ── Versi badge ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: _c100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 13, color: _c700),
                  const SizedBox(width: 6),
                  Text(
                    t(ctx, 'aboutVersion'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _c700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Deskripsi ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                t(ctx, 'aboutDesc'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: _ink2,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Fitur highlights ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildFeatureChip(ctx, Icons.event_available_rounded, 'aboutFeatureBooking'),
                  const SizedBox(width: 8),
                  _buildFeatureChip(ctx, Icons.monitor_heart_rounded, 'aboutFeatureMonitor'),
                  const SizedBox(width: 8),
                  _buildFeatureChip(ctx, Icons.home_rounded, 'aboutFeatureHomeCare'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Divider + info developer ──────────────────────────────
            Divider(height: 1, color: _bg, indent: 24, endIndent: 24),
            const SizedBox(height: 16),
            Text(
              t(ctx, 'aboutDeveloper'),
              style: const TextStyle(fontSize: 11, color: _ink3),
            ),
            const SizedBox(height: 4),
            const Text(
              'PT Trifa Axis Global',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _ink2,
              ),
            ),
            const SizedBox(height: 20),

            // ── Tombol tutup ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _c500,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    t(ctx, 'closeBtn'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(BuildContext ctx, IconData icon, String labelKey) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: _c100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: _c700),
              const SizedBox(height: 6),
              Text(
                t(ctx, labelKey),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _c700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      );

  void _confirmLogout() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFECEB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Color(0xFFD94F45), size: 24),
            ),
            const SizedBox(height: 16),
            Text(t(ctx, 'logoutTitle'),
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _ink)),
            const SizedBox(height: 8),
            Text(
              t(ctx, 'logoutDesc'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: _ink3, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _c300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(t(ctx, 'cancel'),
                        style: const TextStyle(
                            color: _c700, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _doLogout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD94F45),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Text(t(ctx, 'logoutConfirm'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doLogout() async {
    try {
      await SupabaseAuthService().signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: CustomScrollView(
        slivers: [
          _buildSliverHeader(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),
                ..._buildMenuSections(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fadeSlide(int index, Widget child) => FadeTransition(
        opacity: _sectionFades[index],
        child: SlideTransition(
            position: _sectionSlides[index], child: child),
      );

  // ── Sliver header ─────────────────────────────────────────────────────────
  Widget _buildSliverHeader() => SliverToBoxAdapter(
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _headerExpand,
            builder: (context, child) => Align(
              alignment: Alignment.topCenter,
              heightFactor: _headerExpand.value,
              child: child,
            ),
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
                  Positioned(
                    right: -60, top: -60,
                    child: _circle(200, Colors.white, 0.05),
                  ),
                  Positioned(
                    right: 30, top: 30,
                    child: _circle(80, Colors.white, 0.07),
                  ),
                  Positioned(
                    left: -40, bottom: -20,
                    child: _circle(120, _c300, 0.15),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + 16,
                      20,
                      28,
                    ),
                    child: Row(
                      children: [
                        FadeTransition(
                          opacity: _avatarFade,
                          child: _buildAvatar(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FadeTransition(
                            opacity: _infoFade,
                            child: SlideTransition(
                              position: _infoSlide,
                              child: _buildProfileInfo(),
                            ),
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

  Widget _buildAvatar() => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: _c900.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 36,
          backgroundColor: _c300,
          backgroundImage: _profileImageUrl == null
              ? null
              : NetworkImage(_profileImageUrl!),
          onBackgroundImageError: _profileImageUrl == null
              ? null
              : (e, s) => _handleImageError(),
          child: _profileImageUrl == null
              ? const Icon(Icons.person_rounded,
                  color: Colors.white, size: 36)
              : null,
        ),
      );

  Widget _buildProfileInfo() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _phone,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          _buildVerificationBadge(),
          const SizedBox(height: 8),
          _buildUserIdRow(),
        ],
      );

  Widget _buildVerificationBadge() => GestureDetector(
        onTap: () => _showSnackBar('emailNotVerified'),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _emailVerified
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _emailVerified
                  ? Colors.white.withValues(alpha: 0.4)
                  : const Color(0xFFFFCC00).withValues(alpha: 0.8),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _emailVerified
                    ? Icons.verified_rounded
                    : Icons.error_outline_rounded,
                size: 12,
                color: _emailVerified
                    ? Colors.white
                    : const Color(0xFFFFCC00),
              ),
              const SizedBox(width: 5),
              Text(
                t(context,
                    _emailVerified ? 'emailVerified' : 'emailNotVerified'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _emailVerified
                      ? Colors.white
                      : const Color(0xFFFFCC00),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildUserIdRow() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ID: $_userId',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _userId));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t(context, 'idCopied')),
                  backgroundColor: _c700,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.copy_rounded,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.8)),
            ),
          ),
        ],
      );

  // ── Menu sections ─────────────────────────────────────────────────────────
  List<Widget> _buildMenuSections() {
    final groupKeys = [
      'groupAccount',
      'groupServices',
      'groupInfo',
      'groupOther',
    ];

    final widgets = <Widget>[];
    for (var i = 0; i < _menuGroups.length; i++) {
      widgets.add(
        _fadeSlide(
          i,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  t(context, groupKeys[i]).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _ink3,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              _buildMenuCard(_menuGroups[i]),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildMenuCard(List<_MenuItem> items) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: List.generate(items.length, (i) {
            final item   = items[i];
            final isLast = i == items.length - 1;
            return Column(
              children: [
                _buildMenuItem(item),
                if (!isLast)
                  Divider(height: 1, indent: 60, endIndent: 16, color: _bg),
              ],
            );
          }),
        ),
      );

  Widget _buildMenuItem(_MenuItem item) {
    final lang = AppLanguageScope.current(context);
    final isEn = lang == AppLanguage.en;

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, item.labelKey),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: item.isDanger
                          ? const Color(0xFFD94F45)
                          : _ink,
                    ),
                  ),
                  if (item.subtitleKey != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      t(context, item.subtitleKey!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: _ink3),
                    ),
                  ],
                ],
              ),
            ),
            // Tombol toggle bahasa khusus
            if (item.isLanguageToggle)
              _buildLangToggle(isEn)
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: item.isDanger
                    ? const Color(0xFFD94F45).withValues(alpha: 0.5)
                    : _ink3,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLangToggle(bool isEn) => GestureDetector(
        onTap: () => AppLanguageScope.toggle(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 66,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isEn ? _c500 : const Color(0xFFDDE5E6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment:
                    isEn ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isEn ? 'EN' : 'ID',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isEn ? _c700 : _ink3,
                    ),
                  ),
                ),
              ),
              // Label kiri/kanan
              Positioned(
                left: isEn ? 0 : 30,
                top: 0,
                bottom: 0,
                width: 28,
                child: Center(
                  child: Text(
                    isEn ? 'ID' : 'EN',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isEn
                          ? Colors.white.withValues(alpha: 0.7)
                          : _ink3,
                    ),
                  ),
                ),
              ),
            ],
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
}
