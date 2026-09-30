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
    this.height = 10,
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
      duration: const Duration(milliseconds: 1500),
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
              trackColor: widget.trackColor ?? colorScheme.primaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class WaveCircularProgressIndicator extends StatefulWidget {
  final double size;
  final Color? color;

  const WaveCircularProgressIndicator({
    super.key,
    this.size = 48,
    this.color,
  });

  @override
  State<WaveCircularProgressIndicator> createState() => _WaveCircularProgressIndicatorState();
}

class _WaveCircularProgressIndicatorState extends State<WaveCircularProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => CustomPaint(
            painter: _WaveCircularProgressPainter(
              phase: controller.value,
              color: widget.color ?? Theme.of(context).colorScheme.primary,
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
    final radius = size.height / 2;
    final trackRect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.drawRRect(trackRect, Paint()..color = trackColor);

    final waveWidth = value == null
        ? math.min(size.width * 0.42, 120.0).toDouble()
        : size.width * value!;
    if (waveWidth <= 0) return;

    final startX = value == null ? (size.width + waveWidth) * phase - waveWidth : 0.0;
    final endX = math.min(size.width, startX + waveWidth).toDouble();
    final clippedStartX = math.max(0.0, startX).toDouble();
    if (endX <= clippedStartX) return;

    final wavePath = Path()..moveTo(clippedStartX, size.height);
    const step = 2.0;
    final amplitude = math.max(0.8, size.height * 0.10).toDouble();
    final centerY = size.height / 2;
    for (var x = clippedStartX; x <= endX; x += step) {
      final y = centerY + math.sin((x * 0.16) + phase * math.pi * 2) * amplitude;
      wavePath.lineTo(x, y);
    }
    wavePath
      ..lineTo(endX, size.height)
      ..close();

    canvas.save();
    canvas.clipRRect(trackRect);
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withAlpha(175), color.withAlpha(220)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawPath(wavePath, fillPaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha(48)
      ..strokeWidth = math.max(0.6, size.height * 0.055).toDouble()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(clippedStartX + radius, radius * 0.74),
      Offset(math.max(clippedStartX + radius, endX - radius).toDouble(), radius * 0.74),
      highlightPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WaveProgressPainter oldDelegate) {
    return phase != oldDelegate.phase ||
        value != oldDelegate.value ||
        color != oldDelegate.color ||
        trackColor != oldDelegate.trackColor;
  }
}

class _WaveCircularProgressPainter extends CustomPainter {
  final double phase;
  final Color color;

  const _WaveCircularProgressPainter({
    required this.phase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final orbitRadius = size.shortestSide * 0.31;
    final dotRadius = math.max(2.4, size.shortestSide * 0.075).toDouble();
    const count = 12;

    for (var index = 0; index < count; index++) {
      final position = (index / count + phase) % 1;
      final angle = position * math.pi * 2 - math.pi / 2;
      final emphasis = math.pow(1 - position, 2).toDouble();
      final radius = dotRadius * (0.7 + emphasis * 0.42);
      final dotColor = Color.lerp(color.withAlpha(55), color, emphasis)!;
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * orbitRadius,
          center.dy + math.sin(angle) * orbitRadius,
        ),
        radius,
        Paint()..color = dotColor,
      );
    }

    canvas.drawCircle(
      center,
      dotRadius * 0.78,
      Paint()..color = color.withAlpha(38),
    );
  }

  @override
  bool shouldRepaint(covariant _WaveCircularProgressPainter oldDelegate) {
    return phase != oldDelegate.phase || color != oldDelegate.color;
  }
}
