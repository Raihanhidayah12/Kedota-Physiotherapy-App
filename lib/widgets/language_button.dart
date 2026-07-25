import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../l10n/app_language.dart';

class LanguageButton extends StatelessWidget {
  final bool onDarkBackground;

  const LanguageButton({super.key, this.onDarkBackground = false});

  @override
  Widget build(BuildContext context) {
    final language = AppLanguageScope.current(context);
    final isEnglish = language == AppLanguage.en;
    final foreground = onDarkBackground
        ? Colors.white
        : const Color(0xFF17324D);
    final background = onDarkBackground
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.92);
    final border = onDarkBackground
        ? Colors.white.withValues(alpha: 0.26)
        : const Color(0xFF17324D).withValues(alpha: 0.14);
    final shadow = onDarkBackground
        ? Colors.black.withValues(alpha: 0.2)
        : const Color(0xFF7F9CCB).withValues(alpha: 0.2);

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1.15),
        boxShadow: [
          BoxShadow(color: shadow, blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => AppLanguageScope.toggle(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8.5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language_rounded, size: 16.5, color: foreground),
                    const SizedBox(width: 6),
                    Text(
                      isEnglish ? 'EN' : 'ID',
                      style: TextStyle(
                        fontSize: 12.6,
                        fontWeight: FontWeight.w800,
                        color: foreground,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
