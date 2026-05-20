import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../services/firebase_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/rotty_glass.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _signUp = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_signUp) {
        await FirebaseService.instance.signUpWithEmail(
          email: email,
          password: pass,
          phone: _phoneCtrl.text.trim(),
          displayName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        );
      } else {
        await FirebaseService.instance.signInWithEmail(email, pass);
      }
      await StorageService().setAuthSessionDone();
      if (!mounted) return;
      _goNext();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _authMessage(e));
    } catch (_) {
      setState(() => _error = 'Connection issue. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _guest() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseService.instance.signInAsGuest();
    } catch (_) {}
    await StorageService().setAuthSessionDone();
    if (mounted) _goNext();
  }

  void _goNext() {
    final storage = StorageService();
    context.go(storage.isOnboardingDone ? '/home' : '/onboarding');
  }

  String _authMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'email-already-in-use' => 'Email already registered — Sign in instead',
      'user-not-found' => 'No account found — Sign up first',
      'wrong-password' => 'Incorrect password',
      'invalid-email' => 'Invalid email address',
      'weak-password' => 'Password is too weak',
      _ => e.message ?? 'Authentication failed',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  _brandHeader(),
                  const SizedBox(height: 32),
                  RottyGlass(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _signUp ? 'Create account' : 'Sign in',
                          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sync favorites & streak across devices',
                          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        if (_signUp) ...[
                          _field(controller: _nameCtrl, label: 'Name', icon: Icons.person_outline_rounded),
                          const SizedBox(height: 12),
                        ],
                        _field(
                          controller: _emailCtrl,
                          label: 'Email',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _phoneCtrl,
                          label: 'Phone (optional)',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _passCtrl,
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.textTertiary,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: GoogleFonts.inter(color: AppColors.accent, fontSize: 12)),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    _signUp ? 'Sign up' : 'Sign in',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : () => setState(() => _signUp = !_signUp),
                          child: Text(
                            _signUp ? 'Have an account? Sign in' : 'New here? Create account',
                            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _busy ? null : _guest,
                    child: Text('Continue as guest', style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: AppColors.accentGradient,
            boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 38),
        ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.92, 0.92), curve: Curves.easeOutBack),
        const SizedBox(height: 20),
        Text(
          'ROTTY',
          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 6),
        ),
        Text('MUSIC', style: GoogleFonts.inter(fontSize: 12, color: AppColors.accent, letterSpacing: 10, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.bg.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.glassBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
    );
  }
}
