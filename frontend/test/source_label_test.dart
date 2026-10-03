import 'package:flutter_test/flutter_test.dart';
import 'package:korai_frontend/core/utils/source_label.dart';
import 'package:korai_frontend/features/chatbot/domain/chat_models.dart';
import 'package:korai_frontend/features/nurse/domain/ai_case.dart';

const _windows = r'C:\Users\DonutGiveUp\Documents\KORAI\documents_orl\EMC-ORL.pdf · p. 602';

void main() {
  test('retire le chemin Windows de la base indexée (nom de l’auteur compris)', () {
    expect(SourceLabel.clean(_windows), 'EMC-ORL.pdf · p. 602');
    expect(SourceLabel.clean('/data/documents_orl/Guide.pdf'), 'Guide.pdf');
  });

  test('URL, titres ordinaires et libellés déjà propres inchangés', () {
    expect(SourceLabel.clean('https://has-sante.fr/otites.pdf'), 'https://has-sante.fr/otites.pdf');
    expect(SourceLabel.clean('ORL adulte/enfant · p. 12'), 'ORL adulte/enfant · p. 12');
    expect(SourceLabel.clean('EMC-ORL.pdf · p. 97'), 'EMC-ORL.pdf · p. 97');
  });

  test('anciens messages de l’assistant et anciennes analyses : sources affichées sans chemin', () {
    final message = ChatMessage.fromJson({
      'id': 'm1',
      'conversationId': 'c1',
      'role': 'ASSISTANT',
      'content': 'Réponse',
      'sources': [_windows, 'EMC-ORL.pdf · p. 602'],
    });
    expect(message.sources, ['EMC-ORL.pdf · p. 602'], reason: 'nettoyé puis dédoublonné');

    final summary = AiSummary.fromJson({
      'confidenceLabel': 'HIGH',
      'warnings': <String>[],
      'sources': [_windows],
    });
    expect(summary.sources, ['EMC-ORL.pdf · p. 602']);
  });
}
