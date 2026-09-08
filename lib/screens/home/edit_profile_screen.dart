import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/app_language.dart';
import '../../services/screen_security_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/custom_bottom_sheet.dart';
import '../../widgets/custom_date_picker.dart';
import 'change_pin_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _deletePhotoAction = 'delete-photo';
const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _c300 = Color(0xFF5ECFC9);
const _c100 = Color(0xFFD4F5F3);
const _bg = Color(0xFFF0F7F7);
const _ink = Color(0xFF0E2C2F);
const _ink2 = Color(0xFF3D6065);
const _ink3 = Color(0xFF8AA8AC);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin, SecureScreenMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtr = TextEditingController();
  final _nikCtr = TextEditingController();
  final _addressCtr = TextEditingController();

  DateTime? _birthDate;
  String? _gender;
  String? _phone;
  String? _email;
  String? _profileImageUrl;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isDirty = false;
  bool _profileChanged = false;
  bool _hidePhone = true;
  int _changePinCooldownSeconds = 0;
  Timer? _changePinTimer;

  String get _displayPhone {
    final raw = _phone ?? '-';
    if (raw.isEmpty || raw == '-') return '-';
    if (!_hidePhone) return raw;
    if (raw.length > 6) {
      final prefix = raw.substring(0, 7);
      final suffix = raw.length >= 12 ? raw.substring(raw.length - 3) : '';
      final maskedLen = (raw.length - prefix.length - suffix.length).clamp(
        3,
        8,
      );
      return '$prefix${'•' * maskedLen}$suffix';
    }
    return '••••••••';
  }

  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  static const _genders = ['Laki-laki', 'Perempuan'];

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();
    _loadProfile();
  }

  @override
  void dispose() {
    _changePinTimer?.cancel();
    _enterCtrl.dispose();
    _nameCtr.dispose();
    _nikCtr.dispose();
    _addressCtr.dispose();
    super.dispose();
  }

  // ── load ──────────────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    try {
      final svc = SupabaseAuthService();
      final profile = await svc.checkUserProfileExists();
      if (!mounted || profile == null) return;

      final bdStr = profile['birth_date']?.toString();
      DateTime? bd;
      if (bdStr != null && bdStr.length >= 10) {
        bd = DateTime.tryParse(bdStr.substring(0, 10));
      }

      final rawPhone = profile['phone']?.toString().trim() ?? '';
      final displayPhone = rawPhone.isNotEmpty
          ? '+62 ${rawPhone.replaceAll(RegExp(r'^\+?62'), '')}'
          : '-';

      setState(() {
        _nameCtr.text = profile['full_name']?.toString().trim() ?? '';
        _nikCtr.text = profile['nik']?.toString().trim() ?? '';
        _addressCtr.text = profile['address']?.toString().trim() ?? '';
        _email = profile['email']?.toString().trim();
        _phone = displayPhone;
        _birthDate = bd;
        _gender = profile['gender']?.toString();
        final rawUrl = profile['profile_photo_url']?.toString().trim() ?? '';
        _profileImageUrl = rawUrl.isNotEmpty ? rawUrl : null;
      });
      _restoreChangePinCooldown(rawPhone);
    } catch (e) {
      debugPrint('EditProfile load error: $e');
    }
  }

  Future<void> _restoreChangePinCooldown(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return;

    final remaining = await SupabaseAuthService().newPinCooldownRemaining(
      phone: digits,
    );
    if (!mounted) return;
    if (remaining <= 0) {
      _changePinTimer?.cancel();
      if (_changePinCooldownSeconds != 0) {
        setState(() => _changePinCooldownSeconds = 0);
      }
      return;
    }

    setState(() => _changePinCooldownSeconds = remaining);
    var secondsRemaining = remaining;
    _changePinTimer?.cancel();
    _changePinTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (secondsRemaining > 1) {
        secondsRemaining--;
        setState(() => _changePinCooldownSeconds = secondsRemaining);
      } else {
        timer.cancel();
        setState(() => _changePinCooldownSeconds = 0);
      }
    });
  }

  // ── save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final svc = SupabaseAuthService();
      final user = svc.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final bdStr = _birthDate != null
          ? '${_birthDate!.year.toString().padLeft(4, '0')}'
                '-${_birthDate!.month.toString().padLeft(2, '0')}'
                '-${_birthDate!.day.toString().padLeft(2, '0')}'
          : null;

      await svc.client
          .from('profiles')
          .update({
            'full_name': _nameCtr.text.trim(),
            'birth_date': bdStr,
            'gender': _gender,
            'nik': _nikCtr.text.trim().isEmpty ? null : _nikCtr.text.trim(),
            'address': _addressCtr.text.trim().isEmpty
                ? null
                : _addressCtr.text.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isDirty = false;
        _profileChanged = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(context, 'profileSavedSuccess')),
          backgroundColor: _c700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: t(context, 'failedTitle'),
        subtitle: t(context, 'saveProfileFailed'),
        singleButtonText: t(context, 'closeBtn'),
        onSinglePressed: () => Navigator.of(context).pop(),
      );
    }
  }

  // ── photo ─────────────────────────────────────────────────────────────────
  Future<void> _pickAndUploadPhoto() async {
    final source = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFDDE5E6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _sheetOption(
              ctx,
              Icons.camera_alt_rounded,
              t(context, 'camera'),
              ImageSource.camera,
            ),
            const SizedBox(height: 8),
            _sheetOption(
              ctx,
              Icons.photo_library_rounded,
              t(context, 'gallery'),
              ImageSource.gallery,
            ),
            if (_profileImageUrl != null) ...[
              const SizedBox(height: 8),
              _sheetOption(
                ctx,
                Icons.delete_outline_rounded,
                t(context, 'deletePhoto'),
                _deletePhotoAction,
                danger: true,
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (source == _deletePhotoAction && _profileImageUrl != null) {
      _removePhoto();
      return;
    }
    if (source == null) return;
    final imageSource = source as ImageSource;

    if (imageSource == ImageSource.camera) {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (mounted) {
          _showCameraPermissionDialog(cameraStatus.isPermanentlyDenied);
        }
        return;
      }
    }

    final file = await ImagePicker().pickImage(
      source: imageSource,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? 'image/jpeg';
      final url = await SupabaseAuthService().uploadProfilePhoto(
        imageBytes: bytes,
        contentType: mime,
      );
      if (!mounted) return;
      setState(() {
        _profileImageUrl = url;
        _isUploading = false;
        _profileChanged = true;
      });
      _snack(t(context, 'profilePhotoUpdated'));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _snack(t(context, 'uploadPhotoFailed'));
    }
  }

  void _showCameraPermissionDialog(bool permanentlyDenied) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          t(context, 'cameraPermissionTitle'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: Text(
          permanentlyDenied
              ? t(context, 'cameraPermissionSettingsDesc')
              : t(context, 'cameraPermissionDesc'),
          style: const TextStyle(fontSize: 13, color: _ink2, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t(context, 'cancel')),
          ),
          if (permanentlyDenied)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openAppSettings();
              },
              child: Text(t(context, 'openSettings')),
            ),
        ],
      ),
    );
  }

  Widget _sheetOption(
    BuildContext ctx,
    IconData icon,
    String label,
    Object? src, {
    bool danger = false,
  }) => GestureDetector(
    onTap: () => Navigator.of(ctx).pop(src),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFECEB) : _bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: danger ? const Color(0xFFD94F45) : _c700),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: danger ? const Color(0xFFD94F45) : _ink,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _removePhoto() async {
    setState(() => _isUploading = true);
    try {
      final svc = SupabaseAuthService();
      final user = svc.client.auth.currentUser;
      if (user != null) {
        await svc.client
            .from('profiles')
            .update({
              'profile_photo_url': null,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', user.id);
      }
      if (!mounted) return;
      setState(() {
        _profileImageUrl = null;
        _isUploading = false;
        _profileChanged = true;
      });
      _snack(t(context, 'profilePhotoDeleted'));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploading = false);
    }
  }

  // ── date ──────────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => CustomDatePickerDialog(
        initialDate: _birthDate ?? DateTime(2000),
        firstDate: DateTime(1920),
        lastDate: DateTime.now(),
      ),
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _isDirty = true;
      });
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} '
      '${_monthName(d.month)} ${d.year}';

  String _monthName(int m) {
    final lang = AppLanguageScope.current(context);
    final en = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final id = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return lang == AppLanguage.en ? en[m] : id[m];
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: _c700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_profileChanged);
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
                    child: Form(
                      key: _formKey,
                      onChanged: () {
                        if (!_isDirty) setState(() => _isDirty = true);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAvatar(),
                          const SizedBox(height: 32),

                          _sectionTitle(t(context, 'personalInfoSection')),
                          const SizedBox(height: 12),
                          _buildCard(
                            children: [
                              _editableField(
                                controller: _nameCtr,
                                icon: Icons.person_outline_rounded,
                                label: t(context, 'fullName'),
                                hint: t(context, 'fullNameHint'),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? t(context, 'fullNameRequired')
                                    : null,
                              ),
                              _divider(),
                              _genderPicker(),
                              _divider(),
                              _datePicker(),
                              _divider(),
                              _editableField(
                                controller: _nikCtr,
                                icon: Icons.badge_outlined,
                                label: t(context, 'nik'),
                                hint: t(context, 'nikHint'),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return null;
                                  }
                                  if (v.trim().length != 16) {
                                    return t(context, 'nikLengthError');
                                  }
                                  return null;
                                },
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(16),
                                ],
                              ),
                              _divider(),
                              _editableField(
                                controller: _addressCtr,
                                icon: Icons.location_on_outlined,
                                label: t(context, 'address'),
                                hint: t(context, 'addressHint'),
                                maxLines: 3,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          _sectionTitle(t(context, 'contactSection')),
                          const SizedBox(height: 12),
                          _buildCard(
                            children: [
                              _readOnlyField(
                                label: t(context, 'phoneNumber'),
                                value: _displayPhone,
                                icon: Icons.phone_iphone_rounded,
                                onActionTap: () =>
                                    setState(() => _hidePhone = !_hidePhone),
                                actionIcon: _hidePhone
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              _divider(),
                              _readOnlyField(
                                label: t(context, 'email'),
                                value: _email?.isNotEmpty == true
                                    ? _email!
                                    : '-',
                                icon: Icons.email_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          _sectionTitle(t(context, 'securitySection')),
                          const SizedBox(height: 12),
                          _buildCard(
                            onTap: _changePinCooldownSeconds > 0
                                ? null
                                : _openChangePin,
                            children: [_changePinButton()],
                          ),
                          const SizedBox(height: 40),

                          _saveButton(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── app bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() => SliverAppBar(
    pinned: true,
    backgroundColor: _bg,
    foregroundColor: _ink,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => Navigator.of(context).pop(_profileChanged),
    ),
    title: Text(
      t(context, 'menuEditProfile'),
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: _ink,
      ),
    ),
    centerTitle: true,
  );

  // ── avatar ────────────────────────────────────────────────────────────────
  Widget _buildAvatar() => Center(
    child: Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_c500, _c300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _c500.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 56,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 52,
              backgroundColor: _c100,
              backgroundImage: _profileImageUrl != null
                  ? NetworkImage(_profileImageUrl!)
                  : null,
              child: _isUploading
                  ? const CircularProgressIndicator(
                      color: _c700,
                      strokeWidth: 2.5,
                    )
                  : _profileImageUrl == null
                  ? const Icon(Icons.person_rounded, color: _c500, size: 52)
                  : null,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 4,
          child: GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadPhoto,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _ink,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: _ink.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isUploading
                    ? Icons.hourglass_top_rounded
                    : Icons.camera_alt_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // ── helpers ───────────────────────────────────────────────────────────────
  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _ink2,
      ),
    ),
  );

  Widget _buildCard({required List<Widget> children, VoidCallback? onTap}) {
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: children),
    );

    return onTap == null ? card : GestureDetector(onTap: onTap, child: card);
  }

  Widget _divider() => const Divider(
    height: 1,
    thickness: 1,
    color: Color(0xFFF0F4F4),
    indent: 16,
    endIndent: 16,
  );

  Widget _editableField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _c100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: _c700),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _ink3,
                ),
              ),
              const SizedBox(height: 2),
              TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                validator: validator,
                maxLines: maxLines,
                inputFormatters: inputFormatters,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _ink3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _readOnlyField({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onActionTap,
    IconData? actionIcon,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F8F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: _ink3),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _ink3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  letterSpacing: (onActionTap != null && _hidePhone)
                      ? 1.0
                      : 0.0,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onActionTap != null
              ? () {
                  HapticFeedback.lightImpact();
                  onActionTap();
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8F8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              actionIcon ?? Icons.lock_outline_rounded,
              size: 16,
              color: _ink3,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _genderPicker() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(context, 'gender'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _ink3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _genders.map((g) {
            final selected = _gender == g;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _gender = g;
                  _isDirty = true;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: g == _genders.last ? 0 : 8),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? _c700 : const Color(0xFFF5F8F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        g == 'Laki-laki'
                            ? t(context, 'male')
                            : t(context, 'female'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: selected ? Colors.white : _ink2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );

  Widget _datePicker() => GestureDetector(
    onTap: _pickDate,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _c100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 20,
              color: _c700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(context, 'birthDate'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _ink3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _birthDate != null
                      ? _fmt(_birthDate!)
                      : t(context, 'selectBirthDateHint'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _birthDate != null ? _ink : _ink3,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: _ink3),
        ],
      ),
    ),
  );

  void _openChangePin() {
    final rawPhone = _phone ?? '';
    final digits = rawPhone.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(context, 'phoneNotFound')),
          backgroundColor: const Color(0xFFD94F45),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ChangePinScreen(phoneNumber: digits),
          ),
        )
        .then((_) {
          if (mounted) _restoreChangePinCooldown(digits);
        });
  }

  Widget _changePinButton() {
    final isCooldown = _changePinCooldownSeconds > 0;

    return GestureDetector(
      onTap: isCooldown ? null : _openChangePin,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.password_rounded,
                size: 20,
                color: isCooldown ? _ink3 : const Color(0xFFE87A3E),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'menuChangePin'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCooldown
                        ? t(context, 'changePinAvailableIn').replaceAll(
                            '{seconds}',
                            '$_changePinCooldownSeconds',
                          )
                        : t(context, 'menuChangePinSub'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isCooldown ? const Color(0xFFD94F45) : _ink3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_right_rounded,
              size: 20,
              color: isCooldown ? _ink3.withValues(alpha: 0.5) : _ink3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() => Container(
    width: double.infinity,
    height: 56,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: (_isDirty && !_isLoading)
          ? const LinearGradient(colors: [_c700, _c500])
          : null,
      color: (_isDirty && !_isLoading) ? null : _ink3.withValues(alpha: 0.2),
      boxShadow: (_isDirty && !_isLoading)
          ? [
              BoxShadow(
                color: _c500.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    ),
    child: ElevatedButton(
      onPressed: (_isDirty && !_isLoading) ? _save : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Text(
              t(context, 'saveAndContinue'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
    ),
  );
}
