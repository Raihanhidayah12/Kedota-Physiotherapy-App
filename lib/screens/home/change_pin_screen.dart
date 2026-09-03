import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/custom_bottom_sheet.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _c900 = Color(0xFF004D47);
const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _c100 = Color(0xFFD4F5F3);
const _bg   = Color(0xFFF0F7F7);
const _ink  = Color(0xFF0E2C2F);
const _ink3 = Color(0xFF8AA8AC);

class ChangePinScreen extends StatefulWidget {
  /// Phone nomor user yang sedang login (diambil dari profil).
  final String phoneNumber;

  const ChangePinScreen({super.key, required this.phoneNumber});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen>
    with SingleTickerProviderStateMixin {

  // Step: 0 = verifikasi PIN lama, 1 = buat PIN baru, 2 = konfirmasi PIN baru
  int _step = 0;

  String _oldPin     = '';
  String _newPin     = '';
  String _confirmPin = '';

  bool _isLoading    = false;
  bool _isPinError   = false;

  // ── Rate limiting PIN lama ─────────────────────────────────────────────────
  static const _maxAttempts    = 3;
  static const _cooldownSecs   = 30;
  int   _failedAttempts        = 0;
  bool  _isLocked              = false;
  int   _cooldownRemaining     = 0;
  Timer? _cooldownTimer;

  late final AnimationController _enterCtrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade  = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── step helpers ──────────────────────────────────────────────────────────
  String get _currentPin => switch (_step) {
    0 => _oldPin,
    1 => _newPin,
    _ => _confirmPin,
  };

  String get _stepTitle => switch (_step) {
    0 => t(context, 'enterPin'),
    1 => t(context, 'createNewPin'),
    _ => t(context, 'confirmNewPin'),
  };

  String get _stepDesc => switch (_step) {
    0 => t(context, 'enterPinDesc'),
    1 => t(context, 'createNewPinDesc'),
    _ => t(context, 'confirmPinDesc'),
  };

  // ── numpad handler ────────────────────────────────────────────────────────
  void _onKey(String val) {
    if (_isLoading || _isLocked) return;
    HapticFeedback.lightImpact();

    setState(() {
      _isPinError = false;
      if (val == 'back') {
        switch (_step) {
          case 0: if (_oldPin.isNotEmpty)     _oldPin     = _oldPin.substring(0, _oldPin.length - 1);
          case 1: if (_newPin.isNotEmpty)     _newPin     = _newPin.substring(0, _newPin.length - 1);
          case _: if (_confirmPin.isNotEmpty) _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
        return;
      }

      switch (_step) {
        case 0:
          if (_oldPin.length < 6) {
            _oldPin += val;
            if (_oldPin.length == 6) _verifyOldPin();
          }
        case 1:
          if (_newPin.length < 6) {
            _newPin += val;
            if (_newPin.length == 6) {
              Future.delayed(const Duration(milliseconds: 180), () {
                if (mounted) setState(() => _step = 2);
              });
            }
          }
        case _:
          if (_confirmPin.length < 6) {
            _confirmPin += val;
            if (_confirmPin.length == 6) _saveNewPin();
          }
      }
    });
  }

  // ── verify old PIN ────────────────────────────────────────────────────────
  Future<void> _verifyOldPin() async {
    setState(() => _isLoading = true);
    try {
      final svc   = SupabaseAuthService();
      final valid = await svc.verifyPin(
          phone: widget.phoneNumber, pin: _oldPin);

      if (!mounted) return;
      if (valid) {
        setState(() {
          _isLoading      = false;
          _failedAttempts = 0;
          _step           = 1;
        });
      } else {
        _failedAttempts++;
        if (_failedAttempts >= _maxAttempts) {
          _startCooldown();
        } else {
          final sisa = _maxAttempts - _failedAttempts;
          _showError(msg: t(context, 'wrongPin')
              .replaceAll('{attempts}', '$sisa'));
        }
      }
    } catch (_) {
      if (mounted) _showError();
    }
  }

  // ── cooldown ──────────────────────────────────────────────────────────────
  void _startCooldown() {
    setState(() {
      _isLoading        = false;
      _isPinError       = true;
      _isLocked         = true;
      _oldPin           = '';
      _cooldownRemaining = _cooldownSecs;
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _cooldownRemaining--);
      if (_cooldownRemaining <= 0) {
        timer.cancel();
        setState(() {
          _isLocked       = false;
          _isPinError     = false;
          _failedAttempts = 0;
        });
      }
    });
  }

  // ── save new PIN ──────────────────────────────────────────────────────────
  Future<void> _saveNewPin() async {
    if (_newPin != _confirmPin) {
      _showError(msg: t(context, 'confirmPinMismatchError'));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final svc     = SupabaseAuthService();
      final success = await svc.updateUserPin(
        phone: widget.phoneNumber,
        newPin: _newPin,
        allowSamePin: false,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        CustomBottomSheet.show(
          context,
          type: BottomSheetType.success,
          title: t(context, 'pinUpdatedSuccessTitle'),
          subtitle: t(context, 'pinUpdatedSuccessDesc'),
          singleButtonText: t(context, 'closeBtn'),
          onSinglePressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        );
      } else {
        _showError(msg: t(context, 'resetPinFailed'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg == 'sameAsOldPin') {
        _showError(msg: t(context, 'sameAsOldPinError'));
      } else {
        _showError(msg: t(context, 'resetPinFailed'));
      }
    }
  }

  void _showError({String? msg}) {
    setState(() {
      _isLoading  = false;
      _isPinError = true;
      switch (_step) {
        case 0: _oldPin     = '';
        case 1: _newPin     = '';
        case _: _confirmPin = '';
      }
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isPinError = false);
    });
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFD94F45),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildStepBadge() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final done   = i < _step;
            final active = i == _step;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 32 : 12,
              height: 8,
              decoration: BoxDecoration(
                color: done || active ? _c700 : _c100,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      );

  // ── body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Center(child: _buildStepBadge()),
                    const SizedBox(height: 40),

                    // Icon
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) => 
                          ScaleTransition(scale: animation, child: child),
                      child: Container(
                        key: ValueKey(_step),
                        width: 76, height: 76,
                        decoration: BoxDecoration(
                          color: _c100,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _c500.withValues(alpha: 0.2), 
                              blurRadius: 24, 
                              offset: const Offset(0, 8)
                            )
                          ],
                        ),
                        child: Icon(
                          _step == 0
                              ? Icons.lock_outline_rounded
                              : _step == 1
                                  ? Icons.lock_open_rounded
                                  : Icons.check_circle_outline_rounded,
                          size: 36, color: _c700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Title
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        key: ValueKey('title$_step'),
                        _stepTitle,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800, color: _ink),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Desc
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          key: ValueKey('desc$_step'),
                          _stepDesc,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14, color: _ink3, height: 1.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // PIN dots
                    _buildPinDots(),
                    const SizedBox(height: 12),

                    // Error / lock banner
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isLocked
                          ? _buildLockBanner()
                          : _isPinError
                              ? Padding(
                                  key: const ValueKey('err'),
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFECEB),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _step == 2
                                          ? t(context, 'pinMismatch')
                                          : t(context, 'wrongPin').replaceAll(
                                              '{attempts}',
                                              '${_maxAttempts - _failedAttempts}'),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFD94F45)),
                                    ),
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('noerr'), height: 38),
                    ),
                  ],
                ),

                // Numpad at bottom
                Padding(
                  padding: const EdgeInsets.only(bottom: 40, top: 20),
                  child: _buildNumpad(),
                ),
              ],
            ),
          ),
        ),
      );

  // ── lock banner ───────────────────────────────────────────────────────────
  Widget _buildLockBanner() => Container(
        key: const ValueKey('locked'),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFCCCA), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFD94F45).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)
              ),
              child: const Icon(Icons.lock_clock_rounded,
                  color: Color(0xFFD94F45), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'pinLimitTitle'),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD94F45)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t(context, 'wait30Seconds')
                        .replaceAll('{seconds}', '$_cooldownRemaining'),
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFFD94F45), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── PIN dots ──────────────────────────────────────────────────────────────
  Widget _buildPinDots() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (i) {
          final filled = i < _currentPin.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 16, height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isPinError
                  ? (filled
                      ? const Color(0xFFD94F45)
                      : const Color(0xFFFFE5E5))
                  : (filled ? _c500 : Colors.white),
              border: Border.all(
                color: _isPinError
                    ? const Color(0xFFD94F45)
                    : filled ? _c500 : const Color(0xFFCDD8DA),
                width: 2,
              ),
              boxShadow: filled && !_isPinError
                  ? [BoxShadow(color: _c500.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))]
                  : null,
            ),
          );
        }),
      );

  // ── numpad ────────────────────────────────────────────────────────────────
  Widget _buildNumpad() => LayoutBuilder(
        builder: (context, constraints) {
          final btnSz = (constraints.maxWidth * 0.22).clamp(60.0, 76.0);
          final gap   = (constraints.maxWidth * 0.04).clamp(12.0, 24.0);
          return Column(
            children: [
              _numRow(['1', '2', '3'], btnSz, gap),
              SizedBox(height: gap),
              _numRow(['4', '5', '6'], btnSz, gap),
              SizedBox(height: gap),
              _numRow(['7', '8', '9'], btnSz, gap),
              SizedBox(height: gap),
              _numRow(['', '0', 'back'], btnSz, gap),
            ],
          );
        },
      );

  Widget _numRow(List<String> keys, double sz, double gap) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((k) => _buildBtn(k, sz)).toList(),
      );

  Widget _buildBtn(String val, double sz) {
    if (val.isEmpty) return SizedBox(width: sz, height: sz);

    if (val == 'back') {
      return GestureDetector(
        onTap: () => _onKey('back'),
        child: Container(
          width: sz, height: sz,
          decoration: const BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(Icons.backspace_rounded,
                color: _c700, size: sz * 0.4),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _onKey(val),
      child: Container(
        width: sz, height: sz,
        decoration: BoxDecoration(
          color: _isLocked ? _bg : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _isLocked ? Colors.transparent : const Color(0xFFF0F4F4), width: 1.5),
          boxShadow: _isLocked ? null : [
            BoxShadow(
              color: _ink.withValues(alpha: 0.05), 
              blurRadius: 16, 
              offset: const Offset(0, 8)
            )
          ],
        ),
        child: Center(
          child: Text(val,
              style: TextStyle(
                  fontSize: sz * 0.36,
                  fontWeight: FontWeight.w600,
                  color: _isLocked ? _ink3 : _ink)),
        ),
      ),
    );
  }
}
