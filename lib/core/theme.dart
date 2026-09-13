import 'package:flutter/material.dart';

class AppColors {
  // 主品牌色：现代健康翡翠墨绿
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFFE6F4F1);
  static const Color primaryAccent = Color(0xFF14B8A6);

  // 辅助与状态色
  static const Color accent = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFF43F5E);
  static const Color warning = Color(0xFFD97706);

  // 界面背景与表面（解决 cardSurface 缺失问题）
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);

  // 字体颜色层级
  static const Color dark = Color(0xFF0F172A);
  static const Color body = Color(0xFF334155);
  static const Color gray = Color(0xFF64748B);
  static const Color muted = Color(0xFF94A3B8);

  // 地图配色兼容
  static const Color mapBackground = Color(0xFFE2E8F0);
  static const Color mapRoad = Color(0xFFFFFFFF);

  // 柔光高级阴影
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      offset: const Offset(0, 8),
      blurRadius: 20,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.02),
      offset: const Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];
}
