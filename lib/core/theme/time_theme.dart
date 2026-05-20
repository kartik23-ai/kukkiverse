import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

/// ═══════════════════════════════════════════════════════════════
/// Dynamic Time-of-Day Glass Theme System
/// Automatically morphs colors based on device clock.
/// ═══════════════════════════════════════════════════════════════

enum DayPhase { morning, noon, evening, night }

class TimeThemeData {
  final DayPhase phase;
  final String label;
  final Color glassTint;
  final Color glassEdge;
  final Color accentGlow;
  final Color bgDeep;
  final Color bgSurface;
  final Color textPrimary;
  final Color textSecondary;
  final List<Color> auroraColors;
  final LinearGradient headerGradient;

  const TimeThemeData({
    required this.phase,
    required this.label,
    required this.glassTint,
    required this.glassEdge,
    required this.accentGlow,
    required this.bgDeep,
    required this.bgSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.auroraColors,
    required this.headerGradient,
  });

  /// Morning Dew — 05:00–11:59
  static const morning = TimeThemeData(
    phase: DayPhase.morning,
    label: 'Morning Dew',
    glassTint: Color(0xCC0D1B2A),
    glassEdge: Color(0x28DCEEFB),
    accentGlow: Color(0xFF7EC8E3),
    bgDeep: Color(0xFF0A1628),
    bgSurface: Color(0xFF0F1E33),
    textPrimary: Color(0xFFE8F4FD),
    textSecondary: Color(0xFF8BAFC4),
    auroraColors: [Color(0xFF7EC8E3), Color(0xFFB8E6CF), Color(0xFFFFF3B0)],
    headerGradient: LinearGradient(
      colors: [Color(0xFF0A1628), Color(0xFF132D4A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  /// Sleek Solar — 12:00–16:59
  static const noon = TimeThemeData(
    phase: DayPhase.noon,
    label: 'Sleek Solar',
    glassTint: Color(0xCC111827),
    glassEdge: Color(0x28F5C563),
    accentGlow: Color(0xFFF5A623),
    bgDeep: Color(0xFF0C1220),
    bgSurface: Color(0xFF151D2E),
    textPrimary: Color(0xFFFAF3E8),
    textSecondary: Color(0xFFA89070),
    auroraColors: [Color(0xFFF5A623), Color(0xFF5B7DB1), Color(0xFF2D3A50)],
    headerGradient: LinearGradient(
      colors: [Color(0xFF0C1220), Color(0xFF1A2740)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  /// Golden Hour — 17:00–20:59
  static const evening = TimeThemeData(
    phase: DayPhase.evening,
    label: 'Golden Hour',
    glassTint: Color(0xCC1A0E1E),
    glassEdge: Color(0x28FFB07C),
    accentGlow: Color(0xFFFF7B54),
    bgDeep: Color(0xFF150A1A),
    bgSurface: Color(0xFF1E1228),
    textPrimary: Color(0xFFFFF0E6),
    textSecondary: Color(0xFFBF8F70),
    auroraColors: [Color(0xFFFF7B54), Color(0xFFD4508B), Color(0xFF6B3FA0)],
    headerGradient: LinearGradient(
      colors: [Color(0xFF150A1A), Color(0xFF2A1535)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  /// Deep Obsidian Nebula — 21:00–04:59
  static const night = TimeThemeData(
    phase: DayPhase.night,
    label: 'Deep Obsidian',
    glassTint: Color(0xCC08060E),
    glassEdge: Color(0x20A78BFA),
    accentGlow: Color(0xFF8B5CF6),
    bgDeep: Color(0xFF050310),
    bgSurface: Color(0xFF0C0818),
    textPrimary: Color(0xFFEDE8F5),
    textSecondary: Color(0xFF7C6F99),
    auroraColors: [Color(0xFF8B5CF6), Color(0xFF3B82F6), Color(0xFF06B6D4)],
    headerGradient: LinearGradient(
      colors: [Color(0xFF050310), Color(0xFF0E0820)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  static TimeThemeData fromHour(int hour) {
    if (hour >= 5 && hour < 12) return morning;
    if (hour >= 12 && hour < 17) return noon;
    if (hour >= 17 && hour < 21) return evening;
    return night;
  }
}

/// Riverpod provider that auto-updates every 10 minutes
class TimeThemeNotifier extends StateNotifier<TimeThemeData> {
  Timer? _timer;

  TimeThemeNotifier() : super(TimeThemeData.fromHour(DateTime.now().hour)) {
    _timer = Timer.periodic(const Duration(minutes: 10), (_) {
      final newTheme = TimeThemeData.fromHour(DateTime.now().hour);
      if (newTheme.phase != state.phase) {
        state = newTheme;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final timeThemeProvider =
    StateNotifierProvider<TimeThemeNotifier, TimeThemeData>((ref) {
  return TimeThemeNotifier();
});
