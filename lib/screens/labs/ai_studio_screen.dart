import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dynamic_palette.dart';
import '../../models/song_model.dart';
import '../../providers/providers.dart';
import '../../services/ai_image_service.dart';
import '../../widgets/elite_background.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/suno_captcha_sheet.dart';

enum StudioPhase { idle, lyricConstruction, orchestration, vocalSynthesis, mastering, complete }

class AIStudioScreen extends ConsumerStatefulWidget {
  const AIStudioScreen({super.key});

  @override
  ConsumerState<AIStudioScreen> createState() => _AIStudioScreenState();
}

class _AIStudioScreenState extends ConsumerState<AIStudioScreen> with TickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _lyricsController = TextEditingController();
  
  String _selectedGenre = 'Bollywood Romantic';
  String _selectedGender = 'Male Singer';
  String _selectedExpression = 'Soft & Melodious';
  bool _isInstrumental = false;
  bool _showCustomLyrics = false;
  
  StudioPhase _phase = StudioPhase.idle;
  late AnimationController _radialController;
  late AnimationController _equalizerController;
  final List<double> _waveAmplitudes = List.generate(12, (_) => 0.1);
  final math.Random _random = math.Random();
  Timer? _animTimer;
  
  String _synthesisStatus = '';
  double _synthesisProgress = 0.0;
  SongModel? _generatedSong;
  Timer? _countdownTimer;
  int _secondsRemaining = 90;

  // Curated preset genres
  final List<String> _genres = [
    'Bollywood Romantic',
    'Punjabi Club-Hiphop',
    'Sufi Fusion',
    'Qawwali Rock',
    'Lo-Fi Chill',
    'Synthwave Retro',
    'EDM Rave',
    'Acoustic Pop'
  ];

  final List<String> _genders = [
    'Male Singer',
    'Female Singer',
    'Duet (Male + Female)'
  ];

  final List<String> _expressions = [
    'Soft & Melodious',
    'High-Energy & Powerful',
    'Deep & Soulful',
    'Classical Trained'
  ];

  @override
  void initState() {
    super.initState();
    _radialController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _lyricsController.dispose();
    _radialController.dispose();
    _equalizerController.dispose();
    _animTimer?.cancel();
    super.dispose();
  }

  List<String> _getConsoleLogs(StudioPhase phase) {
    switch (phase) {
      case StudioPhase.lyricConstruction:
        return [
          '> SYS [0.0s] ROTTY Generative Engine online...',
          '> INF [1.2s] Connecting to secure payload gateway...',
          '> INF [2.1s] Drafting poetic Hindi-Punjabi stanzas...',
          '> OK  [2.8s] Lyrics structure compiled [Chorus/Verse].',
        ];
      case StudioPhase.orchestration:
        return [
          '> INF [3.2s] Aligning composition tempo to 112 BPM...',
          '> INF [4.0s] Orchestrating symphonic chords & tracks...',
          '> INF [5.2s] Layering deep sub-bass frequencies...',
          '> OK  [5.9s] Full orchestration arrangement synthesized.',
        ];
      case StudioPhase.vocalSynthesis:
        return [
          '> INF [6.4s] Commencing multi-layered neural voice synthesis...',
          '> INF [7.8s] Laying male/female melodic expressiveness...',
          '> INF [8.9s] Bouncing vocals onto backing instrumentals...',
          '> OK  [9.8s] Vocal track blended successfully.',
        ];
      case StudioPhase.mastering:
        return [
          '> INF [10.2s] Normalizing gains & stereo mastering fields...',
          '> INF [11.0s] Bouncing high-fidelity wav outputs...',
          '> INF [11.8s] Compounding AES-256 secure creation payload...',
          '> OK  [12.5s] Stereo mastering processing completed.',
        ];
      case StudioPhase.complete:
        return [
          '> SYS [13.0s] COMPOSITION READY. Securely loaded to library.',
        ];
      default:
        return [];
    }
  }

  void _startWaveAnimation() {
    _animTimer?.cancel();
    _equalizerController.repeat(reverse: true);
    _radialController.repeat();
    
    _animTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _waveAmplitudes.length; i++) {
          if (_phase == StudioPhase.orchestration) {
            _waveAmplitudes[i] = 0.2 + _random.nextDouble() * 0.8;
          } else if (_phase == StudioPhase.mastering) {
            _waveAmplitudes[i] = 0.5 + _random.nextDouble() * 0.5;
          } else {
            _waveAmplitudes[i] = 0.1;
          }
        }
      });
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 90;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 3) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
  }

  void _stopWaveAnimation() {
    _animTimer?.cancel();
    _equalizerController.stop();
    _radialController.stop();
    _stopCountdown();
  }

  // Generates high-quality lyrics dynamically via backend API
  Future<void> _generateAILyrics() async {
    final theme = _promptController.text.trim();
    if (theme.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe a theme in the prompt box first!')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.purple),
      ),
    );

    try {
      final generatedLyrics = await ref.read(apiServiceProvider).generateLyrics(
        prompt: theme,
        genre: _selectedGenre,
      );

      if (mounted) Navigator.of(context).pop();

      if (generatedLyrics != null && generatedLyrics.isNotEmpty) {
        setState(() {
          _lyricsController.text = generatedLyrics;
          _showCustomLyrics = true;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not generate lyrics. Please try again or write your own.')),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating lyrics: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _executeGenerationFlow({bool forceBackup = false}) async {
    final promptText = _promptController.text.trim();
    try {
      return await ref.read(apiServiceProvider).generateSong(
        prompt: promptText,
        genre: _selectedGenre,
        vocalGender: _selectedGender,
        vocalExpression: _selectedExpression,
        isInstrumental: _isInstrumental,
        customLyrics: _showCustomLyrics ? _lyricsController.text.trim() : '',
        forceBackup: forceBackup,
      );
    } catch (e) {
      print("Generation flow error: $e");
      return null;
    }
  }

  void _triggerSongComposition() async {
    final promptText = _promptController.text.trim();
    if (promptText.isEmpty && (!_showCustomLyrics || _lyricsController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description prompt or custom lyrics!')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    
    setState(() {
      _phase = StudioPhase.lyricConstruction;
      _synthesisStatus = 'Initiating neural composition queue...';
      _synthesisProgress = 0.05;
      _secondsRemaining = 90;
      _startWaveAnimation();
    });

    final initiationResult = await _executeGenerationFlow(forceBackup: false);
    if (initiationResult == null || !initiationResult.containsKey('taskId')) {
      _stopWaveAnimation();
      setState(() {
        _phase = StudioPhase.idle;
        _synthesisStatus = '';
      });
      
      final errType = initiationResult?['error'] ?? '';
      final isAuthError = errType == 'auth_failed' || 
                          errType == 'unauthorized' || 
                          errType == 'expired_cookies' ||
                          (initiationResult?['message']?.toString().toLowerCase().contains('clerk') ?? false) ||
                          (initiationResult?['message']?.toString().toLowerCase().contains('cookie') ?? false) ||
                          (initiationResult?['message']?.toString().toLowerCase().contains('unauthorized') ?? false);

      if (isAuthError && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF16162A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Suno Session Expired',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              'The Suno AI session cookies or Clerk auth tokens have expired or are invalid. '
              'Please update your Suno cookies on the server or try again later.',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ),
        );
      } else {
        final errMsg = initiationResult?['message'] ?? 'Failed to initiate song composition. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg)),
        );
      }
      return;
    }

    final String taskId = initiationResult['taskId'];
    print("🎯 ROTTY STUDIO CLIENT: Polling background task $taskId...");

    bool isDone = false;
    int errorCount = 0;

    while (!isDone && mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      try {
        final statusRes = await ref.read(apiServiceProvider).getGenerationStatus(taskId);
        if (statusRes == null) {
          errorCount++;
          if (errorCount > 5) {
            throw Exception('Too many status polling failures.');
          }
          continue;
        }
        errorCount = 0; // Reset error count on successful query

        final String status = statusRes['status'] ?? '';
        final double progress = (statusRes['progress'] != null)
            ? double.tryParse(statusRes['progress'].toString()) ?? 0.0
            : 0.0;
        final int eta = (statusRes['eta'] != null)
            ? int.tryParse(statusRes['eta'].toString()) ?? 60
            : 60;
        final String message = statusRes['message'] ?? 'Composing...';

        print("🎯 ROTTY CLIENT POLL: status=$status, progress=$progress, eta=$eta, message=$message");



        if (status == 'failed') {
          final errType = statusRes['error'] ?? '';
          final isAuthError = errType == 'auth_failed' || 
                              errType == 'unauthorized' || 
                              errType == 'expired_cookies' ||
                              (statusRes['message']?.toString().toLowerCase().contains('clerk') ?? false) ||
                              (statusRes['message']?.toString().toLowerCase().contains('cookie') ?? false) ||
                              (statusRes['message']?.toString().toLowerCase().contains('unauthorized') ?? false);

          if (isAuthError) {
            isDone = true;
            _stopWaveAnimation();
            setState(() {
              _phase = StudioPhase.idle;
              _synthesisStatus = '';
            });
            
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF16162A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'Suno Session Expired',
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ],
                  ),
                  content: Text(
                    'The Suno AI session cookies or Clerk auth tokens have expired or are invalid. '
                    'Please update your Suno cookies on the server or try again later.',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK', style: TextStyle(color: AppColors.accent)),
                    ),
                  ],
                ),
              );
            }
            return;
          }

          if (errType == 'captcha_required') {
            _stopWaveAnimation();
            setState(() {
              _synthesisStatus = 'hCaptcha verification required...';
            });
            
            final clientCookie = statusRes['clientCookie'] ?? '';
            
            if (mounted) {
              final result = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                barrierColor: Colors.black54,
                builder: (context) => SunoCaptchaSheet(
                  clientCookie: clientCookie,
                  prompt: promptText,
                  genre: _selectedGenre,
                  vocalGender: _selectedGender,
                  vocalExpression: _selectedExpression,
                  isInstrumental: _isInstrumental,
                  customLyrics: _showCustomLyrics ? _lyricsController.text.trim() : '',
                  taskId: taskId,
                ),
              );

              if (result == 'success') {
                // Resume polling!
                setState(() {
                  _phase = StudioPhase.vocalSynthesis;
                  _synthesisStatus = 'Verification successful! Resuming composition...';
                  _startWaveAnimation();
                });
                continue;
              } else if (result == 'backup') {
                isDone = true;
                _stopWaveAnimation();
                _triggerForcedBackupSongComposition();
                return;
              }
            }
            
            isDone = true;
            _stopWaveAnimation();
            setState(() {
              _phase = StudioPhase.idle;
              _synthesisStatus = '';
            });
            return;
          }

          isDone = true;
          _stopWaveAnimation();
          setState(() {
            _phase = StudioPhase.idle;
            _synthesisStatus = '';
          });
          final errMsg = statusRes['message'] ?? 'Sorry, service is unavailable for a moment.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg)),
          );
          return;
        }

        if (status == 'complete') {
          isDone = true;
          _stopWaveAnimation();

          final completedSong = statusRes['result'];
          if (completedSong != null && completedSong['url'] != null) {
            final generatedSongId = 'suno_${DateTime.now().millisecondsSinceEpoch}';
            final songTitle = completedSong['title'] ?? '${_selectedGenre} Original Track';
            final coverImg = AiImageService.getCoverUrl(
              prompt: '${promptText.isNotEmpty ? promptText : _selectedGenre} music album cover, aesthetic high quality visualizer graphic art, vibrant detailed illustration',
              seed: songTitle,
            );
            final newSong = SongModel(
              id: generatedSongId,
              title: songTitle,
              artist: 'ROTTY AI Studio',
              album: 'prompt:${promptText.isEmpty ? "Instrumental theme" : promptText}||genre:$_selectedGenre||vocals:$_selectedGender - $_selectedExpression',
              image: coverImg,
              duration: Duration(seconds: completedSong['duration'] != null ? int.tryParse(completedSong['duration'].toString()) ?? 180 : 180),
              url: completedSong['url'],
              lyrics: completedSong['lyrics'] ?? (_showCustomLyrics ? _lyricsController.text.trim() : ''),
            );

            // Save to Hive local database
            await ref.read(studioCreationsProvider.notifier).addCreation(newSong);

            setState(() {
              _generatedSong = newSong;
              _phase = StudioPhase.complete;
              _synthesisStatus = 'Composition rendered successfully!';
              _synthesisProgress = 1.0;
            });
          } else {
            setState(() {
              _phase = StudioPhase.idle;
              _synthesisStatus = '';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to parse completed composition.')),
            );
          }
          return;
        }

        // Update UI status, progress and server-driven ETA!
        setState(() {
          _synthesisProgress = progress;
          _secondsRemaining = eta;
          _synthesisStatus = message;

          // Map status string to StudioPhase
          if (status == 'initiated' || status == 'lyric_construction') {
            _phase = StudioPhase.lyricConstruction;
          } else if (status == 'orchestration') {
            _phase = StudioPhase.orchestration;
          } else if (status == 'vocal_synthesis') {
            _phase = StudioPhase.vocalSynthesis;
          } else if (status == 'mastering') {
            _phase = StudioPhase.mastering;
          }
        });

      } catch (e) {
        print("Polling check failed: $e");
        errorCount++;
        if (errorCount > 5) {
          isDone = true;
          _stopWaveAnimation();
          setState(() {
            _phase = StudioPhase.idle;
            _synthesisStatus = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server connection lost during synthesis. Please check your network.')),
          );
          return;
        }
      }
    }
  }

  void _triggerForcedBackupSongComposition() async {
    final promptText = _promptController.text.trim();
    if (promptText.isEmpty && (!_showCustomLyrics || _lyricsController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description prompt or custom lyrics!')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    
    setState(() {
      _phase = StudioPhase.lyricConstruction;
      _synthesisStatus = 'Initiating neural composition queue (Backup Mode)...';
      _synthesisProgress = 0.05;
      _secondsRemaining = 90;
      _startWaveAnimation();
    });

    final initiationResult = await _executeGenerationFlow(forceBackup: true);
    if (initiationResult == null || !initiationResult.containsKey('taskId')) {
      _stopWaveAnimation();
      setState(() {
        _phase = StudioPhase.idle;
        _synthesisStatus = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to initiate backup composition. Please try again.')),
      );
      return;
    }

    final String taskId = initiationResult['taskId'];
    print("🎯 ROTTY STUDIO CLIENT: Polling background backup task $taskId...");

    bool isDone = false;
    int errorCount = 0;

    while (!isDone && mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      try {
        final statusRes = await ref.read(apiServiceProvider).getGenerationStatus(taskId);
        if (statusRes == null) {
          errorCount++;
          if (errorCount > 5) {
            throw Exception('Too many status polling failures.');
          }
          continue;
        }
        errorCount = 0; // Reset error count on successful query

        final String status = statusRes['status'] ?? '';
        final double progress = (statusRes['progress'] != null)
            ? double.tryParse(statusRes['progress'].toString()) ?? 0.0
            : 0.0;
        final int eta = (statusRes['eta'] != null)
            ? int.tryParse(statusRes['eta'].toString()) ?? 60
            : 60;
        final String message = statusRes['message'] ?? 'Composing...';

        print("🎯 ROTTY CLIENT POLL: status=$status, progress=$progress, eta=$eta, message=$message");

        if (status == 'failed') {
          isDone = true;
          _stopWaveAnimation();
          setState(() {
            _phase = StudioPhase.idle;
            _synthesisStatus = '';
          });
          final errMsg = statusRes['message'] ?? 'Sorry, service is unavailable for a moment.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg)),
          );
          return;
        }

        if (status == 'complete') {
          isDone = true;
          _stopWaveAnimation();

          final completedSong = statusRes['result'];
          if (completedSong != null && completedSong['url'] != null) {
            final generatedSongId = 'suno_${DateTime.now().millisecondsSinceEpoch}';
            final songTitle = completedSong['title'] ?? '${_selectedGenre} Original Track';
            final coverImg = AiImageService.getCoverUrl(
              prompt: '${promptText.isNotEmpty ? promptText : _selectedGenre} music album cover, aesthetic high quality visualizer graphic art, vibrant detailed illustration',
              seed: songTitle,
            );
            final newSong = SongModel(
              id: generatedSongId,
              title: songTitle,
              artist: 'ROTTY AI Studio',
              album: 'prompt:${promptText.isEmpty ? "Instrumental theme" : promptText}||genre:$_selectedGenre||vocals:$_selectedGender - $_selectedExpression',
              image: coverImg,
              duration: Duration(seconds: completedSong['duration'] != null ? int.tryParse(completedSong['duration'].toString()) ?? 180 : 180),
              url: completedSong['url'],
              lyrics: completedSong['lyrics'] ?? (_showCustomLyrics ? _lyricsController.text.trim() : ''),
            );

            // Save to Hive local database
            await ref.read(studioCreationsProvider.notifier).addCreation(newSong);

            setState(() {
              _generatedSong = newSong;
              _phase = StudioPhase.complete;
              _synthesisStatus = 'Composition rendered successfully!';
              _synthesisProgress = 1.0;
            });
          } else {
            setState(() {
              _phase = StudioPhase.idle;
              _synthesisStatus = '';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to parse completed composition.')),
            );
          }
          return;
        }

        // Update UI status, progress and server-driven ETA!
        setState(() {
          _synthesisProgress = progress;
          _secondsRemaining = eta;
          _synthesisStatus = message;

          // Map status string to StudioPhase
          if (status == 'initiated' || status == 'lyric_construction') {
            _phase = StudioPhase.lyricConstruction;
          } else if (status == 'orchestration') {
            _phase = StudioPhase.orchestration;
          } else if (status == 'vocal_synthesis') {
            _phase = StudioPhase.vocalSynthesis;
          } else if (status == 'mastering') {
            _phase = StudioPhase.mastering;
          }
        });

      } catch (e) {
        print("Polling check failed: $e");
        errorCount++;
        if (errorCount > 5) {
          isDone = true;
          _stopWaveAnimation();
          setState(() {
            _phase = StudioPhase.idle;
            _synthesisStatus = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server connection lost during synthesis. Please check your network.')),
          );
          return;
        }
      }
    }
  }

  void _showRegenerateCoverDialog() {
    if (_generatedSong == null) return;
    final promptCtrl = TextEditingController(
      text: _promptController.text.isNotEmpty 
          ? _promptController.text 
          : '${_generatedSong!.title} cover art, beautiful vibrant style',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16162A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Customize Cover Art',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Describe what you want the cover art to look like. We will use AI to generate it instantly.',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: promptCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                hintText: 'e.g. A neon cybernetic sitar in deep space, digital art...',
                hintStyle: const TextStyle(color: Colors.white30),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prompt = promptCtrl.text.trim();
              if (prompt.isEmpty) return;
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: Colors.purpleAccent),
                ),
              );
              
              try {
                final newUrl = AiImageService.getCoverUrl(
                  prompt: prompt,
                  seed: '${_generatedSong!.id}_${DateTime.now().millisecondsSinceEpoch}',
                );
                
                final updatedSong = _generatedSong!.copyWith(
                  image: newUrl,
                );
                
                await ref.read(studioCreationsProvider.notifier).addCreation(updatedSong);
                
                if (mounted) {
                  setState(() {
                    _generatedSong = updatedSong;
                  });
                  Navigator.pop(context); // Pop loading spinner
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cover Art regenerated!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to generate cover: $e')),
                  );
                }
              }
            },
            child: const Text('Generate', style: TextStyle(color: Colors.purpleAccent)),
          ),
        ],
      ),
    );
  }

  // Local Offline Download Manager
  void _downloadSongOffline() async {
    if (_generatedSong == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading composition for offline playback...')),
    );

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final creationsDir = Directory('${docDir.path}/creations');
      if (!await creationsDir.exists()) {
        await creationsDir.create(recursive: true);
      }

      final file = File('${creationsDir.path}/${_generatedSong!.id}.mp3');
      final response = await http.get(Uri.parse(_generatedSong!.url)).timeout(const Duration(seconds: 35));

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        
        // Update model URL to local filepath
        final localSong = SongModel(
          id: _generatedSong!.id,
          title: _generatedSong!.title,
          artist: _generatedSong!.artist,
          album: _generatedSong!.album,
          image: _generatedSong!.image,
          duration: _generatedSong!.duration,
          url: Uri.file(file.path).toString(),
          lyrics: _generatedSong!.lyrics,
        );

        // Update in Hive box
        await ref.read(studioCreationsProvider.notifier).addCreation(localSong);
        setState(() {
          _generatedSong = localSong;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloaded successfully! Saved to My Creations.')),
        );
      } else {
        throw Exception("Server status code: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Offline download failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(dynamicPaletteProvider);

    return RottyDynamicAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'ROTTY Studio',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18, letterSpacing: 0.5),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_phase == StudioPhase.idle) ...[
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LiquidGlass(
                          borderRadius: 20,
                          surfaceOpacity: 0.04,
                          borderOpacity: 0.1,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ROTTY ORIGINAL COMPOSITION STUDIO',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: palette.primary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Write description or paste lyrics to compose deep playback AI songs.',
                                style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                              ),
                              const SizedBox(height: 24),
                              
                              // Prompt Box
                              Text(
                                'DESCRIBE YOUR SONG STYLE',
                                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.45), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _promptController,
                                minLines: 2,
                                maxLines: 4,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Enter style, mood, or instrument details...',
                                  hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.02),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: palette.primary.withValues(alpha: 0.3)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              
                              // Lyrics Trigger Button
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: _generateAILyrics,
                                      icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 16),
                                      label: Text('Generate AI Lyrics', style: GoogleFonts.inter(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.white.withValues(alpha: 0.02),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _showCustomLyrics = !_showCustomLyrics;
                                        });
                                      },
                                      icon: Icon(_showCustomLyrics ? Icons.visibility_off_rounded : Icons.lyrics_rounded, color: Colors.white60, size: 16),
                                      label: Text(_showCustomLyrics ? 'Hide Custom Lyrics' : 'Write Custom Lyrics', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.white.withValues(alpha: 0.02),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        if (_showCustomLyrics) ...[
                          const SizedBox(height: 16),
                          LiquidGlass(
                            borderRadius: 16,
                            surfaceOpacity: 0.04,
                            borderOpacity: 0.1,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'PASTE OR WRITE CUSTOM LYRICS',
                                  style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.45), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _lyricsController,
                                  minLines: 4,
                                  maxLines: 8,
                                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.4),
                                  decoration: InputDecoration(
                                    hintText: 'Enter custom verses... Include [Verse] and [Chorus] tags for better structures.',
                                    hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 11),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.02),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: palette.primary.withValues(alpha: 0.3)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        
                        // Genre chips carousel
                        Text(
                          ' SELECT CURATED GENRE',
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 38,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _genres.length,
                            itemBuilder: (context, i) {
                              final g = _genres[i];
                              final active = _selectedGenre == g;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedGenre = g),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: active ? palette.primary : Colors.white.withValues(alpha: 0.02),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: active ? palette.primary : Colors.white.withValues(alpha: 0.06),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      g,
                                      style: GoogleFonts.inter(
                                        color: active ? Colors.white : Colors.white60,
                                        fontSize: 12,
                                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Vocal selection and options
                        LiquidGlass(
                          borderRadius: 16,
                          surfaceOpacity: 0.04,
                          borderOpacity: 0.1,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'VOCAL TYPE & STYLE PROFILE',
                                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.45), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 12),
                              
                              // Vocal Gender selector
                              Row(
                                children: [
                                  const Icon(Icons.face_rounded, color: Colors.white30, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButton<String>(
                                      value: _selectedGender,
                                      dropdownColor: Colors.black87,
                                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                                      iconEnabledColor: Colors.white30,
                                      underline: const SizedBox(),
                                      isExpanded: true,
                                      items: _genders.map((String val) {
                                        return DropdownMenuItem<String>(
                                          value: val,
                                          child: Text(val),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _selectedGender = val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white12, height: 16),
                              
                              // Vocal Expression selector
                              Row(
                                children: [
                                  const Icon(Icons.tune_rounded, color: Colors.white30, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButton<String>(
                                      value: _selectedExpression,
                                      dropdownColor: Colors.black87,
                                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                                      iconEnabledColor: Colors.white30,
                                      underline: const SizedBox(),
                                      isExpanded: true,
                                      items: _expressions.map((String val) {
                                        return DropdownMenuItem<String>(
                                          value: val,
                                          child: Text(val),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _selectedExpression = val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white12, height: 16),
                              
                              // Instrumental Toggle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.music_video_rounded, color: Colors.white30, size: 16),
                                      const SizedBox(width: 8),
                                      Text('Pure Instrumental (No vocals)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                  Switch(
                                    value: _isInstrumental,
                                    activeColor: palette.primary,
                                    inactiveThumbColor: Colors.white30,
                                    inactiveTrackColor: Colors.white10,
                                    onChanged: (val) {
                                      setState(() => _isInstrumental = val);
                                    },
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [palette.primary, const Color(0xFFFF007A)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _triggerSongComposition,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Center(
                        child: Text(
                          'LAUNCH COMPOSITION',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Generative progress visualizer console
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_phase != StudioPhase.complete) ...[
                        SizedBox(
                          height: 240,
                          width: 240,
                          child: AnimatedBuilder(
                            animation: _radialController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _StudioVisualPainter(
                                  phase: _phase,
                                  animationValue: _radialController.value,
                                  waveAmplitudes: _waveAmplitudes,
                                  random: _random,
                                  palette: palette,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 30),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0),
                          child: LiquidGlass(
                            borderRadius: 16,
                            surfaceOpacity: 0.04,
                            borderOpacity: 0.1,
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                               Text(
                                  _synthesisStatus,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: _synthesisProgress,
                                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                                    color: palette.primary,
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${(_synthesisProgress * 100).toInt()}%',
                                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                if (_phase != StudioPhase.idle && _phase != StudioPhase.complete) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 13,
                                        color: palette.primary.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Estimated remaining: ~${_secondsRemaining}s',
                                        style: GoogleFonts.inter(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0),
                          child: Container(
                            height: 110,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _getConsoleLogs(_phase).map((log) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Text(
                                      log,
                                      style: GoogleFonts.robotoMono(
                                        color: log.contains('OK')
                                            ? const Color(0xFF00E676)
                                            : log.contains('SYS')
                                                ? const Color(0xFFFFD700)
                                                : Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ] else if (_generatedSong != null) ...[
                        // Checkmark Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00E676), size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'COMPOSITION RESOLVED',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF00E676),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Premium Cassette/Album Glassmorphic Preview Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: LiquidGlass(
                            borderRadius: 24,
                            surfaceOpacity: 0.06,
                            borderOpacity: 0.15,
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                // Cover Art Stack
                                GestureDetector(
                                  onTap: () {
                                    ref.read(audioHandlerProvider).playMediaItem(
                                      MediaItem(
                                        id: _generatedSong!.id,
                                        title: _generatedSong!.title,
                                        artist: _generatedSong!.artist,
                                        album: _generatedSong!.album,
                                        duration: _generatedSong!.duration,
                                        artUri: Uri.parse(_generatedSong!.image),
                                        extras: {
                                          'url': _generatedSong!.url,
                                          'lyrics': _generatedSong!.lyrics,
                                        },
                                      ),
                                    );
                                    context.push('/player');
                                  },
                                  child: Container(
                                    width: 170,
                                    height: 170,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: palette.primary.withValues(alpha: 0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        )
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Stack(
                                        children: [
                                          Image.network(
                                            _generatedSong!.image,
                                            fit: BoxFit.cover,
                                            width: 170,
                                            height: 170,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: AppColors.bgCard,
                                              child: Center(
                                                child: Icon(Icons.music_note_rounded, color: palette.primary, size: 40),
                                              ),
                                            ),
                                          ),
                                          // Sleek neon glow gradient overlay
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withValues(alpha: 0.4),
                                                ],
                                              ),
                                            ),
                                          ),
                                          // Massive play icon overlay in center
                                          Center(
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.5),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white24),
                                              ),
                                              child: const Icon(
                                                Icons.play_arrow_rounded,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                // Title & Subtitle
                                Text(
                                  _generatedSong!.title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ROTTY AI Studio',
                                  style: GoogleFonts.inter(
                                    color: Colors.white60,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Metadata Badges
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _selectedGenre.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          color: palette.primary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${_generatedSong!.formattedDuration} MIN',
                                        style: GoogleFonts.inter(
                                          color: Colors.white38,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _showRegenerateCoverDialog,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  icon: const Icon(Icons.palette_rounded, color: Colors.purpleAccent, size: 14),
                                  label: Text(
                                    'GENERATE AI COVER',
                                    style: GoogleFonts.inter(
                                      color: Colors.purpleAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Actions row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _phase = StudioPhase.idle;
                                        _generatedSong = null;
                                      });
                                    },
                                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                                    label: Text('Reset', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: TextButton.icon(
                                    onPressed: _downloadSongOffline,
                                    icon: Icon(
                                      _generatedSong!.url.startsWith('file:') ? Icons.offline_pin_rounded : Icons.download_rounded,
                                      color: _generatedSong!.url.startsWith('file:') ? const Color(0xFF00E676) : Colors.white,
                                      size: 16,
                                    ),
                                    label: Text(
                                      _generatedSong!.url.startsWith('file:') ? 'Saved Offline' : 'Save Offline',
                                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [palette.primary, const Color(0xFFFF007A)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: palette.primary.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: TextButton.icon(
                                    onPressed: () {
                                      ref.read(audioHandlerProvider).playMediaItem(
                                        MediaItem(
                                          id: _generatedSong!.id,
                                          title: _generatedSong!.title,
                                          artist: _generatedSong!.artist,
                                          album: _generatedSong!.album,
                                          duration: _generatedSong!.duration,
                                          artUri: Uri.parse(_generatedSong!.image),
                                          extras: {
                                            'url': _generatedSong!.url,
                                            'lyrics': _generatedSong!.lyrics,
                                          },
                                        ),
                                      );
                                      context.push('/player');
                                    },
                                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                                    label: Text('Play Song', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioVisualPainter extends CustomPainter {
  final StudioPhase phase;
  final double animationValue;
  final List<double> waveAmplitudes;
  final math.Random random;
  final DynamicPalette palette;

  _StudioVisualPainter({
    required this.phase,
    required this.animationValue,
    required this.waveAmplitudes,
    required this.random,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 10, gridPaint);
    canvas.drawCircle(center, radius * 0.7, gridPaint);
    canvas.drawCircle(center, radius * 0.4, gridPaint);

    final pulseRadius = radius - 5 + math.sin(animationValue * math.pi * 2) * 3;
    final borderPaint = Paint()
      ..color = palette.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, pulseRadius, borderPaint);

    if (phase == StudioPhase.lyricConstruction) {
      final rectWidth = 130.0;
      final rectHeight = 130.0;
      final holoRect = Rect.fromCenter(center: center, width: rectWidth, height: rectHeight);
      
      final holoPaint = Paint()
        ..color = palette.primary.withValues(alpha: 0.04)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(holoRect, const Radius.circular(12)), holoPaint);

      final holoBorderPaint = Paint()
        ..color = palette.primary.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(RRect.fromRectAndRadius(holoRect, const Radius.circular(12)), holoBorderPaint);

      final hudPaint = Paint()
        ..color = palette.primary.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      final double bracketSize = 12.0;

      canvas.drawPath(Path()
        ..moveTo(holoRect.left, holoRect.top + bracketSize)
        ..lineTo(holoRect.left, holoRect.top)
        ..lineTo(holoRect.left + bracketSize, holoRect.top), hudPaint);
      canvas.drawPath(Path()
        ..moveTo(holoRect.right, holoRect.top + bracketSize)
        ..lineTo(holoRect.right, holoRect.top)
        ..lineTo(holoRect.right - bracketSize, holoRect.top), hudPaint);
      canvas.drawPath(Path()
        ..moveTo(holoRect.left, holoRect.bottom - bracketSize)
        ..lineTo(holoRect.left, holoRect.bottom)
        ..lineTo(holoRect.left + bracketSize, holoRect.bottom), hudPaint);
      canvas.drawPath(Path()
        ..moveTo(holoRect.right, holoRect.bottom - bracketSize)
        ..lineTo(holoRect.right, holoRect.bottom)
        ..lineTo(holoRect.right - bracketSize, holoRect.bottom), hudPaint);

      final textLinePaint = Paint()
        ..color = palette.primary.withValues(alpha: 0.6)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < 5; i++) {
        final double yOffset = ((animationValue * 130.0 + i * 26.0) % 110.0) - 55.0;
        final double y = center.dy + yOffset;
        if (y > holoRect.top + 10 && y < holoRect.bottom - 10) {
          final double lineWidth = 45.0 + math.sin(i * 1.5) * 20.0;
          canvas.drawLine(
            Offset(center.dx - lineWidth / 2, y),
            Offset(center.dx + lineWidth / 2 - 10, y),
            textLinePaint
          );
          final cursorPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(center.dx + lineWidth / 2, y), 2.5, cursorPaint);
        }
      }
    } 
    else if (phase == StudioPhase.orchestration) {
      final numBars = 36;
      final angleStep = (math.pi * 2) / numBars;
      final baseRadius = 55.0;
      final double maxBarHeight = 35.0;

      final pulseScale = 1.0 + (waveAmplitudes[0] * 0.15);
      final corePaint = Paint()
        ..color = palette.primary.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 40 * pulseScale, corePaint);

      final coreBorder = Paint()
        ..color = palette.primary.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, 40 * pulseScale, coreBorder);
      canvas.drawCircle(center, 22 * pulseScale, coreBorder..strokeWidth = 1.0);
      canvas.drawCircle(center, 7, Paint()..color = palette.primary.withValues(alpha: 0.75));

      for (int i = 0; i < numBars; i++) {
        final angle = i * angleStep + (animationValue * math.pi * 0.25);
        final amp = waveAmplitudes[i % waveAmplitudes.length];
        final double barLen = amp * maxBarHeight;

        final startX = center.dx + math.cos(angle) * baseRadius;
        final startY = center.dy + math.sin(angle) * baseRadius;
        final endX = center.dx + math.cos(angle) * (baseRadius + barLen);
        final endY = center.dy + math.sin(angle) * (baseRadius + barLen);

        final colorVal = Color.lerp(palette.primary, palette.secondary, i / numBars)!;
        final barPaint = Paint()
          ..color = colorVal
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), barPaint);

        final inwardEndX = center.dx + math.cos(angle) * (baseRadius - barLen * 0.4);
        final inwardEndY = center.dy + math.sin(angle) * (baseRadius - barLen * 0.4);
        canvas.drawLine(
          Offset(startX, startY),
          Offset(inwardEndX, inwardEndY),
          Paint()
            ..color = colorVal.withValues(alpha: 0.35)
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round
        );
      }
    } 
    else if (phase == StudioPhase.vocalSynthesis) {
      final double vinylRadius = 85.0;
      final bodyPaint = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF0F0F1D), Color(0xFF020206)],
        ).createShader(Rect.fromCircle(center: center, radius: vinylRadius))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, vinylRadius, bodyPaint);

      final groovePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      for (double r = 38.0; r < vinylRadius; r += 7.0) {
        canvas.drawCircle(center, r, groovePaint);
      }

      final shineAngle = animationValue * math.pi * 2;
      final shinePaint = Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.12),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.12),
            Colors.transparent
          ],
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          transform: GradientRotation(shineAngle),
        ).createShader(Rect.fromCircle(center: center, radius: vinylRadius));
      canvas.drawCircle(center, vinylRadius, shinePaint);

      canvas.drawCircle(center, 24, Paint()..color = palette.secondary);
      canvas.drawCircle(center, 24, Paint()..color = Colors.black.withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      canvas.drawCircle(center, 8, Paint()..color = Colors.black);

      final armStart = Offset(center.dx + 80, center.dy - 80);
      final armPivot = Offset(center.dx + 70, center.dy - 70);
      final needlePos = Offset(
        center.dx + 28 + math.cos(animationValue * 0.08) * 10,
        center.dy + 28 + math.sin(animationValue * 0.08) * 10
      );

      final armPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path()
        ..moveTo(armStart.dx, armStart.dy)
        ..lineTo(armPivot.dx, armPivot.dy)
        ..lineTo(center.dx + 52, center.dy - 24)
        ..lineTo(needlePos.dx, needlePos.dy);
      canvas.drawPath(path, armPaint);

      canvas.drawCircle(armPivot, 8, Paint()..color = Colors.grey[700]!);
      canvas.drawCircle(armPivot, 4, Paint()..color = Colors.white);
      canvas.drawCircle(needlePos, 3.5, Paint()..color = palette.primary);
    } 
    else if (phase == StudioPhase.mastering) {
      final meterRect = Rect.fromCenter(center: Offset(center.dx, center.dy + 15), width: 190, height: 120);
      canvas.drawRRect(RRect.fromRectAndRadius(meterRect, const Radius.circular(12)), Paint()..color = Colors.white.withValues(alpha: 0.03)..style = PaintingStyle.fill);
      canvas.drawRRect(RRect.fromRectAndRadius(meterRect, const Radius.circular(12)), Paint()..color = Colors.white.withValues(alpha: 0.08)..style = PaintingStyle.stroke..strokeWidth = 1.0);

      final leftCenter = Offset(center.dx - 45, center.dy + 28);
      final rightCenter = Offset(center.dx + 45, center.dy + 28);

      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = Colors.white24;

      canvas.drawArc(Rect.fromCenter(center: leftCenter, width: 62, height: 62), math.pi * 1.25, math.pi * 0.5, false, arcPaint);
      canvas.drawArc(Rect.fromCenter(center: rightCenter, width: 62, height: 62), math.pi * 1.25, math.pi * 0.5, false, arcPaint);

      final redPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = Colors.redAccent.withValues(alpha: 0.75);
      canvas.drawArc(Rect.fromCenter(center: leftCenter, width: 62, height: 62), math.pi * 1.63, math.pi * 0.12, false, redPaint);
      canvas.drawArc(Rect.fromCenter(center: rightCenter, width: 62, height: 62), math.pi * 1.63, math.pi * 0.12, false, redPaint);

      final leftAmp = waveAmplitudes[0];
      final rightAmp = waveAmplitudes[waveAmplitudes.length - 1];

      final leftNeedleAngle = math.pi * 1.25 + (leftAmp * math.pi * 0.5);
      final rightNeedleAngle = math.pi * 1.25 + (rightAmp * math.pi * 0.5);

      final needlePaint = Paint()
        ..color = const Color(0xFFFFD700)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(leftCenter, Offset(leftCenter.dx + math.cos(leftNeedleAngle) * 35, leftCenter.dy + math.sin(leftNeedleAngle) * 35), needlePaint);
      canvas.drawLine(rightCenter, Offset(rightCenter.dx + math.cos(rightNeedleAngle) * 35, rightCenter.dy + math.sin(rightNeedleAngle) * 35), needlePaint);

      final capPaint = Paint()..color = Colors.grey[800]!;
      canvas.drawCircle(leftCenter, 4.5, capPaint);
      canvas.drawCircle(rightCenter, 4.5, capPaint);

      final dbPaint = Paint()..color = Colors.white30;
      for (int i = 0; i <= 5; i++) {
        final tickAngle = math.pi * 1.25 + (i * 0.1 * math.pi);
        canvas.drawLine(Offset(leftCenter.dx + math.cos(tickAngle) * 31, leftCenter.dy + math.sin(tickAngle) * 31), Offset(leftCenter.dx + math.cos(tickAngle) * 34, leftCenter.dy + math.sin(tickAngle) * 34), dbPaint);
        canvas.drawLine(Offset(rightCenter.dx + math.cos(tickAngle) * 31, rightCenter.dy + math.sin(tickAngle) * 31), Offset(rightCenter.dx + math.cos(tickAngle) * 34, rightCenter.dy + math.sin(tickAngle) * 34), dbPaint);
      }
    } 
    else if (phase == StudioPhase.complete) {
      final pulse = 1.0 + math.sin(DateTime.now().millisecondsSinceEpoch / 250) * 0.03;
      final completePaint = Paint()
        ..color = const Color(0xFF00E676).withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 90 * pulse, completePaint);
      canvas.drawCircle(center, 70 * pulse, completePaint..color = const Color(0xFF00E676).withValues(alpha: 0.12));

      final ringPaint = Paint()
        ..color = const Color(0xFF00E676)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, 60, ringPaint);

      final checkPaint = Paint()
        ..color = const Color(0xFF00E676)
        ..strokeWidth = 5.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      
      final path = Path()
        ..moveTo(center.dx - 16, center.dy + 1)
        ..lineTo(center.dx - 4, center.dy + 13)
        ..lineTo(center.dx + 16, center.dy - 11);
      canvas.drawPath(path, checkPaint);

      final particlePaint = Paint()..color = const Color(0xFF00E676).withValues(alpha: 0.6);
      for (int i = 0; i < 8; i++) {
        final angle = i * (math.pi / 4) + (animationValue * math.pi * 0.2);
        final pRadius = 75.0 + math.sin(animationValue * math.pi * 2) * 5;
        final px = center.dx + math.cos(angle) * pRadius;
        final py = center.dy + math.sin(angle) * pRadius;
        canvas.drawCircle(Offset(px, py), 2, particlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
