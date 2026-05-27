import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/korai_enums.dart';
import 'ear_side_selector.dart';

class OrlImageCaptureStep extends StatelessWidget {
  const OrlImageCaptureStep({
    super.key,
    required this.image,
    required this.isEditing,
    required this.earSide,
    required this.onEarSideChanged,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EarSideSelector(value: earSide, onChanged: onEarSideChanged),
        const SizedBox(height: 16),
        if (!hasImage) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.camera_alt_outlined,
                    size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'Aucune photo otoscopique',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Prenez une photo claire du conduit auditif externe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: isEditing ? null : onCamera,
            icon: const Icon(Icons.camera),
            label: const Text('Prendre une photo'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: isEditing ? null : onGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choisir dans la galerie'),
          ),
        ] else ...[
          Text(
            'Aperçu de l\'image ORL',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 320),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.35),
                        width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.file(
                      image!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
              if (isEditing)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Retouches',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _RetouchButton(
                icon: Icons.rotate_left,
                label: 'Pivoter G',
                onPressed: isEditing ? null : onRotateLeft,
              ),
              _RetouchButton(
                icon: Icons.rotate_right,
                label: 'Pivoter D',
                onPressed: isEditing ? null : onRotateRight,
              ),
              _RetouchButton(
                icon: Icons.flip,
                label: 'Miroir',
                onPressed: isEditing ? null : onFlipHorizontal,
              ),
              _RetouchButton(
                icon: Icons.wb_sunny_outlined,
                label: 'Plus clair',
                onPressed: isEditing ? null : onBrighten,
              ),
              _RetouchButton(
                icon: Icons.brightness_2_outlined,
                label: 'Plus sombre',
                onPressed: isEditing ? null : onDarken,
              ),
              _RetouchButton(
                icon: Icons.delete_outline,
                label: 'Supprimer',
                onPressed: isEditing ? null : onRemove,
                isDestructive: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isEditing ? null : onCamera,
                  icon: const Icon(Icons.camera, size: 18),
                  label: const Text('Reprendre'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isEditing ? null : onGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Remplacer'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RetouchButton extends StatelessWidget {
  const _RetouchButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade700 : const Color(0xFF006D77);

    return Material(
      color: isDestructive ? Colors.red.shade50 : const Color(0xFFE8F1F2),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 20, color: onPressed == null ? Colors.grey : color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: onPressed == null ? Colors.grey : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
