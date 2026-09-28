import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_language.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../utils/app_snackbar.dart';
import 'history_screen.dart';
import 'main_screen.dart';

const _teal = Color(0xFF00A79D);
const _tealDark = Color(0xFF007F78);
const _background = Color(0xFFF5F8F8);
const _ink = Color(0xFF172B2D);
const _muted = Color(0xFF7C8C8E);

class SettlePaymentScreen extends StatefulWidget {
  final AppointmentItem appointment;

  const SettlePaymentScreen({super.key, required this.appointment});

  @override
  State<SettlePaymentScreen> createState() => _SettlePaymentScreenState();
}

class _SettlePaymentScreenState extends State<SettlePaymentScreen>
    with SingleTickerProviderStateMixin {
  final _service = SupabaseAuthService();
  String _method = 'qris';
  bool _saving = false;
  bool _showInstructions = false;
  bool _paymentCompleted = false;
  int _successCountdown = 3;
  Timer? _successTimer;
  late final AnimationController _successAnimationController;
  late final Animation<double> _successScale;
  late final Animation<double> _successFade;

  // ── Card form controllers ─────────────────────────────────────────────────
  final _cardNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();

  // ── Payment method groups ─────────────────────────────────────────────────
  static const _qrisEwalletValues = ['qris', 'ovo', 'gopay', 'shopeepay'];
  static const _bankValues = ['bca', 'bni', 'bri', 'permata', 'mandiri'];

  // Logo aset per metode
  static const _logos = <String, String>{
    'qris': 'assets/payment/qris.png',
    'ovo': 'assets/payment/ovo.png',
    'gopay': 'assets/payment/gopay.png',
    'shopeepay': 'assets/payment/Spay.png',
    'bca': 'assets/payment/bca.png',
    'bni': 'assets/payment/bni.png',
    'bri': 'assets/payment/bri.png',
    'permata': 'assets/payment/permata.png',
    'mandiri': 'assets/payment/mandiri.png',
  };

  // Logo kartu untuk tile Kartu Kredit/Debit
  static const _cardLogos = [
    'assets/payment/visa logo.png',
    'assets/payment/mastercard logo.png',
    'assets/payment/jcb logo.png',
    'assets/payment/American_Express_Logo logo.png',
  ];

  @override
  void initState() {
    super.initState();
    _successAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _successScale = CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.elasticOut,
    );
    _successFade = CurvedAnimation(
      parent: _successAnimationController,
      curve: const Interval(0, 0.42, curve: Curves.easeOut),
    );
  }

  String _formatRupiah(int amount) {
    final digits = amount.toString();
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      final start = (end - 3).clamp(0, end);
      groups.insert(0, digits.substring(start, end));
    }
    return '${t(context, 'currencyPrefix')} ${groups.join('.')}';
  }

  Future<void> _settle() async {
    final successTitle = t(context, 'paymentSuccessTitle');
    final successBody = t(context, 'paymentSuccessDesc')
        .replaceFirst('{date}', widget.appointment.date)
        .replaceFirst(
          '{clinic}',
          widget.appointment.clinicName.isEmpty
              ? widget.appointment.serviceType
              : widget.appointment.clinicName,
        );
    setState(() => _saving = true);
    try {
      await _service.client.rpc(
        'settle_appointment_payment',
        params: {
          'p_appointment_id': widget.appointment.id,
          'p_payment_method': _method,
        },
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        final events = prefs.getStringList('payment_notifications') ?? [];
        events.add(
          jsonEncode({
            'appointment_id': widget.appointment.id,
            'booker_id': _service.client.auth.currentUser?.id,
            'service_type': widget.appointment.serviceType,
            'clinic_name': widget.appointment.clinicName,
            'appointment_date': widget.appointment.date,
            'appointment_time': widget.appointment.time,
            'created_at': DateTime.now().toIso8601String(),
          }),
        );
        await prefs.setStringList(
          'payment_notifications',
          events.length > 20 ? events.sublist(events.length - 20) : events,
        );
      } catch (notificationError) {
        debugPrint(
          'Payment in-app notification save failed: $notificationError',
        );
      }
      try {
        await NotificationService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
          title: successTitle,
          body: successBody,
          payload: 'appointment:${widget.appointment.id}',
        );
      } catch (notificationError) {
        debugPrint('Payment success notification failed: $notificationError');
      }
      if (mounted) {
        setState(() => _paymentCompleted = true);
        _startSuccessRedirect();
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          t(context, 'paymentErrorGeneric'),
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    _successAnimationController.dispose();
    _cardNameController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: _paymentCompleted
          ? null
          : AppBar(
              backgroundColor: _background,
              foregroundColor: _ink,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              centerTitle: true,
              title: Text(
                t(context, 'settlePayment'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
      body: _paymentCompleted
          ? SafeArea(child: _successView())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _amountCard(),
                const SizedBox(height: 20),
                Text(
                  t(context, 'choosePaymentMethod'),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                // ── QRIS & E-Wallet ─────────────────────────────────────
                _sectionHeader(t(context, 'paymentGroupQrisEwallet')),
                const SizedBox(height: 8),
                for (final v in _qrisEwalletValues) ...[
                  _methodTileLogo(v, _methodLabel(context, v)),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                // ── Transfer Bank ────────────────────────────────────────
                _sectionHeader(t(context, 'paymentGroupBank')),
                const SizedBox(height: 8),
                for (final v in _bankValues) ...[
                  _methodTileLogo(v, _methodLabel(context, v)),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                // ── Kartu Kredit / Debit ─────────────────────────────────
                _sectionHeader(t(context, 'paymentGroupCard')),
                const SizedBox(height: 8),
                _methodTileCard(),
                const SizedBox(height: 8),
                // ── Tunai ────────────────────────────────────────────────
                _methodTileLogo('cash', t(context, 'cashPayment')),
                if (_showInstructions) ...[
                  const SizedBox(height: 10),
                  _paymentInstructions(),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving
                        ? null
                        : () {
                            if (!_showInstructions) {
                              setState(() => _showInstructions = true);
                            } else {
                              _settle();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _teal.withValues(alpha: 0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            t(
                              context,
                              _showInstructions
                                  ? 'confirmPayment'
                                  : 'reservationPayNow',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _successView() {
    final message = t(context, 'paymentSuccessDesc')
        .replaceFirst('{date}', widget.appointment.date)
        .replaceFirst(
          '{clinic}',
          widget.appointment.clinicName.isEmpty
              ? widget.appointment.serviceType
              : widget.appointment.clinicName,
        );
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _successFade,
                    child: ScaleTransition(
                      scale: _successScale,
                      child: Container(
                        width: 116,
                        height: 116,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE0F5EE),
                          border: Border.all(
                            color: const Color(0xFFC7EBDD),
                            width: 8,
                          ),
                        ),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF41B883),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 58,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t(context, 'paymentSuccessTitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _teal,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Text(
            t(
              context,
              'paymentReturningHome',
            ).replaceFirst('{seconds}', '$_successCountdown'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ),
      ],
    );
  }

  void _startSuccessRedirect() {
    _successTimer?.cancel();
    _successCountdown = 3;
    _successAnimationController
      ..reset()
      ..forward();
    _successTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_successCountdown <= 1) {
        timer.cancel();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 1)),
          (route) => false,
        );
        return;
      }
      setState(() => _successCountdown--);
    });
  }

  Widget _amountCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFFFD5D2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(context, 'remainingPayment'),
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                _formatRupiah(widget.appointment.amountDue),
                style: const TextStyle(
                  color: _tealDark,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Material(
              color: const Color(0xFFF5F8F8),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => _copyValue(
                  widget.appointment.amountDue.toString(),
                  successMessageKey: 'reservationAmountCopied',
                ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t(context, 'reservationCopyShort'),
                        style: const TextStyle(
                          color: _teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.copy_rounded, size: 16, color: _teal),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.appointment.serviceType} • ${widget.appointment.therapistName}',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    ),
  );

  String _methodLabel(BuildContext context, String value) => switch (value) {
    'qris' => t(context, 'reservationPaymentQris'),
    'ovo' => 'OVO',
    'gopay' => 'GoPay',
    'shopeepay' => 'ShopeePay',
    'bca' => 'BCA',
    'bni' => 'BNI',
    'bri' => 'BRI',
    'permata' => 'Permata',
    'mandiri' => 'Mandiri',
    'cash' => t(context, 'cashPayment'),
    _ => value.toUpperCase(),
  };

  Widget _sectionHeader(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _muted,
        letterSpacing: 0.3,
      ),
    ),
  );

  Widget _methodTileLogo(String value, String label) {
    final selected = _method == value;
    final logoPath = _logos[value];
    return InkWell(
      onTap: () => setState(() {
        _method = value;
        _showInstructions = false;
      }),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDDF5F2) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _teal : const Color(0xFFE8EEEE),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Logo
            SizedBox(
              width: 48,
              height: 28,
              child: logoPath != null
                  ? Image.asset(
                      logoPath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, err, _) => Icon(
                        Icons.payments_outlined,
                        color: selected ? _tealDark : _muted,
                        size: 24,
                      ),
                    )
                  : Icon(
                      Icons.payments_outlined,
                      color: selected ? _tealDark : _muted,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? _tealDark : _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Amount
            Text(
              _formatRupiah(widget.appointment.amountDue),
              style: TextStyle(
                color: selected ? _tealDark : _ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? _teal : const Color(0xFFBFCFCF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodTileCard() {
    final selected = _method == 'card';
    return InkWell(
      onTap: () => setState(() {
        _method = 'card';
        _showInstructions = false;
      }),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDDF5F2) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _teal : const Color(0xFFE8EEEE),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Logo kartu berjajar
            Row(
              children: _cardLogos.map((logo) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Image.asset(
                  logo,
                  width: 32,
                  height: 22,
                  fit: BoxFit.contain,
                  errorBuilder: (context, err, _) => const SizedBox(width: 32),
                ),
              )).toList(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t(context, 'reservationPaymentCardDebit'),
                style: TextStyle(
                  color: selected ? _tealDark : _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              _formatRupiah(widget.appointment.amountDue),
              style: TextStyle(
                color: selected ? _tealDark : _ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? _teal : const Color(0xFFBFCFCF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentInstructions() {
    final content = switch (_method) {
      'qris' => _qrisInstructions(),
      'bca' || 'bni' || 'bri' || 'permata' || 'mandiri' => _bankInstructions(),
      'card' => _cardInstructions(),
      _ => _walletInstructions(),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7E9E7)),
      ),
      child: content,
    );
  }

  /// Header dengan logo asli metode yang dipilih
  Widget _selectedMethodHeader() {
    final logoPath = _logos[_method];
    final label = switch (_method) {
      'qris' => t(context, 'reservationPaymentQris'),
      'ovo' => 'OVO',
      'gopay' => 'GoPay',
      'shopeepay' => 'ShopeePay',
      'bca' => 'BCA',
      'bni' => 'BNI',
      'bri' => 'BRI',
      'permata' => 'Permata',
      'mandiri' => 'Mandiri',
      _ => _method.toUpperCase(),
    };
    return Row(
      children: [
        if (logoPath != null)
          Image.asset(
            logoPath,
            width: 52,
            height: 30,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, _) => const Icon(
              Icons.payments_outlined,
              color: _teal,
              size: 26,
            ),
          )
        else if (_method == 'card')
          Row(
            children: _cardLogos.take(3).map((logo) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Image.asset(
                logo,
                width: 28,
                height: 20,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, _) => const SizedBox(width: 28),
              ),
            )).toList(),
          )
        else
          const Icon(Icons.payments_outlined, color: _teal, size: 26),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ],
    );
  }

  Widget _instructionSteps(List<String> steps) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var index = 0; index < steps.length; index++) ...[
        if (index > 0) const SizedBox(height: 8),
        Text(
          '${index + 1}. ${steps[index]}',
          style: const TextStyle(color: _muted, fontSize: 11, height: 1.4),
        ),
      ],
    ],
  );

  Widget _qrisInstructions() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _selectedMethodHeader(),
      const SizedBox(height: 14),
      Center(
        child: Container(
          width: 170,
          height: 170,
          color: Colors.white,
          padding: const EdgeInsets.all(10),
          child: const Icon(
            Icons.qr_code_2_rounded,
            size: 145,
            color: Colors.black,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        '${t(context, 'reservationTotal')}: ${_formatRupiah(widget.appointment.amountDue)}',
        style: const TextStyle(color: _tealDark, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      _instructionSteps([
        t(context, 'reservationQrisStep1'),
        t(context, 'reservationQrisStep2'),
        t(context, 'reservationQrisStep3'),
      ]),
    ],
  );

  Widget _bankInstructions() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _selectedMethodHeader(),
      const SizedBox(height: 14),
      Text(
        t(context, 'reservationVirtualAccount'),
        style: const TextStyle(color: _muted, fontSize: 11),
      ),
      const SizedBox(height: 5),
      Row(
        children: [
          const Expanded(
            child: Text(
              '8808 1234 5678 9012',
              style: TextStyle(
                color: _teal,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _copyValue('8808123456789012'),
            icon: const Icon(Icons.copy_rounded, color: _teal),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _instructionSteps([
        t(context, 'reservationBankStep1'),
        t(context, 'reservationBankStep2'),
        t(context, 'reservationBankStep3'),
      ]),
    ],
  );

  Widget _walletInstructions() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _selectedMethodHeader(),
      const SizedBox(height: 14),
      Text(
        '${t(context, 'reservationTotal')}: ${_formatRupiah(widget.appointment.amountDue)}',
        style: const TextStyle(color: _tealDark, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      _instructionSteps([
        t(context, 'reservationWalletStep1'),
        t(context, 'reservationWalletStep2'),
        t(context, 'reservationWalletStep3'),
      ]),
    ],
  );

  Widget _cardInstructions() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _selectedMethodHeader(),
      const SizedBox(height: 14),
      Text(
        '${t(context, 'reservationTotal')}: ${_formatRupiah(widget.appointment.amountDue)}',
        style: const TextStyle(
          color: _tealDark,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
      const SizedBox(height: 16),
      // Nama pemilik kartu
      _cardField(
        controller: _cardNameController,
        label: t(context, 'reservationCardholder'),
        hint: 'NAMA SESUAI KARTU',
        icon: Icons.person_outline_rounded,
        keyboardType: TextInputType.name,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
        ],
      ),
      const SizedBox(height: 10),
      // Nomor kartu
      _cardField(
        controller: _cardNumberController,
        label: t(context, 'reservationCardNumber'),
        hint: '1234  5678  9012  3456',
        icon: Icons.credit_card_rounded,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(16),
          _CardNumberFormatter(),
        ],
      ),
      const SizedBox(height: 10),
      // Expiry + CVV side by side
      Row(
        children: [
          Expanded(
            child: _cardField(
              controller: _cardExpiryController,
              label: t(context, 'reservationCardExpiry'),
              hint: 'MM/YY',
              icon: Icons.calendar_today_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
                _ExpiryFormatter(),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _cardField(
              controller: _cardCvvController,
              label: t(context, 'reservationCardCvv'),
              hint: '•••',
              icon: Icons.lock_outline_rounded,
              keyboardType: TextInputType.number,
              obscureText: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
            ),
          ),
        ],
      ),
    ],
  );

  Widget _cardField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    List<TextInputFormatter>? inputFormatters,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _muted,
        ),
      ),
      const SizedBox(height: 5),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _muted, fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: _muted),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDE4E3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDE4E3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _teal, width: 1.4),
          ),
        ),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ],
  );

  Future<void> _copyValue(
    String value, {
    String successMessageKey = 'reservationAccountCopied',
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    showAppSnackBar(
      context,
      t(context, successMessageKey),
      type: AppSnackBarType.success,
    );
  }
}

/// Format nomor kartu: 1234 5678 9012 3456
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('  ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Format expiry: MM/YY
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.length <= 2) {
      return newValue.copyWith(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }
    final formatted = '${digits.substring(0, 2)}/${digits.substring(2)}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
