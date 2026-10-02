import 'package:flutter_test/flutter_test.dart';
import 'package:korai_frontend/core/utils/diagnosis_text.dart';

void main() {
  const report = '1. Causes probables\n'
      'Otite externe diffuse, otite moyenne chronique.\n\n'
      '2. Signes associés\n'
      'Otalgie pulsatile, otorrhée.\n'
      '3. Conduite à tenir\n'
      'Examen otoscopique en urgence.';

  test('extrait un titre court d’un rapport numéroté', () {
    expect(DiagnosisText.headline(report), 'Otite externe diffuse, otite moyenne chronique.');
    expect(DiagnosisText.hasDetails(report), isTrue);
  });

  test('découpe le rapport en sections', () {
    final sections = DiagnosisText.sections(report);
    expect(sections.map((s) => s.title), ['Causes probables', 'Signes associés', 'Conduite à tenir']);
    expect(sections.last.body, 'Examen otoscopique en urgence.');
  });

  test('garde un diagnostic simple tel quel', () {
    expect(DiagnosisText.headline('Otite moyenne aiguë'), 'Otite moyenne aiguë');
    expect(DiagnosisText.hasDetails('Otite moyenne aiguë'), isFalse);
  });

  test('reconnaît un échec technique sans filtrer un vrai rapport', () {
    expect(DiagnosisText.isTechnicalFailure('Échec technique du service IA'), isTrue);
    expect(DiagnosisText.isTechnicalFailure(report), isFalse);
  });
}
