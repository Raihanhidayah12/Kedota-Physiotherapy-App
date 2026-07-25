import 'package:flutter/material.dart';
import '../../widgets/custom_error_screen.dart';
import '../../l10n/app_language.dart';

class NoInternetScreen extends StatefulWidget {
  const NoInternetScreen({super.key});

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkNetwork();
  }

  void _checkNetwork() {
    setState(() {
      _isLoading = true;
    });
    
    // Simulating network check for 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00A79D),
          ),
        ),
      );
    }

    return CustomErrorScreen(
      imagePath: 'assets/image/Poor Network Connection.png',
      title: t(context, 'noInternetTitle'),
      subtitle: t(context, 'noInternetSubtitle'),
      isError: false,
      customAction: IconButton(
        onPressed: _checkNetwork,
        icon: const Icon(Icons.refresh_rounded),
        color: const Color(0xFF00A79D),
        iconSize: 32,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF00A79D).withValues(alpha: 0.1),
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}
