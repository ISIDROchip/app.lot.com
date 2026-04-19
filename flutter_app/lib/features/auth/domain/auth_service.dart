import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/auth_repository.dart';
import '../data/auth_dto.dart';

class AuthService {
  final _repo = AuthRepository();
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> register(RegisterRequest req) =>
      _repo.register(req);

  Future<void> login(LoginRequest req) async {
    final res = await _repo.login(req);
    await _storage.write(key: 'jwt_token', value: res.token);
  }

  Future<void> logout() => _storage.delete(key: 'jwt_token');

  /// Decodes JWT payload without verifying signature (client-side only).
  Future<Map<String, dynamic>?> getTokenClaims() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> get isSuperAdmin async {
    final claims = await getTokenClaims();
    return claims?['is_super_admin'] == true;
  }

  Future<bool> get isAdmin async {
    final claims = await getTokenClaims();
    return claims?['is_admin'] == true || claims?['is_super_admin'] == true;
  }
}
