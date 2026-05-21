import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/premium_providers.dart';
import '../../providers/providers.dart';
import '../../services/storage_service.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/liquid_glass.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _pinCtrl = TextEditingController();
  bool _unlocked = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _tryUnlock() {
    final stored = StorageService().vaultPin;
    if (stored == null || stored == _pinCtrl.text) {
      setState(() => _unlocked = true);
      ref.read(vaultUnlockedProvider.notifier).state = true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Incorrect PIN', style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  Future<void> _setPin() async {
    if (_pinCtrl.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('PIN must be at least 4 digits', style: TextStyle(color: Colors.white)),
        ),
      );
      return;
    }
    await StorageService().setVaultPin(_pinCtrl.text);
    setState(() => _unlocked = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.bgElevated,
          content: Text('Private Vault PIN configured successfully', style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlists = StorageService().getPlaylists();
    final palette = ref.watch(dynamicPaletteProvider);

    return RottyDynamicAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Rotty Vault',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 20),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: LiquidGlass(
              borderRadius: 24,
              surfaceOpacity: 0.08,
              borderOpacity: 0.15,
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              padding: const EdgeInsets.all(28),
              child: _unlocked
                  ? _unlockedView(playlists, palette.primary)
                  : _lockedView(palette.primary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lockedView(Color accent) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.lock_rounded, size: 32, color: accent),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'SECURE MUSIC VAULT',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: accent,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your private 4-digit PIN to access local playlists.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 6),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '••••',
            hintStyle: GoogleFonts.inter(color: Colors.white24, letterSpacing: 4),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.03),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent.withValues(alpha: 0.4), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        LiquidGlassButton(
          accentColor: accent,
          isActive: true,
          onTap: _tryUnlock,
          child: Center(
            child: Text(
              'UNLOCK VAULT',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white, letterSpacing: 1.0),
            ),
          ),
        ),
        const SizedBox(height: 12),
        LiquidGlassButton(
          accentColor: Colors.white30,
          onTap: _setPin,
          child: Center(
            child: Text(
              'CONFIGURE NEW PIN',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white70, letterSpacing: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _unlockedView(List<dynamic> playlists, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRIVATE STORAGE',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: accent,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'These playlists are stored strictly local to your device.',
          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: playlists.isEmpty
              ? Center(
                  child: Text(
                    'No private playlists found. Create one in the Library tab.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: playlists.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = playlists[i];
                    return LiquidGlassCard(
                      accentColor: accent,
                      borderRadius: 14,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: accent.withValues(alpha: 0.18)),
                            ),
                            child: Icon(Icons.lock_outline_rounded, color: accent, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${p.songs.length} tracks saved offline',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.25), size: 14),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
