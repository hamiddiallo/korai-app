import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korai_frontend/core/api/api_client.dart';
import 'package:korai_frontend/core/auth/session_controller.dart';
import 'package:korai_frontend/core/theme/app_theme.dart';
import 'package:korai_frontend/features/auth/presentation/login_page.dart';

void main() {
  testWidgets('shows professional login screen', (WidgetTester tester) async {
    final session = AuthCubit(apiClient: ApiClient());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LoginPage(session: session),
      ),
    );

    expect(find.text('KORAI ORL'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.byIcon(Icons.login_rounded), findsOneWidget);

    await session.close();
  });
}
