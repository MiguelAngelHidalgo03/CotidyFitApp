import 'package:flutter/material.dart';

class CoordinatedHorizontalSwipe extends StatefulWidget {
  const CoordinatedHorizontalSwipe({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.distanceThreshold = 48,
    this.velocityThreshold = 280,
    this.behavior = HitTestBehavior.translucent,
  });

  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final double distanceThreshold;
  final double velocityThreshold;
  final HitTestBehavior behavior;

  @override
  State<CoordinatedHorizontalSwipe> createState() =>
      _CoordinatedHorizontalSwipeState();
}

class _CoordinatedHorizontalSwipeState
    extends State<CoordinatedHorizontalSwipe> {
  double _dragDelta = 0;

  void _handleDragStart(DragStartDetails details) {
    _dragDelta = 0;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _dragDelta += details.delta.dx;
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final draggedLeft = _dragDelta <= -widget.distanceThreshold;
    final draggedRight = _dragDelta >= widget.distanceThreshold;
    final flungLeft = velocity <= -widget.velocityThreshold;
    final flungRight = velocity >= widget.velocityThreshold;
    _dragDelta = 0;

    if (draggedLeft || flungLeft) {
      widget.onSwipeLeft?.call();
      return;
    }
    if (draggedRight || flungRight) {
      widget.onSwipeRight?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: widget.child,
    );
  }
}
