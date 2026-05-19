import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: json['id'].toString(),
      fullName: json['fullName'].toString(),
      email: json['email'].toString(),
      role: json['role'].toString().trim().toUpperCase(),
      linkedPatientId: json['linkedPatientId']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}

class SessionController extends ChangeNotifier {
  SessionController({
    required this.apiClient,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final ApiClient apiClient;
  final FlutterSecureStorage _storage;

  SessionUser? user;
  bool isLoading = false;
  String? errorMessage;

  bool get isAuthenticated => user != null;

  Future<void> restore() async {
    final token = await _storage.read(key: 'accessToken');
    if (token == null) return;
    apiClient.setAccessToken(token);
    try {
      final response = await apiClient.getJson('/auth/me');
      user = SessionUser.fromJson(response['user'] as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {
      await logout();
    }
  }

  Future<void> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await apiClient.postJson('/auth/login', {
        'email': email.trim(),
        'password': password,
      });
      final accessToken = response['accessToken'].toString();
      apiClient.setAccessToken(accessToken);
      await _storage.write(key: 'accessToken', value: accessToken);
      await _storage.write(key: 'refreshToken', value: response['refreshToken'].toString());
      user = SessionUser.fromJson(response['user'] as Map<String, dynamic>);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
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
    isLoading = true;
    errorMessage = null;
    notifyListeners();
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
        'consentForAi': true,
        'consentForTeleExpertise': true,
      });
      final accessToken = response['accessToken'].toString();
      apiClient.setAccessToken(accessToken);
      await _storage.write(key: 'accessToken', value: accessToken);
      await _storage.write(key: 'refreshToken', value: response['refreshToken'].toString());
      user = SessionUser.fromJson(response['user'] as Map<String, dynamic>);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'refreshToken');
    apiClient.setAccessToken(null);
    user = null;
    notifyListeners();
  }
}
