import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// 3D album stage — gyro parallax + depth blur shadow.
class AlbumStage3D extends StatefulWidget {
  const AlbumStage3D({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.size,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onVerticalDragEnd,
    this.child,
  });

  final String imageUrl;
  final String heroTag;
  final double? size;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(DragEndDetails)? onVerticalDragEnd;
  final Widget? child;

  @override
  State<AlbumStage3D> createState() => _AlbumStage3DState();
}

class _AlbumStage3DState extends State<AlbumStage3D> {
  double _tiltX = 0;
  double _tiltY = 0;
  StreamSubscription<AccelerometerEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        _subscription = accelerometerEventStream().listen((e) {
          if (!mounted) return;
          setState(() {
            _tiltX = (e.x.clamp(-8.0, 8.0) / 8) * 0.12;
            _tiltY = (e.y.clamp(-8.0, 8.0) / 8) * 0.12;
          });
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? MediaQuery.of(context).size.width - 56;

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      onLongPress: widget.onLongPress,
      onVerticalDragEnd: widget.onVerticalDragEnd,
      onPanUpdate: (d) {
        setState(() {
          _tiltY += d.delta.dx * 0.0008;
          _tiltX -= d.delta.dy * 0.0008;
          _tiltX = _tiltX.clamp(-0.15, 0.15);
          _tiltY = _tiltY.clamp(-0.15, 0.15);
        });
      },
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0018)
          ..rotateX(_tiltX)
          ..rotateY(_tiltY),
        child: Hero(
          tag: widget.heroTag,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Stage shadow / depth
              Positioned(
                left: size * 0.08,
                top: size * 0.12,
                child: Container(
                  width: size * 0.85,
                  height: size * 0.08,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 800,
                        placeholder: (context, url) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.purple.withValues(alpha: 0.2), Colors.blue.withValues(alpha: 0.2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.album_rounded, color: Colors.white24, size: 48),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.purple.withValues(alpha: 0.4), Colors.blue.withValues(alpha: 0.4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.album_rounded, color: Colors.white30, size: 48),
                          ),
                        ),
                      ),
                      // Depth blur vignette
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.1,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.25),
                            ],
                          ),
                        ),
                      ),
                      if (widget.child != null) widget.child!,
                    ],
                  ),
                ),
              ),
              // Specular edge
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.transparent,
                          Colors.transparent,
                        ],
                        stops: const [0, 0.35, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact 3D tile for mini player.
class MiniAlbumTile3D extends StatelessWidget {
  const MiniAlbumTile3D({super.key, required this.imageUrl, required this.heroTag});

  final String imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.002)
        ..rotateX(-0.08)
        ..rotateY(0.06),
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            memCacheWidth: 128,
            placeholder: (context, url) => Container(
              color: Colors.white10,
              child: const Icon(Icons.album_rounded, color: Colors.white24, size: 24),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.white10,
              child: const Icon(Icons.album_rounded, color: Colors.white30, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
