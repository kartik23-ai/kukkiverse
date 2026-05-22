import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final _answerCtrl = TextEditingController();
  bool _unlocked = false;

  @override
  void deactivate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vaultUnlockedProvider.notifier).state = false;
    });
    super.deactivate();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  void _tryUnlock() {
    if (_pinCtrl.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('PIN must be exactly 4 digits', style: TextStyle(color: Colors.white)),
        ),
      );
      return;
    }
    final stored = StorageService().vaultPin;
    if (stored != null && stored.isNotEmpty && stored == _pinCtrl.text) {
      setState(() => _unlocked = true);
      ref.read(vaultUnlockedProvider.notifier).state = true;
      _pinCtrl.clear();
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
    if (_pinCtrl.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('PIN must be exactly 4 digits', style: TextStyle(color: Colors.white)),
        ),
      );
      return;
    }

    String selectedQuestion = "What was the name of your first pet?";
    final setupSuccess = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Setup Recovery Question',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'This question will be used to recover or reset your vault PIN if you ever forget it.',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    dropdownColor: AppColors.bgElevated,
                    value: selectedQuestion,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.03),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    items: [
                      "What was the name of your first pet?",
                      "What is the name of your favorite musical artist?",
                      "What city were you born in?",
                      "What is your childhood nickname?",
                    ].map((q) => DropdownMenuItem(value: q, child: Text(q, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedQuestion = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _answerCtrl,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter your answer here',
                      hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.03),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () {
                    if (_answerCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.redAccent,
                          content: Text('Answer cannot be empty', style: TextStyle(color: Colors.white)),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Complete Setup', style: TextStyle(color: Colors.blueAccent)),
                ),
              ],
            );
          },
        );
      },
    );

    if (setupSuccess == true) {
      final pin = _pinCtrl.text;
      final answer = _answerCtrl.text;
      await StorageService().setVaultPin(pin);
      await StorageService().setVaultQuestion(selectedQuestion);
      await StorageService().setVaultAnswer(answer);

      setState(() {
        _unlocked = true;
        _pinCtrl.clear();
        _answerCtrl.clear();
      });
      ref.read(vaultUnlockedProvider.notifier).state = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.amber,
            content: Text('Private Vault configured securely!', style: TextStyle(color: Colors.black)),
          ),
        );
      }
    }
  }

  Future<void> _resetVaultFlow() async {
    final storedQuestion = StorageService().vaultQuestion;
    final storedAnswer = StorageService().vaultAnswer;

    if (storedQuestion == null || storedAnswer == null) {
      // Fallback if no security question set
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgElevated,
          title: const Text('Reset Vault PIN', style: TextStyle(color: Colors.white)),
          content: const Text(
            'No recovery question set for this vault. Are you sure you want to reset the vault PIN? Your private playlists will remain saved.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await StorageService().setVaultPin(null);
        await StorageService().setVaultQuestion(null);
        await StorageService().setVaultAnswer(null);
        setState(() {
          _unlocked = false;
          _pinCtrl.clear();
        });
        ref.read(vaultUnlockedProvider.notifier).state = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.amber,
              content: Text('Vault PIN reset successfully', style: TextStyle(color: Colors.black)),
            ),
          );
        }
      }
      return;
    }

    final recoveryAnswerCtrl = TextEditingController();
    final isCorrect = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Security Challenge', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Answer your recovery question to reset the Vault PIN.',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Text(
              storedQuestion,
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: recoveryAnswerCtrl,
              autofocus: true,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter recovery answer',
                hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.03),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final val = recoveryAnswerCtrl.text.toLowerCase().trim();
              if (val == storedAnswer) {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text('Incorrect Answer. Access Denied.', style: TextStyle(color: Colors.white)),
                  ),
                );
                Navigator.pop(ctx, false);
              }
            },
            child: const Text('Verify Answer', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );

    if (isCorrect == true) {
      await StorageService().setVaultPin(null);
      await StorageService().setVaultQuestion(null);
      await StorageService().setVaultAnswer(null);
      setState(() {
        _unlocked = false;
        _pinCtrl.clear();
      });
      ref.read(vaultUnlockedProvider.notifier).state = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.amber,
            content: Text('Verification successful. Vault PIN reset successfully.', style: TextStyle(color: Colors.black)),
          ),
        );
      }
    }
  }

  void _showManagePlaylistsSheet(BuildContext context, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final allPlaylists = ref.watch(playlistsProvider);
                final privatePlaylists = allPlaylists.where((p) => p.isPrivate).toList();
                final publicPlaylists = allPlaylists.where((p) => !p.isPrivate).toList();
                final newPlaylistCtrl = TextEditingController();

                return LiquidGlass(
                  borderRadius: 24,
                  surfaceOpacity: 0.15,
                  borderOpacity: 0.22,
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.lock_rounded, color: accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'MANAGE SECURE VAULT',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: accent,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create secure playlists or import/export normal playlists here.',
                        style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                      ),
                      const SizedBox(height: 20),

                      // Section A: Create New Secure Playlist
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newPlaylistCtrl,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Create secure playlist name',
                                hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.03),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: accent.withValues(alpha: 0.4)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent.withValues(alpha: 0.2),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              side: BorderSide(color: accent.withValues(alpha: 0.25)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () async {
                              final name = newPlaylistCtrl.text.trim();
                              if (name.isNotEmpty) {
                                await ref.read(playlistsProvider.notifier).create(name, isPrivate: true);
                                newPlaylistCtrl.clear();
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Created secure playlist: "$name"')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Playlists Lists
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            // Import section
                            if (publicPlaylists.isNotEmpty) ...[
                              Text(
                                'IMPORT PLAYLISTS TO VAULT',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: accent, letterSpacing: 1.0),
                              ),
                              const SizedBox(height: 8),
                              ...publicPlaylists.map((p) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.music_note_rounded, color: Colors.white54, size: 18),
                                ),
                                title: Text(p.name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: Text('${p.songs.length} tracks', style: GoogleFonts.inter(color: Colors.white30, fontSize: 11)),
                                trailing: TextButton.icon(
                                  icon: const Icon(Icons.lock_rounded, size: 12, color: Colors.amber),
                                  label: Text('Lock', style: GoogleFonts.inter(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    await ref.read(playlistsProvider.notifier).togglePrivacy(p.id);
                                  },
                                ),
                              )),
                              const SizedBox(height: 24),
                            ],

                            // Export section
                            if (privatePlaylists.isNotEmpty) ...[
                              Text(
                                'EXPORT PLAYLISTS FROM VAULT (MAKE PUBLIC)',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 1.0),
                              ),
                              const SizedBox(height: 8),
                              ...privatePlaylists.map((p) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.lock_rounded, color: accent, size: 18),
                                ),
                                title: Text(p.name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: Text('${p.songs.length} tracks', style: GoogleFonts.inter(color: Colors.white30, fontSize: 11)),
                                trailing: TextButton.icon(
                                  icon: const Icon(Icons.lock_open_rounded, size: 12, color: Colors.white54),
                                  label: Text('Unlock', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    await ref.read(playlistsProvider.notifier).togglePrivacy(p.id);
                                  },
                                ),
                              )),
                            ],

                            if (allPlaylists.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Text('No playlists created yet.', style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistsProvider).where((p) => p.isPrivate).toList();
    final palette = ref.watch(dynamicPaletteProvider);
    final storedPin = StorageService().vaultPin;
    final hasPin = storedPin != null && storedPin.isNotEmpty;

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
          actions: _unlocked
              ? [
                  IconButton(
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    tooltip: 'Add/Manage Vault Playlists',
                    onPressed: () => _showManagePlaylistsSheet(context, palette.primary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_rounded, color: Colors.amber),
                    tooltip: 'Lock Vault',
                    onPressed: () {
                      setState(() {
                        _unlocked = false;
                        _pinCtrl.clear();
                      });
                      ref.read(vaultUnlockedProvider.notifier).state = false;
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                    onSelected: (val) async {
                      if (val == 'reset') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.bgElevated,
                            title: const Text('Remove Vault PIN', style: TextStyle(color: Colors.white)),
                            content: const Text(
                              'Are you sure you want to remove the PIN? Your private playlists will remain saved, but the vault will no longer require a PIN to access until a new one is set.',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await StorageService().setVaultPin(null);
                          await StorageService().setVaultQuestion(null);
                          await StorageService().setVaultAnswer(null);
                          setState(() {
                            _unlocked = false;
                            _pinCtrl.clear();
                          });
                          ref.read(vaultUnlockedProvider.notifier).state = false;
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.amber,
                                content: Text('Vault PIN cleared successfully', style: TextStyle(color: Colors.black)),
                              ),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'reset',
                        child: Row(
                          children: [
                            Icon(Icons.lock_reset_rounded, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Remove Vault PIN', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ]
              : null,
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
                  : _lockedView(palette.primary, hasPin),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lockedView(Color accent, bool hasPin) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
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
              child: Icon(hasPin ? Icons.lock_rounded : Icons.lock_open_rounded, size: 32, color: accent),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            hasPin ? 'SECURE MUSIC VAULT' : 'SETUP SECURE VAULT',
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
            hasPin
                ? 'Enter your private 4-digit PIN to access local playlists.'
                : 'Choose a secure 4-digit PIN to encrypt and protect your private music playlists.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _pinCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 6),
            textAlign: TextAlign.center,
            onSubmitted: (_) => hasPin ? _tryUnlock() : _setPin(),
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
            onTap: hasPin ? _tryUnlock : _setPin,
            child: Center(
              child: Text(
                hasPin ? 'UNLOCK VAULT' : 'CREATE SECURE VAULT PIN',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white, letterSpacing: 1.0),
              ),
            ),
          ),
          if (hasPin) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _resetVaultFlow,
                child: Text(
                  'Forgot PIN? Reset Vault',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_open_rounded, color: Colors.white.withValues(alpha: 0.15), size: 36),
                      const SizedBox(height: 12),
                      Text(
                        'No private playlists found.\nTap the "+" icon at the top to create one or import existing ones!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.35), fontSize: 12, height: 1.3),
                      ),
                    ],
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
                      onTap: () => context.push(
                        '/album/${p.id}',
                        extra: {'title': p.name, 'songs': p.songs},
                      ),
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
