import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korai_frontend/core/api/api_client.dart';
import 'package:korai_frontend/core/auth/session_controller.dart';
import 'package:korai_frontend/core/theme/app_theme.dart';
import 'package:korai_frontend/features/auth/presentation/login_page.dart';

void main() {
  testWidgets('affiche l’écran de connexion sans identifiants pré-remplis',
      (WidgetTester tester) async {
    final session = AuthCubit(apiClient: ApiClient());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LoginPage(session: session),
      ),
    );

    expect(find.text('Korai'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.byIcon(Icons.login_rounded), findsOneWidget);

    // Aucun identifiant ne doit être pré-rempli dans les champs.
    final fields = tester.widgetList<EditableText>(find.byType(EditableText));
    for (final field in fields) {
      expect(field.controller.text, isEmpty);
    }

    await session.close();
  });

  testWidgets('valide les champs avant d’envoyer la connexion',
      (WidgetTester tester) async {
    final session = AuthCubit(apiClient: ApiClient());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LoginPage(session: session),
      ),
    );

    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text('Adresse e-mail : champ obligatoire.'), findsOneWidget);
    expect(find.text('Mot de passe : champ obligatoire.'), findsOneWidget);

    await session.close();
  });
}
