import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RottyMixtapeCollage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final double borderRadius;

  const RottyMixtapeCollage({
    super.key,
    required this.imageUrl,
    this.width = 250,
    this.height = 250,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (!imageUrl.startsWith('collage:')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => Container(
            width: width,
            height: height,
            color: Colors.white.withOpacity(0.05),
            child: const Icon(Icons.music_note_rounded, color: Colors.white24, size: 40),
          ),
        ),
      );
    }

    final urls = imageUrl.replaceFirst('collage:', '').split(',');
    if (urls.isEmpty || urls[0].isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: const Icon(Icons.music_note_rounded, color: Colors.white24, size: 40),
      );
    }

    // Stacked Fan-out Collage Deck Layout
    final primaryImg = urls[0];
    final secondaryImg = urls.length > 1 ? urls[1] : null;
    final tertiaryImg = urls.length > 2 ? urls[2] : null;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. Blur background using primary image for deep contrast and glow
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Stack(
                children: [
                  Image.network(
                    primaryImg,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                    child: Container(
                      color: Colors.black.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Tertiary Track (tilted left, backmost layer)
          if (tertiaryImg != null)
            Transform.translate(
              offset: Offset(-width * 0.15, -height * 0.02),
              child: Transform.rotate(
                angle: -0.15,
                child: Transform.scale(
                  scale: 0.8,
                  child: _buildArtworkCard(tertiaryImg, 3),
                ),
              ),
            ),

          // 3. Secondary Track (tilted right)
          if (secondaryImg != null)
            Transform.translate(
              offset: Offset(width * 0.15, -height * 0.02),
              child: Transform.rotate(
                angle: 0.15,
                child: Transform.scale(
                  scale: 0.8,
                  child: _buildArtworkCard(secondaryImg, 2),
                ),
              ),
            ),

          // 4. Primary Track (center, straight, foremost layer)
          Transform.scale(
            scale: 0.88,
            child: _buildArtworkCard(primaryImg, 1, isPrimary: true),
          ),

          // 5. Aesthetic Neon "MASHUP" badge
          Positioned(
            bottom: height * 0.06,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.6)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withOpacity(0.25),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF00D4FF), size: 10),
                  const SizedBox(width: 4),
                  Text(
                    'AI MASHUP SINGLE',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkCard(String url, int index, {bool isPrimary = false}) {
    return Container(
      width: width * 0.76,
      height: height * 0.76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(isPrimary ? 0.3 : 0.1),
          width: isPrimary ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isPrimary ? 0.6 : 0.35),
            blurRadius: isPrimary ? 20 : 10,
            spreadRadius: isPrimary ? 2 : 0,
            offset: Offset(0, isPrimary ? 10 : 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade900,
            child: const Icon(Icons.music_note, color: Colors.white24),
          ),
        ),
      ),
    );
  }
}
