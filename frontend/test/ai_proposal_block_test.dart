import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korai_frontend/core/design/design.dart';
import 'package:korai_frontend/core/domain/korai_enums.dart';
import 'package:korai_frontend/features/nurse/domain/ai_case.dart';
import 'package:korai_frontend/features/nurse/presentation/widgets/ai_proposal_block.dart';

/// Avis sur les symptômes au format de serviceIA (plus de 600 caractères).
final _longReport = [
  '1. Causes probables :',
  '   - Otite moyenne aiguë (OMA) : ${'inflammation aiguë de la caisse du tympan. ' * 6}',
  '2. Signes associés :',
  '   - Fièvre : ${'fièvre élevée, irritabilité, troubles du sommeil. ' * 6}',
  '3. Conduite à tenir :',
  '   - Antalgiques : paracétamol.',
].join('\n');

Widget _block(String ragOpinion) => MaterialApp(
      theme: KoraiTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: AiProposalBlock(
            summary: AiSummary(
              confidenceLabel: AiConfidenceLabel.high,
              warnings: const [],
              sources: const ['EMC-ORL.pdf · p. 96'],
              likelyDiagnosis: 'Otite moyenne aiguë',
              ragOpinion: ragOpinion,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('avis long sur les symptômes : causes probables d’abord, le reste à la demande', (tester) async {
    await tester.pumpWidget(_block(_longReport));

    expect(find.text('Causes probables'), findsOneWidget);
    expect(find.text('Conduite à tenir'), findsNothing);
    expect(find.text('EMC-ORL.pdf · p. 96'), findsOneWidget, reason: 'sources toujours visibles');

    await tester.ensureVisible(find.text('Lire tout l’avis'));
    await tester.tap(find.text('Lire tout l’avis'));
    await tester.pumpAndSettle();
    expect(find.text('Conduite à tenir'), findsOneWidget);
    expect(find.text('Réduire l’avis'), findsOneWidget);
  });

  testWidgets('avis court : affiché en entier, sans bouton', (tester) async {
    await tester.pumpWidget(_block('1. Causes probables :\nOtomycose.\n2. Conduite à tenir :\nGouttes antifongiques.'));

    expect(find.text('Causes probables'), findsOneWidget);
    expect(find.text('Conduite à tenir'), findsOneWidget);
    expect(find.text('Lire tout l’avis'), findsNothing);
  });
}
