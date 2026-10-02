import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korai_frontend/core/design/design.dart';
import 'package:korai_frontend/core/utils/validators.dart';
import 'package:korai_frontend/features/admin/presentation/admin_widgets.dart';

void main() {
  Future<void> openSheet(WidgetTester tester, {required Future<void> Function() onSubmit}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KoraiTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  final name = TextEditingController();
                  showAdminFormSheet(
                    context,
                    title: 'Nouveau médecin',
                    submitLabel: 'Enregistrer',
                    controllers: [name],
                    fields: (context, setState) => [
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(labelText: 'Nom'),
                        validator: (v) => KValidators.required(v, 'Nom'),
                      ),
                    ],
                    onSubmit: onSubmit,
                  );
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('la feuille se ferme sans erreur (contrôleurs libérés après l’animation)', (tester) async {
    await openSheet(tester, onSubmit: () async {});
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau médecin'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signale les champs à corriger avant d’envoyer', (tester) async {
    var submitted = false;
    await openSheet(tester, onSubmit: () async => submitted = true);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Nom : champ obligatoire.'), findsOneWidget);
    expect(find.text('Champs à corriger'), findsOneWidget);
    expect(submitted, isFalse);
  });

  testWidgets('affiche une erreur claire si l’enregistrement échoue et reste ouverte', (tester) async {
    await openSheet(tester, onSubmit: () async => throw Exception('réseau'));
    await tester.enterText(find.byType(TextFormField), 'Diop');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrement impossible'), findsOneWidget);
    expect(find.text('Nouveau médecin'), findsOneWidget);
  });
}
