import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design.dart';
import '../domain/korai_enums.dart';
import 'ear_side_selector.dart';

/// Étape « image de l'oreille » : choix de l'oreille, viseur rond pour cadrer
/// le tympan, retouches simples et description facultative.
class OrlImageCaptureStep extends StatelessWidget {
  const OrlImageCaptureStep({
    super.key,
    required this.image,
    required this.isEditing,
    required this.earSide,
    required this.onEarSideChanged,
    required this.description,
    required this.onDescriptionChanged,
    required this.onCamera,
    required this.onGallery,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onFlipHorizontal,
    required this.onBrighten,
    required this.onDarken,
    required this.onRemove,
  });

  final File? image;
  final bool isEditing;
  final EarSide earSide;
  final ValueChanged<EarSide> onEarSideChanged;
  final String description;
  final ValueChanged<String> onDescriptionChanged;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onFlipHorizontal;
  final VoidCallback onBrighten;
  final VoidCallback onDarken;
  final VoidCallback onRemove;

  bool get hasImage => image != null;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EarSideSelector(value: earSide, onChanged: onEarSideChanged),
        const SizedBox(height: KSpace.lg),
        if (!hasImage) ...[
          Center(
            child: Semantics(
              button: true,
              label: 'Prendre la photo du tympan',
              child: GestureDetector(
                onTap: isEditing ? null : onCamera,
                child: const _Viewfinder(),
              ),
            ),
          ),
          const SizedBox(height: KSpace.sm),
          Text(
            'Centrez le tympan dans le cercle, puis prenez la photo. Une image nette et bien éclairée améliore l’analyse.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: k.inkMuted),
          ),
          const SizedBox(height: KSpace.lg),
          FilledButton.icon(
            onPressed: isEditing ? null : onCamera,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Prendre la photo'),
          ),
          const SizedBox(height: KSpace.xs),
          TextButton.icon(
            onPressed: isEditing ? null : onGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choisir dans la galerie'),
          ),
          const SizedBox(height: KSpace.xs),
          KBanner(
            tone: KTone.neutral,
            icon: Icons.info_outline_rounded,
            message: 'La photo est facultative : sans elle, l’analyse porte sur les symptômes seulement.',
          ),
        ] else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 320),
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.file(image!, fit: BoxFit.contain, width: double.infinity),
                  ),
                ),
                if (isEditing)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black54,
                      child: KLoadingViewOnDark(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.xs),
          Text(
            'Pincez pour zoomer et vérifier la netteté.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
          const SizedBox(height: KSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: k.surface, borderRadius: KRadius.pillAll, border: Border.all(color: k.line)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Tool(icon: Icons.rotate_left_rounded, label: 'Pivoter à gauche', onPressed: isEditing ? null : onRotateLeft),
                _Tool(icon: Icons.rotate_right_rounded, label: 'Pivoter à droite', onPressed: isEditing ? null : onRotateRight),
                _Tool(icon: Icons.flip_rounded, label: 'Retourner (miroir)', onPressed: isEditing ? null : onFlipHorizontal),
                _Tool(icon: Icons.brightness_high_rounded, label: 'Éclaircir', onPressed: isEditing ? null : onBrighten),
                _Tool(icon: Icons.brightness_low_rounded, label: 'Assombrir', onPressed: isEditing ? null : onDarken),
              ],
            ),
          ),
          const SizedBox(height: KSpace.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isEditing ? null : onCamera,
                  icon: const Icon(Icons.photo_camera_outlined, size: 20),
                  label: const Text('Reprendre'),
                ),
              ),
              const SizedBox(width: KSpace.sm),
              Expanded(
                child: TextButton.icon(
                  onPressed: isEditing ? null : onRemove,
                  style: TextButton.styleFrom(foregroundColor: k.danger),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: const Text('Retirer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpace.md),
          TextFormField(
            initialValue: description,
            onChanged: onDescriptionChanged,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Ce que vous voyez (facultatif)',
              hintText: 'Exemple : tympan rouge et bombé, écoulement jaunâtre…',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ],
    );
  }
}

/// Chargement blanc sur fond sombre (retouche d'image en cours).
class KLoadingViewOnDark extends StatelessWidget {
  const KLoadingViewOnDark({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
          SizedBox(height: 10),
          Text('Retouche en cours…', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon),
      color: context.k.brand,
    );
  }
}

/// Viseur d'otoscope : disque sombre, cercle de cadrage en pointillés.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(
        painter: _ViewfinderPainter(bg: k.hero, ring: k.onHeroMuted, tick: k.aqua),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_camera_outlined, color: k.onHero, size: 34),
              const SizedBox(height: 6),
              Text('Toucher pour\nphotographier', textAlign: TextAlign.center, style: context.text.labelMedium?.copyWith(color: k.onHero)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter({required this.bg, required this.ring, required this.tick});

  final Color bg;
  final Color ring;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = bg);
    final dash = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const segments = 48;
    final ringR = r - 16;
    for (var i = 0; i < segments; i += 2) {
      final a0 = 2 * math.pi * i / segments;
      final a1 = 2 * math.pi * (i + 1) / segments;
      canvas.drawArc(Rect.fromCircle(center: c, radius: ringR), a0, a1 - a0, false, dash);
    }
    final t = Paint()
      ..color = tick
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final a = math.pi / 2 * i;
      final p0 = c + Offset(math.cos(a), math.sin(a)) * (ringR - 10);
      final p1 = c + Offset(math.cos(a), math.sin(a)) * (ringR + 6);
      canvas.drawLine(p0, p1, t);
    }
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) => old.bg != bg || old.ring != ring || old.tick != tick;
}
