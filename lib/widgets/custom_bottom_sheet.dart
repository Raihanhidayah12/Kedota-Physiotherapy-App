import 'package:flutter/material.dart';

enum BottomSheetType { success, error, info }

class CustomBottomSheet extends StatelessWidget {
  final BottomSheetType type;
  final String title;
  final String subtitle;
  
  // For two buttons
  final String? primaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;

  // For single button
  final String? singleButtonText;
  final VoidCallback? onSinglePressed;

  const CustomBottomSheet({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    this.primaryButtonText,
    this.onPrimaryPressed,
    this.secondaryButtonText,
    this.onSecondaryPressed,
    this.singleButtonText,
    this.onSinglePressed,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required BottomSheetType type,
    required String title,
    required String subtitle,
    String? primaryButtonText,
    VoidCallback? onPrimaryPressed,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
    String? singleButtonText,
    VoidCallback? onSinglePressed,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: isDismissible,
      builder: (context) => CustomBottomSheet(
        type: type,
        title: title,
        subtitle: subtitle,
        primaryButtonText: primaryButtonText,
        onPrimaryPressed: onPrimaryPressed,
        secondaryButtonText: secondaryButtonText,
        onSecondaryPressed: onSecondaryPressed,
        singleButtonText: singleButtonText,
        onSinglePressed: onSinglePressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isError = type == BottomSheetType.error;
    final isInfo = type == BottomSheetType.info;
    final mainColor = isError
        ? const Color(0xFFC62828)
        : isInfo
            ? const Color(0xFF1565C0)
            : const Color(0xFF00A79D);
    final lightColor = isError
        ? Colors.red.withAlpha(25)
        : isInfo
            ? const Color(0xFF1565C0).withAlpha(25)
            : const Color(0xFF00A79D).withAlpha(25);
    final icon = isError
        ? Icons.sentiment_dissatisfied_rounded
        : isInfo
            ? Icons.info_outline_rounded
            : Icons.check_rounded;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Icon circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lightColor,
                border: Border.all(
                  color: mainColor.withAlpha(51), // 0.2 opacity
                  width: 6,
                ),
              ),
              child: Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: mainColor,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF17324D),
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Buttons
            if (singleButtonText != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSinglePressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00A79D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    singleButtonText!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else if (primaryButtonText != null && secondaryButtonText != null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondaryPressed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF17324D),
                        side: const BorderSide(color: Color(0xFF00A79D), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        secondaryButtonText!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: onPrimaryPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00A79D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        primaryButtonText!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
