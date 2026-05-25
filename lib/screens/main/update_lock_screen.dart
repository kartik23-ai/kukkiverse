import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../services/update_service.dart';

class UpdateLockScreen extends ConsumerStatefulWidget {
  const UpdateLockScreen({super.key});

  @override
  ConsumerState<UpdateLockScreen> createState() => _UpdateLockScreenState();
}

class _UpdateLockScreenState extends ConsumerState<UpdateLockScreen> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';

  Future<void> _launchWebsite() async {
    final updateInfo = UpdateService.instance.latestUpdate;
    final urlString = updateInfo?.downloadUrl ?? 'https://kukkiverse.github.io/website/';
    final url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _startAutomaticUpdate(String downloadUrl) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Initializing secure connection...';
    });

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request).timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        final totalBytes = response.contentLength ?? 0;
        var receivedBytes = 0;
        final chunks = <List<int>>[];

        final tempDir = await getTemporaryDirectory();
        // Detemine correct file extension
        String fileExtension = '.exe';
        if (downloadUrl.toLowerCase().endsWith('.msi')) {
          fileExtension = '.msi';
        } else if (downloadUrl.toLowerCase().endsWith('.apk')) {
          fileExtension = '.apk';
        }

        final tempFile = File('${tempDir.path}/rotty_update_setup$fileExtension');

        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }

        await for (final chunk in response.stream) {
          chunks.add(chunk);
          receivedBytes += chunk.length;
          setState(() {
            if (totalBytes > 0) {
              _downloadProgress = receivedBytes / totalBytes;
              _downloadStatus = 'Downloading update: ${(_downloadProgress * 100).toStringAsFixed(0)}%';
            } else {
              _downloadStatus = 'Downloading: ${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
            }
          });
        }

        setState(() {
          _downloadStatus = 'Writing local binaries...';
        });

        // Write all chunks to the temporary file
        final ios = tempFile.openWrite();
        for (final chunk in chunks) {
          ios.add(chunk);
        }
        await ios.close();

        setState(() {
          _downloadStatus = 'Launching installer...';
        });

        await Future.delayed(const Duration(milliseconds: 1000));

        if (Platform.isWindows) {
          // Native detached process execution on Windows
          await Process.start(tempFile.path, [], mode: ProcessStartMode.detached);
          exit(0); // Exit app to let the installer replace active executable files
        } else if (Platform.isAndroid) {
          // Native Android OTA package installer execution
          const channel = MethodChannel('com.rottymusic.rotty_music/ota');
          await channel.invokeMethod('installApk', {'path': tempFile.path});
          exit(0);
        } else {
          // On other platforms, fallback to launching the file URI handler
          final fileUri = Uri.file(tempFile.path);
          await launchUrl(fileUri, mode: LaunchMode.externalApplication);
        }
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _downloadStatus = '';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'In-app download failed: $e. Launching website...',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      
      // Fallback to launching the browser update
      await _launchWebsite();
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateInfo = UpdateService.instance.latestUpdate;
    final downloadUrl = updateInfo?.downloadUrl ?? 'https://kukkiverse.github.io/website/';
    
    // Automatically determine if direct binary link is available for automatic installation
    final isDirectLink = downloadUrl.toLowerCase().endsWith('.exe') || 
                         downloadUrl.toLowerCase().endsWith('.msi') ||
                         downloadUrl.toLowerCase().endsWith('.apk');

    return PopScope(
      canPop: false, // Absolutely block back button on Android
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        body: Stack(
          children: [
            // Backdrop blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(color: Colors.transparent),
              ),
            ),
            // Glass content card
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.25),
                        blurRadius: 32,
                        spreadRadius: -4,
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Warning Glowing Icon
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.system_update_rounded,
                          color: AppColors.accent,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Outfit Bold Title
                      Text(
                        'UPDATE REQUIRED',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Persuasive message
                      Text(
                        'To continue enjoying seamless, high-fidelity music streaming and secure synchronization, you must upgrade Rotty to the latest version. This update contains critical performance boosts and brand new custom layouts.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      if (_isDownloading) ...[
                        // Downloading progress visualizers
                        Text(
                          _downloadStatus,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _downloadProgress > 0 ? _downloadProgress : null,
                            minHeight: 8,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                          ),
                        ),
                      ] else ...[
                        // Glowing dynamic checkout action
                        Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: AppColors.accentGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.45),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: FilledButton(
                            onPressed: () {
                              if ((Platform.isWindows || Platform.isAndroid) && isDirectLink) {
                                _startAutomaticUpdate(downloadUrl);
                              } else {
                                _launchWebsite();
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              (Platform.isWindows || Platform.isAndroid) && isDirectLink 
                                  ? 'Install Update Automatically ⚡' 
                                  : 'Download Update Now ⚡',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
