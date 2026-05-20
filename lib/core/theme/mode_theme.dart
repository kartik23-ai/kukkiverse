import 'package:flutter/material.dart';
import '../modes/app_mode.dart';

/// ═══════════════════════════════════════════════════════════════
/// ModeTheme 2.0 — Extreme mode transformations
/// Each mode radically alters the app's DNA — colors, layout,
/// typography, visibility, and interaction model.
/// ═══════════════════════════════════════════════════════════════
class ModeTheme {
  final RottyAppMode mode;

  const ModeTheme(this.mode);

  // ─── COLORS ───────────────────────────────────────────────────

  /// Primary accent — each mode has its own identity color
  Color get accent => switch (mode) {
    RottyAppMode.normal => const Color(0xFFFA2D48),
    RottyAppMode.focus  => const Color(0xFFE0E0E0),  // Monochrome white
    RottyAppMode.drive  => const Color(0xFFFF6B4A),   // Hot orange
    RottyAppMode.sleep  => const Color(0xFF5B4FA7),   // Deep purple
  };

  /// Background tint
  Color get bg => switch (mode) {
    RottyAppMode.normal => const Color(0xFF050508),
    RottyAppMode.focus  => const Color(0xFF111111),   // Pure monochrome dark
    RottyAppMode.drive  => const Color(0xFF030205),   // Deep void
    RottyAppMode.sleep  => const Color(0xFF000000),   // Absolute black
  };

  /// Card/surface color
  Color get surface => switch (mode) {
    RottyAppMode.normal => Colors.white.withValues(alpha: 0.06),
    RottyAppMode.focus  => Colors.white.withValues(alpha: 0.03),  // Barely visible
    RottyAppMode.drive  => const Color(0xFFFF6B4A).withValues(alpha: 0.06),
    RottyAppMode.sleep  => Colors.white.withValues(alpha: 0.02),  // Ghost
  };

  /// Text primary
  Color get textPrimary => switch (mode) {
    RottyAppMode.sleep  => const Color(0x55FFFFFF),   // Very dim
    RottyAppMode.focus  => const Color(0xFFE8E8E8),   // Monochrome
    _                   => Colors.white,
  };

  /// Text secondary
  Color get textSecondary => switch (mode) {
    RottyAppMode.sleep  => const Color(0x33FFFFFF),
    RottyAppMode.focus  => const Color(0x88FFFFFF),
    _                   => const Color(0xB3FFFFFF),
  };

  // ─── AURORA ───────────────────────────────────────────────────

  /// Aurora background intensity
  double get auroraIntensity => switch (mode) {
    RottyAppMode.normal => 0.6,
    RottyAppMode.focus  => 0.0,    // NO aurora — monochrome
    RottyAppMode.drive  => 0.0,    // Drive has its own HUD background
    RottyAppMode.sleep  => 0.1,    // Barely there nebula glow
  };

  /// Aurora palette per mode
  List<Color> get auroraColors => switch (mode) {
    RottyAppMode.normal => const [Color(0xFFFA2D48), Color(0xFF5E5CE6), Color(0xFF7B61FF), Color(0xFF00D4FF)],
    RottyAppMode.focus  => const [Color(0xFF333333), Color(0xFF222222), Color(0xFF444444)],
    RottyAppMode.drive  => const [Color(0xFFFF6B4A), Color(0xFFFF3D1E)],
    RottyAppMode.sleep  => const [Color(0xFF2A1A57), Color(0xFF1A0A47), Color(0xFF3B2B77)],
  };

  // ─── UI DIMENSIONS ────────────────────────────────────────────

  /// Overall UI opacity multiplier
  double get uiOpacity => switch (mode) {
    RottyAppMode.sleep  => 0.35,   // Almost invisible
    RottyAppMode.focus  => 0.85,   // Slightly toned down
    _                   => 1.0,
  };

  /// Control button scale
  double get controlScale => switch (mode) {
    RottyAppMode.drive  => 1.5,    // MASSIVE for driving
    RottyAppMode.focus  => 0.9,    // Compact
    RottyAppMode.sleep  => 0.8,    // Tiny, ghost-like
    _                   => 1.0,
  };

  /// Font size multiplier
  double get fontScale => switch (mode) {
    RottyAppMode.drive  => 1.2,
    RottyAppMode.focus  => 0.92,
    RottyAppMode.sleep  => 0.85,
    _                   => 1.0,
  };

  /// Show decorative elements (particles, gradients, badges)
  bool get showDecorations => switch (mode) {
    RottyAppMode.focus  => false,  // Strip ALL decoration
    RottyAppMode.sleep  => false,  // Only nebula cloud
    _                   => true,
  };

  /// Show labs/extras in home
  bool get showExtras => switch (mode) {
    RottyAppMode.focus  => false,
    RottyAppMode.sleep  => false,
    RottyAppMode.drive  => false,
    _                   => true,
  };

  /// Show quick actions row
  bool get showQuickActions => switch (mode) {
    RottyAppMode.focus  => false,
    RottyAppMode.sleep  => false,
    RottyAppMode.drive  => false,
    _                   => true,
  };

  /// Show album art in player/lists
  bool get showAlbumArt => switch (mode) {
    RottyAppMode.focus  => false,  // Monochrome — no art distractions
    _                   => true,
  };

  /// Show bottom navigation bar
  bool get showBottomNav => switch (mode) {
    RottyAppMode.drive  => false,  // Full immersive
    RottyAppMode.sleep  => false,  // Full dark
    _                   => true,
  };

  /// Use monospaced font (brutalist feel)
  bool get useMonoFont => switch (mode) {
    RottyAppMode.focus  => true,   // Space Mono / JetBrains Mono
    _                   => false,
  };

  /// Force landscape
  bool get forceLandscape => switch (mode) {
    RottyAppMode.drive  => true,
    _                   => false,
  };

  /// Enable haptic feedback intensity
  double get hapticMultiplier => switch (mode) {
    RottyAppMode.drive  => 1.5,    // Extra heavy
    RottyAppMode.sleep  => 0.0,    // No haptics during sleep
    _                   => 1.0,
  };

  /// Mode title for display
  String get modeTitle => switch (mode) {
    RottyAppMode.normal => 'ROTTY',
    RottyAppMode.focus  => 'FOCUS',
    RottyAppMode.drive  => 'DRIVE',
    RottyAppMode.sleep  => 'SLEEP',
  };

  /// Mode icon
  IconData get modeIcon => switch (mode) {
    RottyAppMode.normal => Icons.music_note_rounded,
    RottyAppMode.focus  => Icons.self_improvement_rounded,
    RottyAppMode.drive  => Icons.speed_rounded,
    RottyAppMode.sleep  => Icons.bedtime_rounded,
  };

  /// Gradient for mode badge
  LinearGradient get accentGradient => LinearGradient(
    colors: [accent, accent.withValues(alpha: 0.7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── ANIMATION ────────────────────────────────────────────────

  /// Transition duration for mode switches
  static const Duration transitionDuration = Duration(milliseconds: 600);
  static const Curve transitionCurve = Curves.easeInOutCubic;
}
