import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/app_language.dart';
import '../../services/screen_security_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/custom_bottom_sheet.dart';
import '../../widgets/custom_date_picker.dart';
import 'change_contact_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _deletePhotoAction = 'delete-photo';
const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _c100 = Color(0xFFD4F5F3);
const _bg = Color(0xFFF0F7F7);
const _ink = Color(0xFF0E2C2F);
const _ink2 = Color(0xFF3D6065);
const _ink3 = Color(0xFF8AA8AC);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.requireCompleteProfile = true});

  final bool requireCompleteProfile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin, SecureScreenMixin {
  final _nameCtr = TextEditingController();
  final _nikCtr = TextEditingController();
  final _addressCtr = TextEditingController();

  DateTime? _birthDate;
  String? _gender;
  String? _phone;
  String? _email;
  String _medicalCode = '-';
  String? _profileImageUrl;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _profileChanged = false;
  bool _hidePhone = true;

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

  // ─── Masked value getters ─────────────────────────────────────────────────

  String _maskName(String name) {
    if (name.trim().isEmpty) return '-';
    return name.trim().split(RegExp(r'\s+')).map((word) {
      if (word.length <= 2) return word;
      return '${word[0]}${'*' * (word.length - 2)}${word[word.length - 1]}';
    }).join(' ');
  }

  String _maskEmail(String? email) {
    if (email == null || email.trim().isEmpty) return '-';
    final at = email.indexOf('@');
    if (at <= 0) return email;
    return '${email[0]}****${email.substring(at)}';
  }

  String _maskDate(DateTime? d) {
    if (d == null) return '-';
    return '**/**/${d.year}';
  }

  String _previewAddress(String addr) {
    if (addr.trim().isEmpty) return '-';
    return addr.length > 22 ? '${addr.substring(0, 22)}...' : addr;
  }

  // ─── Animations ───────────────────────────────────────────────────────────
  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  List<String> get _genders => [
    t(context, 'genderMaleValue'),
    t(context, 'genderFemaleValue'),
  ];

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
        _medicalCode = profile['medical_code']?.toString().trim() ?? '-';
        _phone = displayPhone;
        _birthDate = bd;
        _gender = profile['gender']?.toString();
        final rawUrl = profile['profile_photo_url']?.toString().trim() ?? '';
        _profileImageUrl = rawUrl.isNotEmpty ? rawUrl : null;
      });
    } catch (e) {
      debugPrint('EditProfile load error: $e');
    }
  }

  Future<void> _showRequiredProfileDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE6EEEE)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x45000000),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
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
                      color: _c700,
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
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(context, 'profileRequiredMessage'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink2,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: _c700,
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
                    child: Text(t(context, 'incompleteProfileBtn')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_isLoading) return;
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
        _profileChanged = true;
      });
      showAppSnackBar(
        context,
        t(context, 'profileSavedSuccess'),
        type: AppSnackBarType.success,
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
        restrictToFutureMonths: false,
      ),
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
      _save();
    }
  }

  void _snack(String msg) =>
      showAppSnackBar(context, msg, type: AppSnackBarType.success);

  Future<void> _copyMedicalCode() async {
    await Clipboard.setData(ClipboardData(text: _medicalCode));
    if (mounted) _snack(t(context, 'patientIdCopied'));
  }

  bool get _requiredFieldsComplete {
    final nik = _nikCtr.text.trim();
    return RegExp(r'^\d{16}$').hasMatch(nik) &&
        _addressCtr.text.trim().isNotEmpty;
  }

  void _handleBack() {
    if (widget.requireCompleteProfile && !_requiredFieldsComplete) {
      _showRequiredProfileDialog();
      return;
    }
    Navigator.of(context).pop(_profileChanged);
  }

  // ── bottom sheet helpers ──────────────────────────────────────────────────

  Widget _editSheet({
    required BuildContext ctx,
    required String title,
    GlobalKey<FormState>? formKey,
    required Widget child,
    required VoidCallback onSave,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE5E6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 14),
          formKey != null ? Form(key: formKey, child: child) : child,
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onSave,
              style: FilledButton.styleFrom(
                backgroundColor: _c700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                t(ctx, 'save'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _sheetInputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _ink3, fontSize: 14),
    filled: true,
    fillColor: const Color(0xFFF5F8F8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _c500, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD94F45)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD94F45)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    isDense: true,
  );

  void _openNameSheet() {
    final sheetFormKey = GlobalKey<FormState>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _editSheet(
          ctx: ctx,
          title: t(context, 'fullName'),
          formKey: sheetFormKey,
          child: TextFormField(
            controller: _nameCtr,
            autofocus: true,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? t(context, 'fullNameRequired')
                : null,
            decoration: _sheetInputDecoration(t(context, 'fullNameHint')),
          ),
          onSave: () {
            if (sheetFormKey.currentState!.validate()) {
              _save();
              Navigator.of(ctx).pop();
            }
          },
        ),
      ),
    );
  }

  void _openNikSheet() {
    final sheetFormKey = GlobalKey<FormState>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _editSheet(
          ctx: ctx,
          title: t(context, 'nik'),
          formKey: sheetFormKey,
          child: TextFormField(
            controller: _nikCtr,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
            ],
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return widget.requireCompleteProfile
                    ? t(context, 'nikRequired')
                    : null;
              }
              if (v.trim().length != 16) return t(context, 'nikLengthError');
              return null;
            },
            decoration: _sheetInputDecoration(t(context, 'nikHint')),
          ),
          onSave: () {
            if (sheetFormKey.currentState!.validate()) {
              _save();
              Navigator.of(ctx).pop();
            }
          },
        ),
      ),
    );
  }

  void _openAddressSheet() {
    final sheetFormKey = GlobalKey<FormState>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _editSheet(
          ctx: ctx,
          title: t(context, 'address'),
          formKey: sheetFormKey,
          child: TextFormField(
            controller: _addressCtr,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            validator: (v) => widget.requireCompleteProfile &&
                    (v == null || v.trim().isEmpty)
                ? t(context, 'addressRequired')
                : null,
            decoration: _sheetInputDecoration(t(context, 'addressHint')),
          ),
          onSave: () {
            if (sheetFormKey.currentState!.validate()) {
              _save();
              Navigator.of(ctx).pop();
            }
          },
        ),
      ),
    );
  }

  void _openGenderSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String? localGender = _gender;
        return StatefulBuilder(
          builder: (ctx2, setSheet) => _editSheet(
            ctx: ctx2,
            title: t(context, 'gender'),
            formKey: null,
            child: Row(
              children: _genders.map((g) {
                final selected = localGender == g;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setSheet(() => localGender = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(
                        right: g == _genders.last ? 0 : 8,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? _c700
                            : const Color(0xFFF5F8F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          g == t(context, 'genderMaleValue')
                              ? t(context, 'male')
                              : t(context, 'female'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: selected ? Colors.white : _ink2,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            onSave: () {
              setState(() {
                _gender = localGender;
              });
              _save();
              Navigator.of(ctx).pop();
            },
          ),
        );
      },
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
                    child: Column(
                      children: [
                        // ── Photo card ─────────────────────────────────────
                        _buildPhotoCard(),
                        const SizedBox(height: 16),

                        // ── Info list card ─────────────────────────────────
                        _buildCard(children: [
                          // 1. Nama Lengkap
                          _infoRow(
                            icon: Icons.person_outline_rounded,
                            label: t(context, 'fullName'),
                            value: _maskName(_nameCtr.text),
                            onTap: _openNameSheet,
                          ),
                          _divider(),

                          // 2. NIK
                          _infoRow(
                            icon: Icons.badge_outlined,
                            label: t(context, 'nik'),
                            value: _nikCtr.text.trim().isEmpty
                                ? '-'
                                : '•' * 16,
                            onTap: _openNikSheet,
                          ),
                          _divider(),

                          // 3. Jenis Kelamin
                          _infoRow(
                            icon: Icons.wc_rounded,
                            label: t(context, 'gender'),
                            value: _gender ?? '-',
                            onTap: _openGenderSheet,
                          ),
                          _divider(),

                          // 4. Tanggal Lahir
                          _infoRow(
                            icon: Icons.calendar_month_rounded,
                            label: t(context, 'birthDate'),
                            value: _maskDate(_birthDate),
                            onTap: _pickDate,
                          ),
                          _divider(),

                          // 5. Alamat
                          _infoRow(
                            icon: Icons.location_on_outlined,
                            label: t(context, 'address'),
                            value: _previewAddress(_addressCtr.text),
                            onTap: _openAddressSheet,
                          ),
                          _divider(),

                          // 6. Nomor Telepon — tappable → ubah nomor
                          _infoRow(
                            icon: Icons.phone_iphone_rounded,
                            label: t(context, 'phoneNumber'),
                            value: _displayPhone,
                            showChevron: true,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChangeContactScreen(
                                    mode: ChangeContactMode.phone,
                                    currentValue: _phone,
                                  ),
                                ),
                              );
                              if (mounted) _loadProfile();
                            },
                            trailing: IconButton(
                              icon: Icon(
                                _hidePhone
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: _ink3,
                              ),
                              onPressed: () =>
                                  setState(() => _hidePhone = !_hidePhone),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                          _divider(),

                          // 7. Email — tappable → ubah email
                          _infoRow(
                            icon: Icons.email_outlined,
                            label: t(context, 'email'),
                            value: _maskEmail(_email),
                            showChevron: true,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChangeContactScreen(
                                    mode: ChangeContactMode.email,
                                    currentValue: _email,
                                  ),
                                ),
                              );
                              if (mounted) _loadProfile();
                            },
                          ),
                          _divider(),

                          // 8. ID Pasien — READ-ONLY, copy icon
                          _infoRow(
                            icon: Icons.badge_outlined,
                            label: t(context, 'patientIdLabel'),
                            value: _medicalCode,
                            showChevron: false,
                            trailing: _medicalCode == '-'
                                ? null
                                : IconButton(
                                    icon: const Icon(
                                      Icons.copy_outlined,
                                      size: 20,
                                      color: _ink3,
                                    ),
                                    onPressed: _copyMedicalCode,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                          ),
                        ]),

                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: CircularProgressIndicator(
                              color: _c700,
                              strokeWidth: 2,
                            ),
                          ),
                      ],
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
      onPressed: _handleBack,
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

  // ── photo card ────────────────────────────────────────────────────────────
  Widget _buildPhotoCard() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: _ink.withValues(alpha: 0.04),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    margin: EdgeInsets.zero,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    child: Row(
      children: [
        // Avatar with upload overlay
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: _c100,
              backgroundImage: _profileImageUrl != null
                  ? NetworkImage(_profileImageUrl!)
                  : null,
              child: _profileImageUrl == null
                  ? const Icon(Icons.person_rounded, color: _c500, size: 48)
                  : null,
            ),
            if (_isUploading)
              const CircularProgressIndicator(
                color: _c700,
                strokeWidth: 2.5,
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Upload button + hint
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickAndUploadPhoto,
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('Unggah Foto'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _c700,
                  side: const BorderSide(color: _c700, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'PNG/JPG maksimal 2MB',
                style: TextStyle(fontSize: 11, color: _ink3),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── info row ──────────────────────────────────────────────────────────────
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    bool showChevron = true,
    Widget? trailing,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Leading teal icon square
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _c100,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: _c700),
          ),
          const SizedBox(width: 14),
          // Label + value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _ink3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          // Trailing: custom widget, chevron, or nothing
          if (trailing != null)
            trailing
          else if (onTap != null && showChevron)
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: _ink3,
            ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }

  // ── card + divider ────────────────────────────────────────────────────────
  Widget _buildCard({required List<Widget> children}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
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

  Widget _divider() => const Divider(
    height: 1,
    thickness: 1,
    color: Color(0xFFF0F4F4),
    indent: 16,
  );
}
