import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../widgets/error_state_screen.dart';

class NoInternetScreen extends StatefulWidget {
  const NoInternetScreen({super.key, required this.onRetry});

  final Future<bool> Function() onRetry;

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> {
  bool _isChecking = false;

  Future<void> _checkNetwork() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    await widget.onRetry();
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    return ErrorStateScreen(
      imagePath: 'assets/image/Poor Network Connection.png',
      title: t(context, 'noInternetTitle'),
      subtitle: t(context, 'noInternetSubtitle'),
      isError: false,
      imageHeight: 180,
      buttonText: t(context, 'retry'),
      onPressed: _checkNetwork,
      isLoading: _isChecking,
    );
  }
}
