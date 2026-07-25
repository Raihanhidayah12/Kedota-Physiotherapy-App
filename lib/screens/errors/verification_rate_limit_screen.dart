import 'package:flutter/material.dart';
import '../../widgets/custom_error_screen.dart';
import '../../l10n/app_language.dart';

class VerificationRateLimitScreen extends StatelessWidget {
  const VerificationRateLimitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomErrorScreen(
      imagePath: 'assets/image/Verification Birthday Limit.png',
      title: t(context, 'verificationLimitTitle'),
      subtitle: t(context, 'verificationLimitSubtitle'),
      isError: true,
      buttonText: t(context, 'back'),
      onButtonPressed: () {
        Navigator.of(context).pop();
      },
    );
  }
}
