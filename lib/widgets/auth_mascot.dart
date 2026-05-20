import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

enum AuthMascotMode { idle, watching, blind }

/// ROTTY buddy — serious when you type email/phone, eyes shut on password.
class AuthMascot extends StatefulWidget {
  const AuthMascot({super.key, required this.mode, this.size = 140});

  final AuthMascotMode mode;
  final double size;

  @override
  State<AuthMascot> createState() => _AuthMascotState();
}

class _AuthMascotState extends State<AuthMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) {
        final dy = (widget.mode == AuthMascotMode.watching) ? 0.0 : _bob.value * 6 - 3;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _MascotPainter(mode: widget.mode),
        ),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  _MascotPainter({required this.mode});

  final AuthMascotMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.38;

    final body = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFA2D48), Color(0xFFFF6B8A)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, body);

    final ear = Paint()..color = const Color(0xFFE0243F);
    canvas.drawCircle(Offset(cx - r * 0.85, cy - r * 0.55), r * 0.22, ear);
    canvas.drawCircle(Offset(cx + r * 0.85, cy - r * 0.55), r * 0.22, ear);

    final cheek = Paint()..color = Colors.white.withValues(alpha: 0.15);
    canvas.drawCircle(Offset(cx - r * 0.55, cy + r * 0.15), r * 0.18, cheek);
    canvas.drawCircle(Offset(cx + r * 0.55, cy + r * 0.15), r * 0.18, cheek);

    final browY = cy - r * 0.35;
    final brow = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    if (mode == AuthMascotMode.watching) {
      canvas.drawLine(Offset(cx - r * 0.42, browY - 4), Offset(cx - r * 0.12, browY - 10), brow);
      canvas.drawLine(Offset(cx + r * 0.12, browY - 10), Offset(cx + r * 0.42, browY - 4), brow);
    } else {
      canvas.drawLine(Offset(cx - r * 0.4, browY), Offset(cx - r * 0.1, browY - 2), brow);
      canvas.drawLine(Offset(cx + r * 0.1, browY - 2), Offset(cx + r * 0.4, browY), brow);
    }

    final eyeY = cy - r * 0.05;
    if (mode == AuthMascotMode.blind) {
      final lid = Paint()
        ..color = Colors.white
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx - r * 0.28, eyeY), width: r * 0.38, height: r * 0.2),
        0,
        3.14,
        false,
        lid,
      );
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx + r * 0.28, eyeY), width: r * 0.38, height: r * 0.2),
        0,
        3.14,
        false,
        lid,
      );
    } else {
      final pupil = Paint()..color = Colors.white;
      final iris = Paint()..color = AppColors.bg;
      final eyeR = mode == AuthMascotMode.watching ? r * 0.14 : r * 0.11;
      for (final dx in [-r * 0.28, r * 0.28]) {
        canvas.drawCircle(Offset(cx + dx, eyeY), eyeR, pupil);
        canvas.drawCircle(Offset(cx + dx + (mode == AuthMascotMode.watching ? 2 : 0), eyeY), eyeR * 0.55, iris);
      }
    }

    final mouth = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    if (mode == AuthMascotMode.watching) {
      canvas.drawLine(Offset(cx - r * 0.12, cy + r * 0.35), Offset(cx + r * 0.12, cy + r * 0.35), mouth);
    } else {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy + r * 0.38), width: r * 0.35, height: r * 0.18),
        0.1,
        3.0,
        false,
        mouth,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MascotPainter old) => old.mode != mode;
}
