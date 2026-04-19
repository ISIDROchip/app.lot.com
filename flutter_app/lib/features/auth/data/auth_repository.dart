import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import 'auth_dto.dart';

class AuthRepository {
  final Dio _dio;
  AuthRepository() : _dio = dioInstance;

  Future<Map<String, dynamic>> register(RegisterRequest req) async {
    final res = await _dio.post('/users/register', data: req.toJson());
    return res.data as Map<String, dynamic>;
  }

  Future<LoginResponse> login(LoginRequest req) async {
    final res = await _dio.post('/users/login', data: req.toJson());
    return LoginResponse.fromJson(res.data as Map<String, dynamic>);
  }
}
