import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import 'dream_dto.dart';

class DreamRepository {
  final Dio _dio;
  DreamRepository() : _dio = dioInstance;

  Future<DreamResponse> interpret(DreamRequest req) async {
    final res = await _dio.post('/dreams/interpret', data: req.toJson());
    return DreamResponse.fromJson(res.data as Map<String, dynamic>);
  }
}
