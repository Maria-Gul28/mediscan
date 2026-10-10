import 'package:flutter/material.dart';

/// Central palette + shared shape tokens, matched to the reference
/// healthcare-app mockups: soft mint background, deep-teal header,
/// white rounded cards, pill-shaped buttons and chips.
class AppColors {
  AppColors._();

  // Core teal family
  static const Color deepTeal =
      Color(0xFF0B3D3A); // header / dark text on light
  static const Color primaryTeal = Color(0xFF14A89A); // buttons, active states
  static const Color brightTeal = Color(0xFF1FC2AE); // gradients, highlights
  static const Color mintBg = Color(0xFFE3F4EF); // page background
  static const Color mintChip = Color(0xFFDCF3EC); // light pill/chip fill

  // Neutrals
  static const Color cardWhite = Colors.white;
  static const Color textDark = Color(0xFF16302C);
  static const Color textMuted = Color(0xFF6E8B85);
  static const Color border = Color(0xFFE1EEEA);

  // Status
  static const Color warnBg = Color(0xFFFFF6DD);
  static const Color warnText = Color(0xFF8A6D1F);
  static const Color guessBg = Color(0xFFFFF1DD);
  static const Color guessBorder = Color(0xFFFFD9A0);
  static const Color guessText = Color(0xFFB4620A);
  static const Color errorBg = Color(0xFFFDECEC);
  static const Color errorText = Color(0xFFC0392B);
  static const Color listening = Color(0xFFE9584B);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepTeal, Color(0xFF0F5C55)],
  );

  static const LinearGradient primaryButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primaryTeal, brightTeal],
  );
}

class AppRadii {
  AppRadii._();
  static const double card = 22;
  static const double headerBottom = 32;
  static const double pill = 30;
  static const double chip = 20;
  static const double preview = 16;
}

class AppShadows {
  AppShadows._();
  static List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.deepTeal.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> button = [
    BoxShadow(
      color: AppColors.primaryTeal.withValues(alpha: 0.35),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];
}
