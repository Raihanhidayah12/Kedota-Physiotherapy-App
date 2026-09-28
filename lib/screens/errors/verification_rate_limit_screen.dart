import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import 'rate_limit_screen.dart';

class VerificationRateLimitScreen extends StatelessWidget {
  const VerificationRateLimitScreen({super.key});

  @override
  Widget build(BuildContext context) => RateLimitScreen(
    title: t(context, 'verificationLimitTitle'),
    subtitleBuilder: (ctx, seconds) => t(
      ctx,
      'verificationLimitSubtitle',
    ).replaceAll('{seconds}', seconds.toString()),
    onContinue: () => Navigator.of(context).pop(),
  );
}
