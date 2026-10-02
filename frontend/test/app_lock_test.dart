import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korai_frontend/core/auth/app_lock.dart';
import 'package:korai_frontend/core/auth/biometric_service.dart';
import 'package:korai_frontend/core/auth/lock_screen.dart';
import 'package:korai_frontend/core/design/design.dart';

class _MemoryStore implements AppLockStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _FakeBiometrics extends BiometricService {
  UnlockMethod method = UnlockMethod.faceId;
  UnlockResult next = UnlockResult.success;
  int calls = 0;

  @override
  Future<UnlockMethod> availableMethod() async => method;

  @override
  Future<UnlockResult> authenticate(String reason) async {
    calls++;
    return next;
  }
}

void main() {
  late _MemoryStore store;
  late _FakeBiometrics bio;
  late DateTime now;

  AppLockCubit build() => AppLockCubit(biometrics: bio, store: store, clock: () => now);

  setUp(() {
    store = _MemoryStore();
    bio = _FakeBiometrics();
    now = DateTime(2026, 9, 26, 10);
  });

  test('verrou activé : l’application démarre verrouillée', () async {
    store.values['appLockEnabled'] = 'true';
    final lock = build();
    await lock.load();
    expect(lock.state.locked, isTrue);

    final off = AppLockCubit(biometrics: bio, store: _MemoryStore(), clock: () => now);
    await off.load();
    expect(off.state.locked, isFalse);
  });

  test('se verrouille seulement après le délai en arrière-plan', () async {
    store.values['appLockEnabled'] = 'true';
    final lock = build();
    await lock.load();
    await lock.unlock();
    expect(lock.state.locked, isFalse);

    lock.onBackgrounded();
    now = now.add(const Duration(minutes: 4));
    await lock.onForegrounded();
    expect(lock.state.locked, isFalse, reason: '4 min < 5 min');

    lock.onBackgrounded();
    now = now.add(const Duration(minutes: 5));
    await lock.onForegrounded();
    expect(lock.state.locked, isTrue);
  });

  test('annuler laisse verrouillé sans message ; un échec donne un message clair', () async {
    store.values['appLockEnabled'] = 'true';
    final lock = build();
    await lock.load();

    bio.next = UnlockResult.cancelled;
    await lock.unlock();
    expect(lock.state.locked, isTrue);
    expect(lock.state.message, isNull);

    bio.next = const UnlockResult.failed('Trop d’essais.');
    await lock.unlock();
    expect(lock.state.locked, isTrue);
    expect(lock.state.message, 'Trop d’essais.');

    bio.next = UnlockResult.success;
    await lock.unlock();
    expect(lock.state.locked, isFalse);
    expect(lock.state.message, isNull);
  });

  test('activer demande une vérification et enregistre le réglage', () async {
    final lock = build();
    await lock.load();

    bio.next = UnlockResult.cancelled;
    expect(await lock.enable(), isNull);
    expect(lock.state.enabled, isFalse);
    expect(store.values['appLockEnabled'], isNull);

    bio.next = UnlockResult.success;
    expect(await lock.enable(), isNull);
    expect(lock.state.enabled, isTrue);
    expect(store.values['appLockEnabled'], 'true');

    await lock.reset();
    expect(lock.state.enabled, isFalse);
    expect(store.values, isEmpty);
  });

  test('la fenêtre Face ID ne compte pas comme un passage en arrière-plan', () async {
    store.values['appLockEnabled'] = 'true';
    final lock = build();
    await lock.load();
    bio.next = UnlockResult.success;
    final pending = lock.unlock();
    lock.onBackgrounded(); // pendant la vérification
    await pending;
    now = now.add(const Duration(minutes: 30));
    await lock.onForegrounded();
    expect(lock.state.locked, isFalse);
  });

  testWidgets('écran de verrouillage : bouton, message d’échec et repli mot de passe', (tester) async {
    store.values['appLockEnabled'] = 'true';
    bio.next = const UnlockResult.failed('Le capteur est momentanément indisponible. Réessayez dans un instant.');
    final lock = build();
    await lock.load();
    var usedPassword = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: KoraiTheme.light(),
        home: BlocProvider.value(
          value: lock,
          child: LockScreen(userName: 'Hamid Diallo', onUsePassword: () => usedPassword = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Korai est verrouillé'), findsOneWidget);
    expect(find.textContaining('Bonjour Hamid'), findsOneWidget);
    expect(bio.calls, 1, reason: 'Face ID proposé dès l’affichage');
    expect(find.text('Le capteur est momentanément indisponible. Réessayez dans un instant.'), findsOneWidget);
    expect(find.text('Déverrouiller avec Face ID'), findsOneWidget);

    await tester.tap(find.text('Me reconnecter avec mon mot de passe'));
    expect(usedPassword, isTrue);
  });
}
