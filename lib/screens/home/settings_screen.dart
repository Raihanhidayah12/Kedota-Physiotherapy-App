import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import 'edit_profile_screen.dart';
import 'notification_preferences_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _c300 = Color(0xFF5ECFC9);
const _c100 = Color(0xFFD4F5F3);
const _bg   = Color(0xFFF0F7F7);
const _ink  = Color(0xFF0E2C2F);
const _ink3 = Color(0xFF8AA8AC);

// ─── SettingsScreen ───────────────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          t(context, 'settingsTitle'),
          style: const TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink),
      ),
      body: const SettingsBody(),
    );
  }
}

// ─── SettingsBody ─────────────────────────────────────────────────────────────
class SettingsBody extends StatefulWidget {
  const SettingsBody({super.key});

  @override
  State<SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<SettingsBody>
    with SingleTickerProviderStateMixin {
  String _fullName = 'Pasien Kedota';
  String? _profileImageUrl;
  String _phone = '-';
  bool _hidePhone = true;
  bool _isProfileIncomplete = false; // true jika NIK atau alamat kosong

  String get _displayPhone {
    if (_phone.isEmpty || _phone == '-') return '-';
    if (!_hidePhone) return _phone;
    if (_phone.length > 6) {
      final prefix = _phone.substring(0, 4);
      final suffix = _phone.length >= 10 ? _phone.substring(_phone.length - 3) : '';
      final masked = (_phone.length - prefix.length - suffix.length).clamp(3, 8);
      return '$prefix${'•' * masked}$suffix';
    }
    return '••••••••';
  }

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadProfile();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final service = SupabaseAuthService();
      final user    = service.client.auth.currentUser;
      final profile = await service.checkUserProfileExists();
      final metadata    = user?.userMetadata ?? <String, dynamic>{};
      final profileName = profile?['full_name']?.toString().trim() ?? '';
      final metaName    =
          (metadata['full_name'] ?? metadata['name'])?.toString().trim();
      final persistedUrl =
          profile?['profile_photo_url']?.toString().trim() ?? '';
      final imageUrl =
          persistedUrl.isNotEmpty && !_isRateLimitedHost(persistedUrl)
              ? persistedUrl
              : _firstNonEmpty([
                  profile?['avatar_url'],
                  profile?['photo_url'],
                  metadata['avatar_url'],
                  metadata['picture'],
                ]);
      if (!mounted) return;
      setState(() {
        _fullName = profileName.isNotEmpty
            ? profileName
            : (metaName?.isNotEmpty == true ? metaName! : _fullName);
        _profileImageUrl = imageUrl;
        _phone = profile?['phone']?.toString().trim() ??
            metadata['phone']?.toString().trim() ??
            user?.phone ??
            '-';
        // Cek NIK dan alamat — jika salah satu kosong, tampilkan banner
        final nik     = profile?['nik']?.toString().trim() ?? '';
        final address = profile?['address']?.toString().trim() ?? '';
        _isProfileIncomplete = nik.isEmpty || address.isEmpty;
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

  void _showSnackBar(String key) {
    final label = t(context, key);
    final soon  = t(context, 'comingSoon');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — $soon'),
        backgroundColor: _c700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

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
            Text(
              t(ctx, 'logoutTitle'),
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: _ink),
            ),
            const SizedBox(height: 8),
            Text(
              t(ctx, 'logoutDesc'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _ink3, height: 1.5),
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
                            color: Colors.white, fontWeight: FontWeight.w700)),
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
    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Title "Pengaturan"
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              t(context, 'settingsTitle'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          _buildProfileHeader(),
          const SizedBox(height: 8),
          // Banner notifikasi kelengkapan profil
          if (_isProfileIncomplete)
            _buildIncompleteProfileBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Akun ──────────────────────────────────────────────
                _buildSectionLabel(t(context, 'groupAccount')),
                _buildCard([
                  _buildItem(
                    icon: Icons.person_outline_rounded,
                    label: t(context, 'menuEditProfile'),
                    onTap: () async {
                      final refreshed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                            builder: (_) => const EditProfileScreen()),
                      );
                      if (refreshed == true && mounted) _loadProfile();
                    },
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Preferensi ────────────────────────────────────────
                _buildSectionLabel(t(context, 'groupPreferences')),
                _buildCard([
                  _buildItem(
                    icon: Icons.notifications_outlined,
                    label: t(context, 'menuNotification'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              const NotificationPreferencesScreen()),
                    ),
                  ),
                  _buildDivider(),
                  _buildLanguageItem(),
                ]),
                const SizedBox(height: 24),

                // ── Dukungan & Tentang ────────────────────────────────
                _buildSectionLabel(t(context, 'groupSupport')),
                _buildCard([
                  _buildItem(
                    icon: Icons.help_outline_rounded,
                    label: t(context, 'menuFaq'),
                    onTap: () => _showSnackBar('menuFaq'),
                  ),
                  _buildDivider(),
                  _buildItem(
                    icon: Icons.article_outlined,
                    label: t(context, 'menuTerms'),
                    onTap: () => _showSnackBar('menuTerms'),
                  ),
                  _buildDivider(),
                  _buildItem(
                    icon: Icons.info_outline_rounded,
                    label: t(context, 'menuPrivacy'),
                    onTap: () => _showSnackBar('menuPrivacy'),
                  ),
                  _buildDivider(),
                  _buildItem(
                    icon: Icons.headset_mic_outlined,
                    label: t(context, 'menuCS'),
                    onTap: () => _showSnackBar('menuCS'),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Keluar ────────────────────────────────────────────
                _buildLogoutCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Incomplete profile banner ─────────────────────────────────────────────
  Widget _buildIncompleteProfileBanner() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: GestureDetector(
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
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB7820A),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );

  // ── Profile header ────────────────────────────────────────────────────────
  Widget _buildProfileHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: _c100,
              backgroundImage: _profileImageUrl != null
                  ? NetworkImage(_profileImageUrl!)
                  : null,
              onBackgroundImageError: _profileImageUrl != null
                  ? (e, s) => _handleImageError()
                  : null,
              child: _profileImageUrl == null
                  ? const Icon(Icons.person_rounded, color: _c500, size: 32)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _displayPhone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: _ink3,
                            letterSpacing: _hidePhone ? 1.0 : 0.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _hidePhone = !_hidePhone),
                        child: Icon(
                          _hidePhone
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 16,
                          color: _ink3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Section label ─────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _ink3,
          ),
        ),
      );

  // ── Card wrapper ──────────────────────────────────────────────────────────
  Widget _buildCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: children),
      );

  Widget _buildDivider() =>
      Divider(height: 1, indent: 52, endIndent: 0, color: _bg);

  // ── Generic menu item ─────────────────────────────────────────────────────
  Widget _buildItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: _c500, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: _ink3),
            ],
          ),
        ),
      );

  // ── Language toggle ───────────────────────────────────────────────────────
  Widget _buildLanguageItem() {
    final lang = AppLanguageScope.current(context);
    final isEn = lang == AppLanguage.en;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.language_rounded, color: _c500, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              t(context, 'languageToggle'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _ink,
              ),
            ),
          ),
          // Custom toggle dengan label ID/EN di dalam thumb
          GestureDetector(
            onTap: () => AppLanguageScope.toggle(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: 64,
              height: 32,
              decoration: BoxDecoration(
                color: isEn ? _c500 : const Color(0xFFDDE5E6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Thumb dengan label teks
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    left: isEn ? 34 : 2,
                    top: 2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isEn ? 'EN' : 'ID',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isEn ? _c500 : _ink3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logout card ───────────────────────────────────────────────────────────
  Widget _buildLogoutCard() => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFECEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD5D3)),
        ),
        child: InkWell(
          onTap: _confirmLogout,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.logout_rounded,
                    color: Color(0xFFD94F45), size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    t(context, 'menuLogout'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD94F45),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: Color(0xFFD94F45)),
              ],
            ),
          ),
        ),
      );
}
