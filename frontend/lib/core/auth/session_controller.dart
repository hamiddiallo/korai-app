import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_client.dart';
import '../design/feedback.dart';

class SessionUser {
  const SessionUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.linkedPatientId,
    this.phone,
    this.healthFacility,
    this.professionalId,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? linkedPatientId;
  final String? phone;
  final String? healthFacility;
  final String? professionalId;

  static String _normalizeRole(String raw) {
    final role = raw.trim().toUpperCase();
    if (role == 'PROFESSIONAL') return 'NURSE';
    return role;
  }

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: json['id'].toString(),
      fullName: json['fullName'].toString(),
      email: json['email'].toString(),
      role: _normalizeRole(json['role'].toString()),
      linkedPatientId: json['linkedPatientId']?.toString(),
      phone: json['phone']?.toString(),
      healthFacility: json['healthFacility']?.toString(),
      professionalId: json['professionalId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'role': role,
        if (linkedPatientId != null) 'linkedPatientId': linkedPatientId,
        if (phone != null) 'phone': phone,
        if (healthFacility != null) 'healthFacility': healthFacility,
        if (professionalId != null) 'professionalId': professionalId,
      };
}

class AuthState {
  const AuthState({
    this.user,
    this.isRestoring = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final SessionUser? user;
  final bool isRestoring;
  final bool isSubmitting;
  final String? errorMessage;

  bool get isAuthenticated => user != null;
  bool get isBusy => isRestoring || isSubmitting;

  AuthState copyWith({
    Object? user = _unset,
    bool? isRestoring,
    bool? isSubmitting,
    Object? errorMessage = _unset,
  }) {
    return AuthState(
      user: identical(user, _unset) ? this.user : user as SessionUser?,
      isRestoring: isRestoring ?? this.isRestoring,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: identical(errorMessage, _unset) ? this.errorMessage : errorMessage as String?,
    );
  }
}

const Object _unset = Object();

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this.apiClient,
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        super(const AuthState()) {
    apiClient
      ..tokenRefresher = _refreshTokens
      ..onSessionExpired = _expireSession;
  }

  static const sessionExpiredMessage = 'Votre session a expiré. Reconnectez-vous pour continuer.';

  final ApiClient apiClient;
  final FlutterSecureStorage _storage;
  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';
  static const _sessionUserKey = 'sessionUser';

  SessionUser? get user => state.user;
  bool get isAuthenticated => state.isAuthenticated;
  bool get isLoading => state.isBusy;
  String? get errorMessage => state.errorMessage;

  Future<void> restore() async {
    emit(state.copyWith(isRestoring: true, errorMessage: null));
    final token = await _storage.read(key: _accessTokenKey);
    final cachedUser = await _readCachedUser();
    if (token == null) {
      emit(state.copyWith(isRestoring: false, user: null));
      return;
    }

    apiClient.setAccessToken(token);
    try {
      final response = await apiClient.getJson('/auth/me');
      final user = SessionUser.fromJson(response['user'] as Map<String, dynamic>);
      await _cacheUser(user);
      emit(
        state.copyWith(
          user: user,
          isRestoring: false,
          errorMessage: null,
        ),
      );
    } on ApiException catch (error) {
      if (error.code == 'SESSION_EXPIRED') {
        await logout();
        emit(state.copyWith(errorMessage: sessionExpiredMessage));
        return;
      }
      if (error.code == 'UNAUTHORIZED' || error.code == 'FORBIDDEN') {
        await logout();
        return;
      }
      emit(
        state.copyWith(
          user: cachedUser,
          isRestoring: false,
          errorMessage: cachedUser == null ? friendlyError(error) : null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          user: cachedUser,
          isRestoring: false,
          errorMessage: cachedUser == null ? friendlyError(error) : null,
        ),
      );
    }
  }

  Future<void> login(String email, String password) async {
    emit(state.copyWith(isSubmitting: true, errorMessage: null));
    try {
      final response = await apiClient.postJson('/auth/login', {
        'email': email.trim(),
        'password': password,
      });
      await _persistAuthPayload(response);
    } catch (error) {
      emit(state.copyWith(errorMessage: friendlyError(error)));
    } finally {
      emit(state.copyWith(isSubmitting: false));
    }
  }

  Future<void> registerPatient({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    String? address,
    String? birthDate,
    String? sex,
    bool consentForAi = false,
    bool consentForTeleExpertise = false,
    String? facilityId,
  }) async {
    emit(state.copyWith(isSubmitting: true, errorMessage: null));
    try {
      final response = await apiClient.postJson('/auth/register/patient', {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        if (address != null && address.isNotEmpty) 'address': address.trim(),
        if (birthDate != null && birthDate.isNotEmpty) 'birthDate': birthDate.trim(),
        if (sex != null && sex.isNotEmpty) 'sex': sex,
        'consentForAi': consentForAi,
        'consentForTeleExpertise': consentForTeleExpertise,
        if (facilityId != null) 'facilityId': facilityId,
      });
      await _persistAuthPayload(response);
    } catch (error) {
      emit(state.copyWith(errorMessage: friendlyError(error)));
    } finally {
      emit(state.copyWith(isSubmitting: false));
    }
  }

  /// Inscription infirmier : compte créé en attente de validation (pas de
  /// connexion immédiate). Retourne le message de confirmation si l'inscription
  /// a réussi, sinon `null` (et `errorMessage` est renseigné).
  Future<String?> registerNurse({
    required String fullName,
    required String email,
    required String password,
    required String healthFacility,
    required String supervisorMatricule,
    String? phone,
    String? professionalId,
  }) async {
    emit(state.copyWith(isSubmitting: true, errorMessage: null));
    try {
      final response = await apiClient.postJson('/auth/register/nurse', {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'password': password,
        'healthFacility': healthFacility.trim(),
        'supervisorMatricule': supervisorMatricule.trim(),
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        if (professionalId != null && professionalId.isNotEmpty) 'professionalId': professionalId.trim(),
      });
      return response['message']?.toString() ?? 'Inscription enregistrée. En attente de validation de votre encadrant.';
    } catch (error) {
      emit(state.copyWith(errorMessage: friendlyError(error)));
      return null;
    } finally {
      emit(state.copyWith(isSubmitting: false));
    }
  }

  /// Inscription spécialiste : vérifiée par le matricule, connectée directement.
  /// Retourne `true` si l'inscription/connexion a réussi.
  /// Inscription d'un spécialiste. Le compte reste en attente jusqu'à la
  /// vérification de l'identité par un administrateur : renvoie le message à
  /// afficher, ou `null` en cas d'échec (voir `errorMessage`).
  Future<String?> registerSpecialist({
    required String fullName,
    required String email,
    required String password,
    required String matricule,
    String? phone,
    String? healthFacility,
  }) async {
    emit(state.copyWith(isSubmitting: true, errorMessage: null));
    try {
      final response = await apiClient.postJson('/auth/register/specialist', {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'password': password,
        'matricule': matricule.trim(),
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        if (healthFacility != null && healthFacility.isNotEmpty) 'healthFacility': healthFacility.trim(),
      });
      return response['message']?.toString() ?? 'Inscription enregistrée. Un administrateur doit valider votre compte.';
    } catch (error) {
      emit(state.copyWith(errorMessage: friendlyError(error)));
      return null;
    } finally {
      emit(state.copyWith(isSubmitting: false));
    }
  }

  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? healthFacility,
    String? professionalId,
  }) async {
    // Treat empty strings as "no change" — don't send them to the API
    String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

    final cleanName = clean(fullName);
    final cleanPhone = clean(phone);
    final cleanFacility = clean(healthFacility);
    final cleanProId = clean(professionalId);

    emit(state.copyWith(isSubmitting: true, errorMessage: null));
    try {
      final response = await apiClient.patchJson('/auth/me', {
        if (cleanName != null) 'fullName': cleanName,
        if (cleanPhone != null) 'phone': cleanPhone,
        if (cleanFacility != null) 'healthFacility': cleanFacility,
        if (cleanProId != null) 'professionalId': cleanProId,
      });
      final user = SessionUser.fromJson(response['user'] as Map<String, dynamic>);
      await _cacheUser(user);
      emit(state.copyWith(user: user, errorMessage: null));
    } catch (error) {
      emit(state.copyWith(errorMessage: friendlyError(error)));
      rethrow;
    } finally {
      emit(state.copyWith(isSubmitting: false));
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    emit(state.copyWith(isSubmitting: true, errorMessage: null));
    try {
      await apiClient.patchJson('/auth/me/password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
    } catch (error) {
      emit(state.copyWith(errorMessage: friendlyError(error)));
      rethrow;
    } finally {
      emit(state.copyWith(isSubmitting: false));
    }
  }

  /// Efface le message d'erreur affiché (changement d'écran, nouvelle saisie).
  void clearError() {
    if (state.errorMessage != null) emit(state.copyWith(errorMessage: null));
  }

  Future<void> logout() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _sessionUserKey);
    apiClient.setAccessToken(null);
    emit(const AuthState());
  }

  /// Renouvelle le jeton d'accès (30 min) avec le jeton de rafraîchissement.
  /// `false` : session terminée. Une panne réseau est relancée telle quelle
  /// (on ne déconnecte pas quelqu'un parce qu'il est hors ligne).
  Future<bool> _refreshTokens() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await apiClient.postJson('/auth/refresh', {'refreshToken': refreshToken});
      final accessToken = response['accessToken'].toString();
      apiClient.setAccessToken(accessToken);
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: response['refreshToken'].toString());
      final user = response['user'];
      if (user is Map<String, dynamic>) await _cacheUser(SessionUser.fromJson(user));
      return true;
    } on ApiException catch (error) {
      if (error.isNetworkFailure) rethrow;
      return false;
    }
  }

  /// La session n'a pas pu être renouvelée : retour à la connexion avec une
  /// explication. Pendant la restauration, [restore] s'en charge.
  Future<void> _expireSession() async {
    if (!state.isAuthenticated || state.isRestoring) return;
    await logout();
    emit(state.copyWith(errorMessage: sessionExpiredMessage));
  }

  Future<void> _persistAuthPayload(Map<String, dynamic> response) async {
    final accessToken = response['accessToken'].toString();
    final user = SessionUser.fromJson(response['user'] as Map<String, dynamic>);
    apiClient.setAccessToken(accessToken);
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: response['refreshToken'].toString());
    await _cacheUser(user);
    emit(
      state.copyWith(
        user: user,
        errorMessage: null,
      ),
    );
  }

  Future<void> _cacheUser(SessionUser user) async {
    await _storage.write(key: _sessionUserKey, value: jsonEncode(user.toJson()));
  }

  Future<SessionUser?> _readCachedUser() async {
    final raw = await _storage.read(key: _sessionUserKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SessionUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await _storage.delete(key: _sessionUserKey);
      return null;
    }
  }
}
