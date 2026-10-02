import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/korai_enums.dart';
import '../korai_tokens.dart';
import 'k_pills.dart';

/// Dessine l'onde Korai : une sinusoïde enveloppée jusqu'à [progress], puis un
/// trait plat pour la partie restante.
class KWavePainter extends CustomPainter {
  KWavePainter({
    required this.amplitude,
    required this.cycles,
    required this.progress,
    required this.color,
    required this.restColor,
    this.strokeWidth = 2.6,
    this.dashed = false,
    this.phase = 0,
    this.knob = true,
  });

  final double amplitude;
  final double cycles;
  final double progress;
  final Color color;
  final Color restColor;
  final double strokeWidth;
  final bool dashed;
  final double phase;
  final bool knob;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final mid = size.height / 2;
    final inset = strokeWidth;
    final end = (w * progress.clamp(0.0, 1.0)).clamp(inset, w - inset);

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (double x = inset; x <= end; x += 1.5) {
      final t = x / w;
      final env = math.sin(math.pi * t);
      final y = mid - amplitude * env * math.sin(2 * math.pi * cycles * t - phase);
      if (x == inset) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    if (dashed) {
      _drawDashed(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }

    if (progress < 1) {
      final rest = Paint()
        ..color = restColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(end, mid), Offset(w - inset, mid), rest);
      if (knob) {
        canvas.drawCircle(Offset(end, mid), strokeWidth * 1.7, Paint()..color = color);
      }
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(KWavePainter old) =>
      old.amplitude != amplitude ||
      old.progress != progress ||
      old.color != color ||
      old.phase != phase ||
      old.dashed != dashed ||
      old.restColor != restColor;
}

/// Barre de progression du parcours de consultation : sa longueur suit les
/// étapes, son amplitude et sa couleur suivent l'urgence estimée.
class KWaveProgress extends StatelessWidget {
  const KWaveProgress({
    super.key,
    required this.progress,
    required this.urgency,
    this.height = 26,
    this.semanticLabel,
  });

  final double progress;
  final UrgencyLevel? urgency;
  final double height;
  final String? semanticLabel;

  static double amplitudeFor(UrgencyLevel? u) => switch (u) {
        null => 2.5,
        UrgencyLevel.low => 3.5,
        UrgencyLevel.medium => 6.5,
        UrgencyLevel.high => 9.5,
      };

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final color = urgency == null ? k.brand : KUrgency.color(context, urgency);
    final duration = KMotion.of(context, KMotion.slow);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: amplitudeFor(urgency)),
          duration: duration,
          curve: Curves.easeOutBack,
          builder: (context, amp, _) => TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: duration,
            curve: KMotion.enter,
            builder: (context, p, _) => TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: color),
              duration: duration,
              builder: (context, c, _) => SizedBox(
                height: height,
                width: double.infinity,
                child: CustomPaint(
                  painter: KWavePainter(
                    amplitude: amp,
                    cycles: 10,
                    progress: p,
                    color: c ?? color,
                    restColor: k.line,
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

enum KSyncWaveState { offline, syncing, pending }

/// Petite onde de la pastille de synchronisation : plate en pointillés hors
/// ligne, en mouvement pendant l'envoi.
class KSyncWave extends StatefulWidget {
  const KSyncWave({super.key, required this.state, this.color, this.width = 34, this.height = 12});

  final KSyncWaveState state;
  final Color? color;
  final double width;
  final double height;

  @override
  State<KSyncWave> createState() => _KSyncWaveState();
}

class _KSyncWaveState extends State<KSyncWave> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  void _sync() {
    final animate = widget.state == KSyncWaveState.syncing && !KMotion.reduced(context);
    if (animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(KSyncWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.k.inkMuted;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size(widget.width, widget.height),
          painter: KWavePainter(
            amplitude: widget.state == KSyncWaveState.offline ? 0 : widget.height * 0.32,
            cycles: 2,
            progress: 1,
            color: color,
            restColor: color,
            strokeWidth: 1.8,
            dashed: widget.state == KSyncWaveState.offline,
            phase: _c.value * 2 * math.pi,
            knob: false,
          ),
        ),
      ),
    );
  }
}
