import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_language.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_auth_service.dart';
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

  List<({String value, String label, IconData icon})> _paymentMethods(
    BuildContext context,
  ) => [
    (
      value: 'qris',
      label: t(context, 'reservationPaymentQris'),
      icon: Icons.qr_code_2_rounded,
    ),
    (value: 'ovo', label: 'OVO', icon: Icons.account_balance_wallet_rounded),
    (
      value: 'gopay',
      label: 'GoPay',
      icon: Icons.account_balance_wallet_rounded,
    ),
    (value: 'shopeepay', label: 'ShopeePay', icon: Icons.shopping_bag_outlined),
    (value: 'bca', label: 'BCA', icon: Icons.account_balance_rounded),
    (value: 'bni', label: 'BNI', icon: Icons.account_balance_rounded),
    (value: 'bri', label: 'BRI', icon: Icons.account_balance_rounded),
    (value: 'permata', label: 'Permata', icon: Icons.account_balance_rounded),
    (value: 'mandiri', label: 'Mandiri', icon: Icons.account_balance_rounded),
    (
      value: 'card',
      label: t(context, 'reservationPaymentCardDebit'),
      icon: Icons.credit_card_rounded,
    ),
    (
      value: 'cash',
      label: t(context, 'cashPayment'),
      icon: Icons.payments_outlined,
    ),
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
    return 'Rp ${groups.join('.')}';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    _successAnimationController.dispose();
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
                for (final method in _paymentMethods(context)) ...[
                  _methodTile(method.value, method.label, method.icon),
                  const SizedBox(height: 10),
                ],
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
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 2)),
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
        Text(
          _formatRupiah(widget.appointment.amountDue),
          style: const TextStyle(
            color: _tealDark,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.appointment.serviceType} • ${widget.appointment.therapistName}',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _methodTile(String value, String label, IconData icon) {
    final selected = _method == value;
    return InkWell(
      onTap: () => setState(() {
        _method = value;
        _showInstructions = false;
      }),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDDF5F2) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _teal : const Color(0xFFE1E9E8),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _tealDark : _muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? _teal : _muted,
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

  Widget _instructionHeader(String title) => Row(
    children: [
      const Icon(Icons.info_outline_rounded, color: _teal),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );

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
      _instructionHeader(t(context, 'reservationPaymentInstructionQris')),
      const SizedBox(height: 12),
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
      _instructionHeader(
        '${t(context, 'reservationPaymentInstructionBank')} (${_method.toUpperCase()})',
      ),
      const SizedBox(height: 12),
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
      _instructionHeader(
        '${t(context, 'reservationPaymentInstructionWallet')} (${_method.toUpperCase()})',
      ),
      const SizedBox(height: 12),
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
      _instructionHeader(t(context, 'reservationPaymentInstructionCard')),
      const SizedBox(height: 12),
      Text(
        '${t(context, 'reservationTotal')}: ${_formatRupiah(widget.appointment.amountDue)}',
        style: const TextStyle(color: _tealDark, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      _instructionSteps([
        t(context, 'reservationCardStep1'),
        t(context, 'reservationCardStep2'),
        t(context, 'reservationCardStep3'),
      ]),
    ],
  );

  Future<void> _copyValue(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'reservationAccountCopied'))),
    );
  }
}
