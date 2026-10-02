import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korai_frontend/core/design/design.dart';
import 'package:korai_frontend/core/storage/local_data_conflict_page.dart';
import 'package:korai_frontend/core/storage/local_data_guard.dart';

class _MemoryStore implements LocalDataStore {
  LocalDataOwner? owner;
  int unsent = 0;
  int clears = 0;

  @override
  Future<LocalDataOwner?> readOwner() async => owner;

  @override
  Future<void> writeOwner(LocalDataOwner value) async => owner = value;

  @override
  Future<int> countUnsent() async => unsent;

  @override
  Future<void> clearPersonalData() async {
    clears++;
    unsent = 0;
  }
}

void main() {
  late _MemoryStore store;
  late LocalDataGuard guard;

  setUp(() {
    store = _MemoryStore();
    guard = LocalDataGuard(store);
  });

  test('première connexion : le téléphone appartient au compte connecté', () async {
    expect(await guard.claim(userId: 'a', userName: 'Aïssatou'), isA<LocalDataReady>());
    expect(store.owner?.id, 'a');
    expect(store.clears, 0);
  });

  test('même compte : ses données restent', () async {
    store.owner = const LocalDataOwner(id: 'a', name: 'Aïssatou');
    store.unsent = 4;
    expect(await guard.claim(userId: 'a', userName: 'Aïssatou'), isA<LocalDataReady>());
    expect(store.clears, 0);
  });

  test('autre compte, tout envoyé : le cache du précédent est effacé', () async {
    store.owner = const LocalDataOwner(id: 'a', name: 'Aïssatou');
    final claim = await guard.claim(userId: 'b', userName: 'Bineta');
    expect(claim, isA<LocalDataReady>().having((c) => c.clearedPreviousOwner, 'effacé', isTrue));
    expect(store.clears, 1);
    expect(store.owner?.id, 'b');
  });

  test('autre compte avec des envois en attente : accès bloqué, rien n’est effacé', () async {
    store.owner = const LocalDataOwner(id: 'a', name: 'Aïssatou');
    store.unsent = 3;
    final claim = await guard.claim(userId: 'b', userName: 'Bineta');
    expect(
      claim,
      isA<LocalDataConflict>()
          .having((c) => c.ownerName, 'propriétaire', 'Aïssatou')
          .having((c) => c.unsentCount, 'non envoyés', 3),
    );
    expect(store.clears, 0);
    expect(store.owner?.id, 'a', reason: 'les données restent à Aïssatou');
  });

  test('effacement choisi explicitement : le téléphone change de propriétaire', () async {
    store.owner = const LocalDataOwner(id: 'a', name: 'Aïssatou');
    store.unsent = 3;
    await guard.discardAndClaim(userId: 'b', userName: 'Bineta');
    expect(store.clears, 1);
    expect(store.owner?.id, 'b');
  });

  testWidgets('écran de conflit : explication claire et effacement confirmé', (tester) async {
    var discarded = 0;
    var loggedOut = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: KoraiTheme.light(),
        home: LocalDataConflictPage(
          ownerName: 'Aïssatou',
          unsentCount: 3,
          onLogout: () => loggedOut++,
          onDiscard: () async => discarded++,
        ),
      ),
    );
    expect(find.textContaining('3 éléments non envoyés enregistrés par Aïssatou'), findsOneWidget);

    await tester.tap(find.text('Effacer les données de Aïssatou'));
    await tester.pumpAndSettle();
    expect(find.text('Effacer les données de Aïssatou ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(discarded, 0, reason: 'annuler ne supprime rien');

    await tester.tap(find.text('Effacer les données de Aïssatou'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Effacer définitivement'));
    await tester.pumpAndSettle();
    expect(discarded, 1);

    await tester.tap(find.text('Me déconnecter'));
    expect(loggedOut, 1);
  });

  testWidgets('écran de conflit : accord au singulier', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KoraiTheme.light(),
        home: LocalDataConflictPage(ownerName: 'Aïssatou', unsentCount: 1, onLogout: () {}, onDiscard: () async {}),
      ),
    );
    expect(find.textContaining('1 élément non envoyé enregistré par Aïssatou'), findsOneWidget);
    await tester.tap(find.text('Effacer les données de Aïssatou'));
    await tester.pumpAndSettle();
    expect(find.textContaining('L’élément non envoyé sera définitivement perdu'), findsOneWidget);
  });
}
