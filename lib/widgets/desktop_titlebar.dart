import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class DesktopTitlebar extends StatefulWidget implements PreferredSizeWidget {
  const DesktopTitlebar({super.key});

  @override
  State<DesktopTitlebar> createState() => _DesktopTitlebarState();

  @override
  Size get preferredSize => const Size.fromHeight(40);
}

class _DesktopTitlebarState extends State<DesktopTitlebar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximizedState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximizedState() async {
    final max = await windowManager.isMaximized();
    if (mounted) {
      setState(() {
        _isMaximized = max;
      });
    }
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: Color(0x1AFFFFFF),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        children: [
          // Drag handle that covers the entire bar
          const Positioned.fill(
            child: DragToMoveArea(
              child: SizedBox.expand(),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side logo
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.accentGradient,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ROTTY MUSIC',
                        style: GoogleFonts.outfit(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  // Right side window control buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Minimize button
                      _FunkyTitlebarButton(
                        icon: Icons.remove_rounded,
                        glowColor: const Color(0xFF00D4FF), // Neon Cyan
                        onPressed: () => windowManager.minimize(),
                        type: _FunkyButtonType.minimize,
                      ),
                      // Maximize / Restore button
                      _FunkyTitlebarButton(
                        icon: _isMaximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
                        iconSize: 10,
                        glowColor: const Color(0xFF7B61FF), // Neon Purple
                        onPressed: () async {
                          if (await windowManager.isMaximized()) {
                            windowManager.unmaximize();
                          } else {
                            windowManager.maximize();
                          }
                        },
                        type: _FunkyButtonType.maximize,
                      ),
                      // Close button
                      _FunkyTitlebarButton(
                        icon: Icons.close_rounded,
                        glowColor: const Color(0xFFFA2D48), // Neon Red
                        onPressed: () => windowManager.close(),
                        type: _FunkyButtonType.close,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _FunkyButtonType { minimize, maximize, close }

class _FunkyTitlebarButton extends StatefulWidget {
  const _FunkyTitlebarButton({
    required this.icon,
    required this.onPressed,
    required this.glowColor,
    required this.type,
    this.iconSize = 12,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color glowColor;
  final _FunkyButtonType type;
  final double iconSize;

  @override
  State<_FunkyTitlebarButton> createState() => _FunkyTitlebarButtonState();
}

class _FunkyTitlebarButtonState extends State<_FunkyTitlebarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Determine rotation turns for hover state
    double turns = 0.0;
    if (_isHovered) {
      if (widget.type == _FunkyButtonType.close) {
        turns = 0.25; // 90 degrees rotation
      } else if (widget.type == _FunkyButtonType.maximize) {
        turns = 0.5; // 180 degrees rotation
      }
    }

    // Determine translation offset for minimize button bounce
    double translateY = 0.0;
    if (_isHovered && widget.type == _FunkyButtonType.minimize) {
      translateY = 1.5;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 32,
          height: 32,
          color: Colors.transparent, // Expand hit test area
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            width: _isHovered ? 26 : 13,
            height: _isHovered ? 26 : 13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isHovered
                  ? widget.glowColor.withValues(alpha: 0.15)
                  : widget.glowColor.withValues(alpha: 0.8),
              border: Border.all(
                color: _isHovered
                    ? widget.glowColor
                    : widget.glowColor.withValues(alpha: 0.3),
                width: _isHovered ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? widget.glowColor.withValues(alpha: 0.6)
                      : widget.glowColor.withValues(alpha: 0.2),
                  blurRadius: _isHovered ? 10 : 5,
                  spreadRadius: _isHovered ? 1.0 : 0.5,
                )
              ],
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _isHovered ? 1.0 : 0.0,
              child: Center(
                child: AnimatedRotation(
                  turns: turns,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    transform: Matrix4.translationValues(0, translateY, 0),
                    child: Icon(
                      widget.icon,
                      size: widget.iconSize,
                      color: widget.glowColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
