import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/premium_providers.dart';
import '../../services/storage_service.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wrong PIN')));
    }
  }

  Future<void> _setPin() async {
    if (_pinCtrl.text.length < 4) return;
    await StorageService().setVaultPin(_pinCtrl.text);
    setState(() => _unlocked = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vault PIN saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
  final playlists = StorageService().getPlaylists();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Vault', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: _unlocked
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Private playlists', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                if (playlists.isEmpty)
                  Text('Create playlists in Library — they stay on device.', style: GoogleFonts.inter(color: AppColors.textTertiary))
                else
                  ...playlists.map(
                    (p) => ListTile(
                      tileColor: AppColors.bgCard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: Text(p.name, style: GoogleFonts.inter(color: Colors.white)),
                      subtitle: Text('${p.songs.length} songs', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
                      leading: const Icon(Icons.lock_rounded, color: AppColors.accent),
                    ),
                  ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.lock_rounded, size: 64, color: AppColors.accent),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: '4-digit PIN', labelStyle: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: _tryUnlock, child: const Text('Unlock')),
                  TextButton(onPressed: _setPin, child: const Text('Set new PIN')),
                ],
              ),
            ),
    );
  }
}
