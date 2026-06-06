import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/storage_service.dart';

class ContactSupportScreen extends ConsumerStatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  ConsumerState<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends ConsumerState<ContactSupportScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _messageCtrl = TextEditingController();
  String _category = 'Bug Report';

  final List<String> _categories = [
    'Bug Report',
    'Feature Request',
    'General Inquiry',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = StorageService().profileEmail;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    final email = _emailCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Please enter your email address.',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Please enter your message.',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    final mailtoUri = Uri(
      scheme: 'mailto',
      path: 'kartikchauhan0509@gmail.com',
      queryParameters: {
        'subject': '[Rotty Music Support] $_category',
        'body': 'From: $email\nCategory: $_category\n\nMessage:\n$message\n\n---\nSent from Rotty Music App',
      },
    );

    try {
      final launched = await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw 'Could not launch mail client';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.greenAccent,
            content: Text(
              'Opening your email app... 🚀',
              style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF16162A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              'Email App Not Found',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900),
            ),
            content: Text(
              'Hum default mail app ko open nahi kar paaye.\n\nKripya apna message is email par manually send karein:\n\nkartikchauhan0509@gmail.com',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK', style: GoogleFonts.inter(color: AppColors.accent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: Stack(
        children: [
          // Elegant Aurora Gradient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.meshTop,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium Navigation Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'HELP & SUPPORT',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Header info card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withValues(alpha: 0.03),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.support_agent_rounded, color: AppColors.accent, size: 24),
                                const SizedBox(width: 10),
                                Text(
                                  'Contact Kartik 🤝',
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Rotty Music ke regarding koi bhi question, query, bug report ya suggestions hain? Form fill karke message bhejein, ye directly Kartik ke email inbox par deliver ho jayega.',
                              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12.5, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Your email field
                      Text(
                        'YOUR EMAIL ADDRESS',
                        style: GoogleFonts.inter(color: AppColors.textTertiary, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'e.g. user@gmail.com',
                          hintStyle: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 13),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Category Selection
                      Text(
                        'SELECT CATEGORY',
                        style: GoogleFonts.inter(color: AppColors.textTertiary, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _category,
                            dropdownColor: const Color(0xFF16162A),
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            isExpanded: true,
                            onChanged: (String? val) {
                              if (val != null) {
                                setState(() => _category = val);
                              }
                            },
                            items: _categories.map((c) {
                              return DropdownMenuItem<String>(
                                value: c,
                                child: Text(c),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Message
                      Text(
                        'MESSAGE DETAIL',
                        style: GoogleFonts.inter(color: AppColors.textTertiary, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _messageCtrl,
                        maxLines: 8,
                        minLines: 5,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Aapka message yahan likhein...',
                          hintStyle: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 13),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Send Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _sendEmail,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 8,
                            shadowColor: AppColors.accent.withValues(alpha: 0.3),
                          ),
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          label: Text(
                            'Compose & Send Email ✉️',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
