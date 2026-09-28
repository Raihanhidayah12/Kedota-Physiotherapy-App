import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import 'rate_limit_screen.dart';
import '../auth/pin_verification_screen.dart';

class PinRateLimitScreen extends StatelessWidget {
  final String phoneNumber;

  const PinRateLimitScreen({super.key, required this.phoneNumber});

  @override
  Widget build(BuildContext context) => RateLimitScreen(
    title: t(context, 'pinLimitTitle'),
    subtitleBuilder: (ctx, seconds) =>
        t(ctx, 'pinLimitSubtitle').replaceAll('{seconds}', seconds.toString()),
    onContinue: () => Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PinVerificationScreen(phoneNumber: phoneNumber),
      ),
    ),
  );
}
