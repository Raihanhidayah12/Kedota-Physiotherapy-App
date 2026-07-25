import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/custom_error_screen.dart';
import '../../widgets/language_button.dart';
import '../../l10n/app_language.dart';
import '../auth/pin_verification_screen.dart';

class PinRateLimitScreen extends StatefulWidget {
  final String phoneNumber;

  const PinRateLimitScreen({super.key, required this.phoneNumber});

  @override
  State<PinRateLimitScreen> createState() => _PinRateLimitScreenState();
}

class _PinRateLimitScreenState extends State<PinRateLimitScreen> {
  int _secondsRemaining = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PinVerificationScreen(phoneNumber: widget.phoneNumber),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomErrorScreen(
      imagePath: 'assets/image/LImit.png',
      title: t(context, 'pinLimitTitle'),
      subtitle: t(context, 'pinLimitSubtitle'),
      isError: true,
      topAction: const LanguageButton(),
      customAction: SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFCDD2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFFC62828),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                t(context, 'wait30Seconds').replaceAll(
                  '{seconds}',
                  _secondsRemaining.toString(),
                ),
                style: const TextStyle(
                  color: Color(0xFFC62828),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
