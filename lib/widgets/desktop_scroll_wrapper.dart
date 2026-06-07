import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class DesktopScrollWrapper extends StatefulWidget {
  final Widget Function(BuildContext context, ScrollController controller, ScrollPhysics physics) builder;
  final ScrollController parentController;

  const DesktopScrollWrapper({
    super.key,
    required this.builder,
    required this.parentController,
  });

  @override
  State<DesktopScrollWrapper> createState() => _DesktopScrollWrapperState();
}

class _DesktopScrollWrapperState extends State<DesktopScrollWrapper> with SingleTickerProviderStateMixin {
  late final ScrollController _controller;
  late final Ticker _ticker;
  
  double? _targetVerticalOffset;
  double? _targetHorizontalOffset;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    bool verticalAnimating = false;
    bool horizontalAnimating = false;

    if (_targetVerticalOffset != null && widget.parentController.hasClients) {
      final current = widget.parentController.offset;
      final target = _targetVerticalOffset!;
      if ((target - current).abs() > 0.5) {
        // Smooth lerp (20% step size per frame)
        final next = current + (target - current) * 0.20;
        widget.parentController.jumpTo(next);
        verticalAnimating = true;
      } else {
        widget.parentController.jumpTo(target);
        _targetVerticalOffset = null;
      }
    }

    if (_targetHorizontalOffset != null && _controller.hasClients) {
      final current = _controller.offset;
      final target = _targetHorizontalOffset!;
      if ((target - current).abs() > 0.5) {
        // Smooth lerp (25% step size per frame)
        final next = current + (target - current) * 0.25;
        _controller.jumpTo(next);
        horizontalAnimating = true;
      } else {
        _controller.jumpTo(target);
        _targetHorizontalOffset = null;
      }
    }

    if (!verticalAnimating && !horizontalAnimating) {
      _ticker.stop();
    }
  }

  void _handleVerticalScroll(double dy) {
    if (!widget.parentController.hasClients) return;
    
    final position = widget.parentController.position;
    final currentTarget = _targetVerticalOffset ?? widget.parentController.offset;
    
    _targetVerticalOffset = (currentTarget + dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _handleHorizontalScroll(double dx) {
    if (!_controller.hasClients) return;

    final position = _controller.position;
    final currentTarget = _targetHorizontalOffset ?? _controller.offset;

    _targetHorizontalOffset = (currentTarget + dx).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          final dy = pointerSignal.scrollDelta.dy;
          final dx = pointerSignal.scrollDelta.dx;
          
          if (dy != 0) {
            _handleVerticalScroll(dy);
          } else if (dx != 0) {
            _handleHorizontalScroll(dx);
          }
        }
      },
      child: widget.builder(context, _controller, const NeverScrollableScrollPhysics()),
    );
  }
}
