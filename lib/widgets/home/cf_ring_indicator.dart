import 'package:flutter/material.dart';

import '../../core/theme.dart';

class CfRingIndicator extends StatefulWidget {
  const CfRingIndicator({
    super.key,
    required this.value,
    this.size = 68,
  });

  final int value; // 0..100
  final double size;

  @override
  State<CfRingIndicator> createState() => _CfRingIndicatorState();
}

class _CfRingIndicatorState extends State<CfRingIndicator> {
  late int _from;

  @override
  void initState() {
    super.initState();
    _from = widget.value.clamp(0, 100);
  }

  @override
  void didUpdateWidget(covariant CfRingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _from = oldWidget.value.clamp(0, 100);
    }
  }

  @override
  Widget build(BuildContext context) {
    final to = widget.value.clamp(0, 100);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _from.toDouble(), end: to.toDouble()),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final progress = (v / 100).clamp(0.0, 1.0);
        final display = v.round().clamp(0, 100);

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 7,
                  backgroundColor: CFColors.softGray,
                  valueColor: const AlwaysStoppedAnimation(CFColors.primary),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(anim), child: child),
                ),
                child: Text(
                  '$display',
                  key: ValueKey(display),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: CFColors.primary,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
