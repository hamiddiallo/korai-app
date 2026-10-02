import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_client.dart';
import '../design/design.dart';
import '../../features/nurse/domain/ai_case.dart';

/// Charge les photos du tympan (route protégée du serveur). Garde les
/// dernières en mémoire pour ne pas les retélécharger à chaque affichage ;
/// rien n'est écrit sur l'appareil, et tout est oublié à la déconnexion.
class ProtectedImageLoader {
  ProtectedImageLoader(this._load, {this.capacity = 12});

  /// Chargeur réel : `ProtectedImageLoader.api(apiClient)`.
  factory ProtectedImageLoader.api(ApiClient apiClient) => ProtectedImageLoader(apiClient.getBytes);

  final Future<Uint8List> Function(String url) _load;
  final int capacity;
  final _cache = <String, Uint8List>{};
  final _inFlight = <String, Future<Uint8List>>{};

  Future<Uint8List> load(String url) {
    final cached = _cache.remove(url);
    if (cached != null) {
      _cache[url] = cached; // le plus récemment vu passe en dernier
      return Future.value(cached);
    }
    return _inFlight[url] ??= _load(url).then((bytes) {
      _cache[url] = bytes;
      while (_cache.length > capacity) {
        _cache.remove(_cache.keys.first);
      }
      return bytes;
    }).whenComplete(() {
      // Bloc sans valeur de retour : renvoyer le futur retiré ferait attendre
      // `whenComplete` sur lui-même (chargement sans fin).
      _inFlight.remove(url);
    });
  }

  /// À la déconnexion : aucune photo ne reste en mémoire pour le compte suivant.
  void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}

/// Photos du tympan d'une consultation, à toucher pour agrandir.
class OtoscopyPhotos extends StatelessWidget {
  const OtoscopyPhotos({super.key, required this.images});

  final List<CaseImage> images;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final image in images) ...[
          OtoscopyPhotoCard(image: image),
          const SizedBox(height: KSpace.sm),
        ],
      ],
    );
  }
}

class OtoscopyPhotoCard extends StatefulWidget {
  const OtoscopyPhotoCard({super.key, required this.image});

  final CaseImage image;

  @override
  State<OtoscopyPhotoCard> createState() => _OtoscopyPhotoCardState();
}

class _OtoscopyPhotoCardState extends State<OtoscopyPhotoCard> {
  late Future<Uint8List> _photo = _load();

  Future<Uint8List> _load() => context.read<ProtectedImageLoader>().load(widget.image.url);

  void _retry() {
    final next = _load();
    setState(() {
      _photo = next;
    });
  }

  void _openFullScreen(Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenPhoto(bytes: bytes, title: 'Tympan · ${widget.image.earSide.label}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final ear = widget.image.earSide.label;
    return KCard(
      padding: const EdgeInsets.all(KSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera_outlined, size: 18, color: k.inkMuted),
              const SizedBox(width: KSpace.xs),
              Expanded(child: Text('Photo du tympan · $ear', style: context.text.titleSmall)),
            ],
          ),
          const SizedBox(height: KSpace.xs),
          ClipRRect(
            borderRadius: KRadius.controlAll,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: ColoredBox(
                color: k.hero,
                child: FutureBuilder<Uint8List>(
                  future: _photo,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(KSpace.md),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_outlined, color: k.onHeroMuted, size: 32),
                              const SizedBox(height: KSpace.xs),
                              Text(
                                friendlyError(snapshot.error!),
                                textAlign: TextAlign.center,
                                style: context.text.bodySmall?.copyWith(color: k.onHero),
                              ),
                              TextButton(
                                onPressed: _retry,
                                style: TextButton.styleFrom(foregroundColor: k.onHero),
                                child: const Text('Réessayer'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final bytes = snapshot.data;
                    if (bytes == null) {
                      return Center(
                        child: Semantics(
                          label: 'Chargement de la photo',
                          child: CircularProgressIndicator(color: k.onHero),
                        ),
                      );
                    }
                    return Semantics(
                      image: true,
                      button: true,
                      label: 'Photo du tympan, ${ear.toLowerCase()}. Toucher pour agrandir.',
                      child: GestureDetector(
                        onTap: () => _openFullScreen(bytes),
                        child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('Touchez la photo pour l’agrandir.', style: context.text.bodySmall),
        ],
      ),
    );
  }
}

/// Plein écran : pincer pour zoomer, double-toucher pour revenir.
class _FullScreenPhoto extends StatefulWidget {
  const _FullScreenPhoto({required this.bytes, required this.title});

  final Uint8List bytes;
  final String title;

  @override
  State<_FullScreenPhoto> createState() => _FullScreenPhotoState();
}

class _FullScreenPhotoState extends State<_FullScreenPhoto> {
  final _zoom = TransformationController();

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Scaffold(
      backgroundColor: k.hero,
      appBar: AppBar(
        backgroundColor: k.hero,
        foregroundColor: k.onHero,
        title: Text(widget.title),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onDoubleTap: () => _zoom.value = Matrix4.identity(),
          child: InteractiveViewer(
            transformationController: _zoom,
            minScale: 1,
            maxScale: 6,
            child: Center(child: Image.memory(widget.bytes, fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }
}
