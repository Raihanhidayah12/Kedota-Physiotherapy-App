import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../widgets/error_state_screen.dart';

class RateLimitScreen extends StatefulWidget {
  const RateLimitScreen({
    super.key,
    required this.title,
    required this.subtitleBuilder,
    required this.onContinue,
    this.durationSeconds = 30,
  });

  final String title;
  final String Function(BuildContext context, int secondsRemaining)
  subtitleBuilder;
  final VoidCallback onContinue;
  final int durationSeconds;

  @override
  State<RateLimitScreen> createState() => _RateLimitScreenState();
}

class _RateLimitScreenState extends State<RateLimitScreen> {
  late int _secondsRemaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.durationSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _secondsRemaining == 0,
    child: ErrorStateScreen(
      imagePath: 'assets/image/eror.png',
      title: widget.title,
      subtitle: widget.subtitleBuilder(context, _secondsRemaining),
      buttonText: t(context, 'back'),
      actionEnabled: _secondsRemaining == 0,
      onPressed: widget.onContinue,
    ),
  );
}
