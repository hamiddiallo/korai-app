import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_client.dart';

class SessionUser {
  const SessionUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.linkedPatientId,
    this.phone,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? linkedPatientId;
  final String? phone;

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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'role': role,
        if (linkedPatientId != null) 'linkedPatientId': linkedPatientId,
        if (phone != null) 'phone': phone,
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
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _unset = Object();

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this.apiClient,
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        super(const AuthState());

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
      final user =
          SessionUser.fromJson(response['user'] as Map<String, dynamic>);
      await _cacheUser(user);
      emit(
        state.copyWith(
          user: user,
          isRestoring: false,
          errorMessage: null,
        ),
      );
    } on ApiException catch (error) {
      if (error.code == 'UNAUTHORIZED' || error.code == 'FORBIDDEN') {
        await logout();
        return;
      }
      emit(
        state.copyWith(
          user: cachedUser,
          isRestoring: false,
          errorMessage: cachedUser == null ? error.toString() : null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          user: cachedUser,
          isRestoring: false,
          errorMessage: cachedUser == null ? error.toString() : null,
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
      emit(state.copyWith(errorMessage: error.toString()));
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
        if (birthDate != null && birthDate.isNotEmpty)
          'birthDate': birthDate.trim(),
        if (sex != null && sex.isNotEmpty) 'sex': sex,
        'consentForAi': true,
        'consentForTeleExpertise': true,
      });
      await _persistAuthPayload(response);
    } catch (error) {
      emit(state.copyWith(errorMessage: error.toString()));
    } finally {
      emit(state.copyWith(isSubmitting: false));
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _sessionUserKey);
    apiClient.setAccessToken(null);
    emit(const AuthState());
  }

  Future<void> _persistAuthPayload(Map<String, dynamic> response) async {
    final accessToken = response['accessToken'].toString();
    final user = SessionUser.fromJson(response['user'] as Map<String, dynamic>);
    apiClient.setAccessToken(accessToken);
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(
        key: _refreshTokenKey, value: response['refreshToken'].toString());
    await _cacheUser(user);
    emit(
      state.copyWith(
        user: user,
        errorMessage: null,
      ),
    );
  }

  Future<void> _cacheUser(SessionUser user) async {
    await _storage.write(
        key: _sessionUserKey, value: jsonEncode(user.toJson()));
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
