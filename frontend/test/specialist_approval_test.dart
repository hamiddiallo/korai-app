import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:korai_frontend/core/api/api_client.dart';
import 'package:korai_frontend/core/auth/session_controller.dart';
import 'package:korai_frontend/core/design/design.dart';
import 'package:korai_frontend/features/admin/data/admin_repository.dart';
import 'package:korai_frontend/features/admin/domain/admin_models.dart';
import 'package:korai_frontend/features/admin/presentation/admin_users_tab.dart';

class _FakeAdminRepository extends AdminRepository {
  _FakeAdminRepository() : super(ApiClient());

  final approved = <String>[];
  var users = <AdminUser>[
    const AdminUser(
      id: 'spec-1',
      fullName: 'Awa Ndiaye',
      email: 'awa@korai.test',
      role: 'SPECIALIST',
      accountStatus: 'PENDING',
      matricule: 'ORL002',
    ),
    const AdminUser(id: 'nurse-1', fullName: 'Hamid Diallo', email: 'nurse@korai.test', role: 'NURSE'),
  ];

  @override
  Future<List<AdminUser>> listUsers() async => users;

  @override
  Future<AdminUser> approveUser(String id) async {
    approved.add(id);
    users = [
      for (final u in users)
        u.id == id
            ? AdminUser(id: u.id, fullName: u.fullName, email: u.email, role: u.role, matricule: u.matricule)
            : u,
    ];
    return users.firstWhere((u) => u.id == id);
  }
}

void main() {
  test('l’inscription spécialiste reste en attente : message, aucune session ouverte', () async {
    final api = ApiClient(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/auth/register/specialist');
        return http.Response(
          jsonEncode({'pending': true, 'message': 'Un administrateur doit vérifier votre identité.'}),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final session = AuthCubit(apiClient: api);
    final message = await session.registerSpecialist(
      fullName: 'Awa Ndiaye',
      email: 'awa@korai.test',
      password: 'MotDePasse123',
      matricule: 'ORL002',
    );
    expect(message, contains('administrateur'));
    expect(session.state.isAuthenticated, isFalse);
    await session.close();
  });

  testWidgets('l’admin voit les inscriptions à valider et active un compte', (tester) async {
    final repo = _FakeAdminRepository();
    await tester.pumpWidget(MaterialApp(theme: KoraiTheme.light(), home: AdminUsersTab(repository: repo)));
    await tester.pumpAndSettle();

    // Ouverture sur le filtre « À valider » : seul le spécialiste en attente apparaît.
    expect(find.text('À valider · 1'), findsOneWidget);
    expect(find.text('Awa Ndiaye'), findsOneWidget);
    expect(find.text('Hamid Diallo'), findsNothing);

    await tester.tap(find.text('Activer'));
    await tester.pumpAndSettle();
    expect(find.text('Activer ce compte ?'), findsOneWidget);
    expect(find.textContaining('matricule ORL002'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Activer').last);
    await tester.pumpAndSettle();

    expect(repo.approved, ['spec-1']);
    expect(find.text('Compte de Awa Ndiaye activé.'), findsOneWidget);
    expect(find.text('À valider · 1'), findsNothing);
  });
}
