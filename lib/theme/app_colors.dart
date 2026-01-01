import 'package:flutter/material.dart';

class AppColors {
  // Primary & Secondary (Brand)
  static const Color primary = Color(0xFFD67730);
  static const Color secondary = Color(0xFF003060);
  static const Color textPrimary = secondary; // Dark Navy

  // Greys / Surface / Borders (Tailwind-ish)
  static const Color surfaceLight = Color(0xFFF9FAFB);
  static const Color backgroundLight = Color(0xFFF5F5F5); // gray-100 equivalent often
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderMedium = Color(0xFFD1D5DB);
  static const Color borderDefault = Color(0xFFCCCCCC);
  static const Color textGreyLight = Color(0xFF9CA3AF);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color textGreyDark = Color(0xFF374151);
  static const Color searchBarBackground = Color(0xFFD4DCE5);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color slate500 = Color(0xFF64748B);
  static const Color concrete = Color(0xFF95A5A6);

  // Status Colors
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color emerald600 = Color(0xFF059669);
  static const Color nephritis = Color(0xFF27AE60);
  static const Color red = Color(0xFFFF0000);
  static const Color darkRed = Color(0xFFCC0000);

  // Blues
  static const Color blueAccent = Color(0xFF4A90E2);
  static const Color lightBlueAccent = Color(0xFF5DA3FA);
  static const Color blue = Color(0xFF0066FF);
  static const Color darkBlue = Color(0xFF1E3A8A);
  static const Color navy = Color(0xFF004080);
  static const Color royalBlue = Color(0xFF0033A0);

  // Oranges / Purples
  static const Color orangeAccent = Color(0xFFFF6B35);
  static const Color carrotOrange = Color(0xFFE67E22);
  static const Color amethyst = Color(0xFF9B59B6);
  static const Color floralWhite = Color(0xFFFFF8F0);
  static const Color linen = Color(0xFFFFF4E6);

  // Shadows (Low opacity blacks)
  static const Color shadowSubtle = Color(0x0F000000);
  static const Color shadowMicro = Color(0x0A000000);
}
