import 'package:flutter/material.dart';

class AppTheme {
  // --- Colors ---
  static const Color primary = Color(0xFF2563EB); // Blue
  static const Color secondary = Color(0xFF64748B); // Slate
  static const Color background = Color(0xFFF8FAFC); // Light Gray/White
  static const Color surface = Colors.white;
  
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF3B82F6); // Blue

  static const Color textPrimary = Color(0xFF1E293B); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color borderColor = Color(0xFFE2E8F0); // Slate 200

  // --- Text Styles ---
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: textSecondary,
    fontWeight: FontWeight.w500,
  );

  // --- Decorations ---
  
  // Standard Card Shadow
  static List<BoxShadow> shadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // Glow Effect (for active items)
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.25),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: 2,
    ),
  ];

  static BorderRadius borderRadius = BorderRadius.circular(16);
  static BorderRadius borderRadiusSmall = BorderRadius.circular(8);

  static BoxDecoration cardDecoration = BoxDecoration(
    color: surface,
    borderRadius: borderRadius,
    border: Border.all(color: borderColor),
    boxShadow: shadow,
  );

  // --- Animations ---
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Curve animationCurve = Curves.easeInOut;
}
