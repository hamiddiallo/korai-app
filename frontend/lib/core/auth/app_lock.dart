import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'biometric_service.dart';

/// Réglages du verrou conservés sur l'appareil.
abstract class AppLockStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureAppLockStore implements AppLockStore {
  const SecureAppLockStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class AppLockState {
  const AppLockState({
    this.ready = false,
    this.enabled = false,
    this.locked = false,
    this.unlocking = false,
    this.timeout = AppLockCubit.defaultTimeout,
    this.method = UnlockMethod.none,
    this.message,
  });

  /// Réglages lus (au démarrage, avant la restauration de session).
  final bool ready;
  final bool enabled;
  final bool locked;
  final bool unlocking;
  final Duration timeout;
  final UnlockMethod method;

  /// Explication du dernier échec de déverrouillage.
  final String? message;

  AppLockState copyWith({
    bool? ready,
    bool? enabled,
    bool? locked,
    bool? unlocking,
    Duration? timeout,
    UnlockMethod? method,
    String? message,
    bool clearMessage = false,
  }) {
    return AppLockState(
      ready: ready ?? this.ready,
      enabled: enabled ?? this.enabled,
      locked: locked ?? this.locked,
      unlocking: unlocking ?? this.unlocking,
      timeout: timeout ?? this.timeout,
      method: method ?? this.method,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

/// Verrou de l'application : au lancement et après un temps en arrière-plan,
/// Korai demande Face ID, l'empreinte ou le code du téléphone. Tout se passe
/// sur l'appareil ; le serveur n'est pas sollicité (fonctionne hors ligne).
class AppLockCubit extends Cubit<AppLockState> {
  AppLockCubit({
    BiometricService? biometrics,
    AppLockStore store = const SecureAppLockStore(),
    DateTime Function()? clock,
  })  : _biometrics = biometrics ?? BiometricService(),
        _store = store,
        _clock = clock ?? DateTime.now,
        super(const AppLockState());

  static const defaultTimeout = Duration(minutes: 5);
  static const timeouts = [Duration(minutes: 1), Duration(minutes: 5), Duration(minutes: 15)];

  static const _enabledKey = 'appLockEnabled';
  static const _timeoutKey = 'appLockTimeoutSeconds';

  final BiometricService _biometrics;
  final AppLockStore _store;
  final DateTime Function() _clock;
  DateTime? _backgroundedAt;

  /// Lit les réglages. Verrou activé → l'application démarre verrouillée.
  Future<void> load() async {
    var enabled = false;
    int? seconds;
    try {
      enabled = await _store.read(_enabledKey) == 'true';
      seconds = int.tryParse(await _store.read(_timeoutKey) ?? '');
    } catch (_) {
      // Stockage illisible : pas de verrou plutôt qu'une application bloquée.
    }
    final method = await _biometrics.availableMethod();
    emit(AppLockState(
      ready: true,
      enabled: enabled,
      locked: enabled,
      timeout: seconds == null ? defaultTimeout : Duration(seconds: seconds),
      method: method,
    ));
  }

  /// L'application passe en arrière-plan (hors fenêtre de vérification).
  void onBackgrounded() {
    if (state.unlocking) return;
    _backgroundedAt ??= _clock();
  }

  /// Retour au premier plan : verrouille si l'absence a dépassé le délai.
  Future<void> onForegrounded() async {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (state.enabled && !state.locked && since != null && _clock().difference(since) >= state.timeout) {
      emit(state.copyWith(locked: true, clearMessage: true));
    }
    // Face ID ou code ajoutés/retirés dans les réglages entre-temps.
    final method = await _biometrics.availableMethod();
    if (!isClosed && method != state.method) emit(state.copyWith(method: method));
  }

  Future<void> unlock() async {
    if (!state.locked || state.unlocking) return;
    emit(state.copyWith(unlocking: true, clearMessage: true));
    final result = await _biometrics.authenticate('Déverrouillez Korai pour retrouver vos dossiers.');
    if (isClosed) return;
    emit(state.copyWith(
      unlocking: false,
      locked: !result.ok,
      message: result.message,
      clearMessage: result.message == null,
    ));
  }

  /// Active le verrou après une vérification. Renvoie un message d'échec, ou
  /// `null` si c'est activé (ou simplement annulé : [AppLockState.enabled]).
  Future<String?> enable() async {
    final result = await _confirm('Confirmez pour protéger Korai.');
    if (!result.ok) return result.message;
    await _store.write(_enabledKey, 'true');
    await _store.write(_timeoutKey, '${state.timeout.inSeconds}');
    emit(state.copyWith(enabled: true, locked: false, clearMessage: true));
    return null;
  }

  Future<String?> disable() async {
    final result = await _confirm('Confirmez pour retirer la protection de Korai.');
    if (!result.ok) return result.message;
    await _store.write(_enabledKey, 'false');
    emit(state.copyWith(enabled: false, locked: false, clearMessage: true));
    return null;
  }

  Future<void> setTimeout(Duration timeout) async {
    await _store.write(_timeoutKey, '${timeout.inSeconds}');
    emit(state.copyWith(timeout: timeout));
  }

  /// Déconnexion : le prochain utilisateur de l'appareil choisira lui-même.
  Future<void> reset() async {
    _backgroundedAt = null;
    await _store.delete(_enabledKey);
    await _store.delete(_timeoutKey);
    emit(AppLockState(ready: true, method: state.method));
  }

  Future<UnlockResult> _confirm(String reason) async {
    if (state.unlocking) return UnlockResult.cancelled;
    emit(state.copyWith(unlocking: true));
    final result = await _biometrics.authenticate(reason);
    if (!isClosed) emit(state.copyWith(unlocking: false));
    return result;
  }
}

/// « 5 min » pour les réglages et les messages.
String appLockTimeoutLabel(Duration d) => '${d.inMinutes} min';
