import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:korai_frontend/core/api/api_client.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('korai_upload'));
  tearDown(() => dir.deleteSync(recursive: true));

  const jpeg = [0xFF, 0xD8, 0xFF, 0xE0];
  const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0];
  const webp = [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50];

  Future<String> uploadAndCaptureBody(String fileName, List<int> bytes) async {
    final file = File('${dir.path}/$fileName')..writeAsBytesSync(bytes);
    String body = '';
    final client = ApiClient(
      httpClient: MockClient((request) async {
        body = latin1.decode(request.bodyBytes);
        return http.Response(jsonEncode({'case': {}}), 201, headers: {'content-type': 'application/json'});
      }),
    );
    await client.postMultipart(path: '/cases/diagnose', fields: {'patientId': 'p'}, file: file, fileField: 'file');
    return body.toLowerCase();
  }

  test('une photo JPEG part avec le type image/jpeg (plus application/octet-stream)', () async {
    final body = await uploadAndCaptureBody('otoscopie.jpg', jpeg);
    expect(body, contains('content-type: image/jpeg'));
    expect(body, isNot(contains('application/octet-stream')));
  });

  test('le type vient du contenu de la photo, pas de son nom', () async {
    expect(sniffImageMimeType(png), 'image/png');
    expect(sniffImageMimeType(webp), 'image/webp');
    expect(sniffImageMimeType(jpeg), 'image/jpeg');
    expect(await uploadAndCaptureBody('image_picker_123', png), contains('content-type: image/png'));
    // Un JPEG renommé en .png reste déclaré JPEG : le serveur vérifie la signature.
    expect(await uploadAndCaptureBody('retouche.png', jpeg), contains('content-type: image/jpeg'));
  });
}
