import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import 'rate_limit_screen.dart';
import '../auth/otp_verification_screen.dart';

class OtpRateLimitScreen extends StatelessWidget {
  final String phoneNumber;

  const OtpRateLimitScreen({super.key, required this.phoneNumber});

  @override
  Widget build(BuildContext context) => RateLimitScreen(
    title: t(context, 'otpLimitTitle'),
    subtitleBuilder: (ctx, seconds) =>
        t(ctx, 'otpLimitSubtitle').replaceAll('{seconds}', seconds.toString()),
    onContinue: () => Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(phoneNumber: phoneNumber),
      ),
    ),
  );
}
