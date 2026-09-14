import 'package:flutter/material.dart';

enum AppSnackBarType { success, error, warning, info }

void showAppSnackBar(
  BuildContext context,
  String message, {
  AppSnackBarType type = AppSnackBarType.info,
  IconData? icon,
  Duration duration = const Duration(seconds: 3),
}) {
  final (background, foreground, border, defaultIcon) = switch (type) {
    AppSnackBarType.success => (
      const Color(0xFFE8F7F5),
      const Color(0xFF007F78),
      const Color(0xFFB8E8E3),
      Icons.check_circle_outline_rounded,
    ),
    AppSnackBarType.error => (
      const Color(0xFFFFECEB),
      const Color(0xFFD94F45),
      const Color(0xFFFFD5D2),
      Icons.error_outline_rounded,
    ),
    AppSnackBarType.warning => (
      const Color(0xFFFFF5E3),
      const Color(0xFF7A5800),
      const Color(0xFFFFDFA8),
      Icons.info_outline_rounded,
    ),
    AppSnackBarType.info => (
      const Color(0xFFE8F7F5),
      const Color(0xFF007F78),
      const Color(0xFFB8E8E3),
      Icons.info_outline_rounded,
    ),
  };

  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon ?? defaultIcon, color: foreground, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        backgroundColor: background,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border),
        ),
      ),
    );
}
