import 'dart:io';

import 'package:image/image.dart' as img;

class OrlImageEditor {
  static Future<File> rotate(File file, {required bool clockwise}) async {
    final decoded = await _decode(file);
    final rotated = img.copyRotate(decoded, angle: clockwise ? 90 : -90);
    return _writeJpeg(file, rotated);
  }

  static Future<File> flipHorizontal(File file) async {
    final decoded = await _decode(file);
    return _writeJpeg(
      file,
      img.copyFlip(decoded, direction: img.FlipDirection.horizontal),
    );
  }

  static Future<File> adjustBrightness(File file,
      {required bool brighter}) async {
    final decoded = await _decode(file);
    final adjusted = img.adjustColor(
      decoded,
      brightness: brighter ? 1.12 : 0.88,
    );
    return _writeJpeg(file, adjusted);
  }

  static Future<img.Image> _decode(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Impossible de lire l\'image ORL.');
    }
    return decoded;
  }

  static Future<File> _writeJpeg(File source, img.Image image) async {
    final encoded = img.encodeJpg(image, quality: 86);
    final output = File(
      '${source.parent.path}/korai_edited_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await output.writeAsBytes(encoded);
    return output;
  }
}
