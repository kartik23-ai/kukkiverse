import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class PerspectiveCard extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isSquare;

  const PerspectiveCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isSquare = true,
  });

  @override
  State<PerspectiveCard> createState() => _PerspectiveCardState();
}

class _PerspectiveCardState extends State<PerspectiveCard> with SingleTickerProviderStateMixin {
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      onTap: widget.onTap,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 200),
        tween: Tween(begin: 1.0, end: _isHovered ? 0.95 : 1.0),
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 20),
              width: 170,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The 3D Image Container
                  Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002) // Perspective
                      ..rotateX(_rotationX)
                      ..rotateY(_rotationY),
                    alignment: FractionalOffset.center,
                    child: Container(
                      height: 170,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.isSquare ? 28 : 100),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonCyan.withAlpha(_isHovered ? 60 : 30),
                            blurRadius: _isHovered ? 30 : 20,
                            spreadRadius: _isHovered ? 5 : 0,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(widget.isSquare ? 28 : 100),
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: widget.imageUrl,
                              width: 170, height: 170,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: Colors.white10),
                            ),
                            // Glass Overlay on hover
                            if (_isHovered)
                              Container(
                                color: Colors.black.withAlpha(40),
                                child: const Center(
                                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 50),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Text Info
                  Text(
                    widget.title,
                    style: GoogleFonts.outfit(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.subtitle,
                    style: GoogleFonts.outfit(
                      color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
