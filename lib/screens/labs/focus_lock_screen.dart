import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/feature_providers.dart';
import '../../providers/providers.dart';

class FocusLockScreen extends ConsumerStatefulWidget {
  const FocusLockScreen({super.key});

  @override
  ConsumerState<FocusLockScreen> createState() => _FocusLockScreenState();
}

class _FocusLockScreenState extends ConsumerState<FocusLockScreen> {
  Timer? _timer;
  int _remaining = 0;
  bool _active = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start(int minutes) {
    _timer?.cancel();
    setState(() {
      _active = true;
      _remaining = minutes * 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() {
          _active = false;
          _remaining = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Focus session complete')));
        }
        return;
      }
      setState(() => _remaining--);
    });
  }

  String get _timeLabel {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final minutes = ref.watch(focusTimerMinutesProvider);
    final playing = ref.watch(isPlayingProvider);
    final handler = ref.read(audioHandlerProvider);

    return PopScope(
      canPop: !_active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _active) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End focus to leave')));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text('Focus Lock', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          backgroundColor: Colors.transparent,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (_active)
                Text(_timeLabel, style: GoogleFonts.inter(color: AppColors.accent, fontSize: 56, fontWeight: FontWeight.w800))
              else
                Text('$minutes min', style: GoogleFonts.inter(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              Text('Music keeps playing — stay in flow', style: GoogleFonts.inter(color: AppColors.textSecondary)),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      playing ? handler.pause() : handler.play();
                    },
                  ),
                ],
              ),
              const Spacer(),
              if (!_active)
                FilledButton(
                  onPressed: () => _start(minutes),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size.fromHeight(52)),
                  child: const Text('Start focus'),
                )
              else
                OutlinedButton(
                  onPressed: () {
                    _timer?.cancel();
                    setState(() {
                      _active = false;
                      _remaining = 0;
                    });
                  },
                  child: const Text('End session'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
