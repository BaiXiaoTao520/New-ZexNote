import 'dart:math' as math;

import 'package:flutter/material.dart';

class WaveProgressIndicator extends StatefulWidget {
  final double? value;
  final double height;
  final Color? color;
  final Color? trackColor;

  const WaveProgressIndicator({
    super.key,
    this.value,
    this.height = 12,
    this.color,
    this.trackColor,
  }) : assert(value == null || (value >= 0 && value <= 1));

  @override
  State<WaveProgressIndicator> createState() => _WaveProgressIndicatorState();
}

class _WaveProgressIndicatorState extends State<WaveProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => CustomPaint(
            painter: _WaveProgressPainter(
              phase: controller.value,
              value: widget.value,
              color: widget.color ?? colorScheme.primary,
              trackColor: widget.trackColor ?? colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveProgressPainter extends CustomPainter {
  final double phase;
  final double? value;
  final Color color;
  final Color trackColor;

  const _WaveProgressPainter({
    required this.phase,
    required this.value,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = math.max(3.0, size.height * 0.56).toDouble();
    final centerY = size.height / 2;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(strokeWidth / 2, centerY),
      Offset(size.width - strokeWidth / 2, centerY),
      trackPaint,
    );

    final availableWidth = math.max(0.0, size.width - strokeWidth).toDouble();
    final waveWidth = (value == null
        ? math.min(availableWidth * 0.45, 96.0)
        : availableWidth * value!).toDouble();
    if (waveWidth <= 0) return;

    final startX = value == null
        ? strokeWidth / 2 + (availableWidth + waveWidth) * phase - waveWidth
        : strokeWidth / 2;
    final endX = math.min(size.width - strokeWidth / 2, startX + waveWidth).toDouble();
    final clippedStartX = math.max(strokeWidth / 2, startX).toDouble();
    if (endX <= clippedStartX) return;

    final wavePath = Path();
    const segment = 2.0;
    final amplitude = math.max(1.0, strokeWidth * 0.22).toDouble();
    for (var x = clippedStartX; x <= endX; x += segment) {
      final y = centerY + math.sin((x * 0.18) + phase * math.pi * 2) * amplitude;
      if (x == clippedStartX) {
        wavePath.moveTo(x, y);
      } else {
        wavePath.lineTo(x, y);
      }
    }
    final finalY = centerY + math.sin((endX * 0.18) + phase * math.pi * 2) * amplitude;
    wavePath.lineTo(endX, finalY);

    final wavePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _WaveProgressPainter oldDelegate) {
    return phase != oldDelegate.phase ||
        value != oldDelegate.value ||
        color != oldDelegate.color ||
        trackColor != oldDelegate.trackColor;
  }
}
