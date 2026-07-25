import 'package:flutter/material.dart';

class CustomErrorScreen extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;
  final bool isError;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final Widget? customAction;
  final Widget? topAction;

  const CustomErrorScreen({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
    this.isError = true,
    this.buttonText,
    this.onButtonPressed,
    this.customAction,
    this.topAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (topAction != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: topAction!,
                    ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          imagePath,
                          height: 240,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isError ? const Color(0xFFC62828) : const Color(0xFF00A79D),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7A90),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (customAction != null) customAction!,
                  if (buttonText != null && onButtonPressed != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onButtonPressed,
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
                          buttonText!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
