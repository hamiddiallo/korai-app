import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Moyen de déverrouillage disponible sur ce téléphone. Rien ne quitte
/// l'appareil : c'est le système (Face ID, empreinte, code) qui vérifie.
enum UnlockMethod { faceId, touchId, face, fingerprint, biometric, deviceCode, none }

extension UnlockMethodLabel on UnlockMethod {
  bool get available => this != UnlockMethod.none;

  /// Complément de « Déverrouiller avec … ».
  String get label => switch (this) {
        UnlockMethod.faceId => 'Face ID',
        UnlockMethod.touchId => 'Touch ID',
        UnlockMethod.face => 'la reconnaissance faciale',
        UnlockMethod.fingerprint => 'votre empreinte',
        UnlockMethod.biometric => 'votre empreinte ou votre visage',
        UnlockMethod.deviceCode => 'le code du téléphone',
        UnlockMethod.none => '',
      };

  /// Libellé court du bouton de l'écran de verrouillage (tient sur une ligne).
  String get buttonLabel => switch (this) {
        UnlockMethod.faceId => 'Déverrouiller avec Face ID',
        UnlockMethod.touchId => 'Déverrouiller avec Touch ID',
        UnlockMethod.face => 'Déverrouiller avec le visage',
        UnlockMethod.fingerprint => 'Déverrouiller avec l’empreinte',
        UnlockMethod.deviceCode => 'Déverrouiller avec le code',
        UnlockMethod.biometric || UnlockMethod.none => 'Déverrouiller',
      };
}

/// Issue d'une demande de déverrouillage. `message` est prêt à afficher ;
/// il est `null` quand l'utilisateur a simplement annulé.
class UnlockResult {
  const UnlockResult._(this.ok, this.message);

  static const success = UnlockResult._(true, null);
  static const cancelled = UnlockResult._(false, null);
  const UnlockResult.failed(String message) : this._(false, message);

  final bool ok;
  final String? message;
}

/// Accès à la biométrie du téléphone (local_auth), avec des messages clairs.
class BiometricService {
  BiometricService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<UnlockMethod> availableMethod() async {
    try {
      if (!await _auth.isDeviceSupported()) return UnlockMethod.none;
      final types = await _auth.getAvailableBiometrics();
      final ios = !kIsWeb && Platform.isIOS;
      if (types.contains(BiometricType.face)) return ios ? UnlockMethod.faceId : UnlockMethod.face;
      if (types.contains(BiometricType.fingerprint)) return ios ? UnlockMethod.touchId : UnlockMethod.fingerprint;
      // Android ne précise souvent que la « force » du capteur.
      if (types.isNotEmpty) return UnlockMethod.biometric;
      return UnlockMethod.deviceCode;
    } catch (_) {
      return UnlockMethod.none;
    }
  }

  /// Demande au système de vérifier l'utilisateur. Le code du téléphone est
  /// accepté en repli (gants, masque, capteur indisponible).
  Future<UnlockResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Déverrouiller Korai',
            signInHint: 'Utilisez votre empreinte, votre visage ou le code du téléphone.',
            cancelButton: 'Annuler',
          ),
          IOSAuthMessages(cancelButton: 'Annuler', localizedFallbackTitle: 'Utiliser le code'),
        ],
      );
      return ok ? UnlockResult.success : UnlockResult.cancelled;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback ||
        LocalAuthExceptionCode.authInProgress =>
          UnlockResult.cancelled,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware =>
          const UnlockResult.failed(
            'Aucun code, visage ou empreinte n’est configuré sur ce téléphone. '
            'Ajoutez un code de verrouillage dans les réglages, ou utilisez votre mot de passe.',
          ),
        LocalAuthExceptionCode.temporaryLockout => const UnlockResult.failed(
            'Trop d’essais. Patientez quelques secondes puis réessayez, ou utilisez votre mot de passe.',
          ),
        LocalAuthExceptionCode.biometricLockout => const UnlockResult.failed(
            'La biométrie est bloquée après trop d’essais. Déverrouillez le téléphone avec son code, puis réessayez.',
          ),
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable => const UnlockResult.failed(
            'Le capteur est momentanément indisponible. Réessayez dans un instant.',
          ),
        _ => const UnlockResult.failed('Le déverrouillage n’a pas abouti. Réessayez ou utilisez votre mot de passe.'),
      };
    } catch (_) {
      return const UnlockResult.failed('Le déverrouillage n’a pas abouti. Réessayez ou utilisez votre mot de passe.');
    }
  }
}
