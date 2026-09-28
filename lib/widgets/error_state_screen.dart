import 'package:flutter/material.dart';

class ErrorStateScreen extends StatelessWidget {
  const ErrorStateScreen({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
    this.isError = true,
    this.actionEnabled = true,
    this.imageHeight = 96,
    this.isLoading = false,
  });

  final String imagePath;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;
  final bool isError;
  final bool actionEnabled;
  final double imageHeight;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxImageHeight = (constraints.maxHeight * 0.28)
              .clamp(40.0, 220.0)
              .toDouble();
          final fittedImageHeight = imageHeight
              .clamp(40.0, maxImageHeight)
              .toDouble();
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            imagePath,
                            height: fittedImageHeight,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isError
                                  ? const Color(0xFFE85C59)
                                  : const Color(0xFF00A79D),
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF687782),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: actionEnabled && !isLoading ? onPressed : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF008F87),
                      disabledBackgroundColor: const Color(0xFF008F87),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            buttonText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
