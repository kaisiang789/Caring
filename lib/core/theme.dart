import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0D9488);      // Teal
  static const Color primaryLight = Color(0xFFE0F2F1);
  static const Color accent = Color(0xFFFCD34D);       // Gold
  static const Color dark = Color(0xFF1E293B);         // Text Dark
  static const Color gray = Color(0xFF64748B);         // Text Gray
  static const Color lightGray = Color(0xFFF8FAFC);    // Lighter Backgrounds
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF1F5F9);   // App Background
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color mapBackground = Color(0xFFE5E7EB);
  static const Color mapRoad = Color(0xFFFFFFFF);

  // Universal card shadow
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      offset: const Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];
}