import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import 'lottery_dto.dart';

class LotteryRepository {
  final Dio _dio;
  LotteryRepository() : _dio = dioInstance;

  Future<LotteryResponse> requestNumber(LotteryRequest req) async {
    final res = await _dio.post('/lottery/request-number', data: req.toJson());
    return LotteryResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getHistory(
      {int page = 1, int limit = 20}) async {
    final res = await _dio.get('/users/history', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<DailyUsage> getDailyUsage() async {
    final res = await _dio.get('/lottery/daily-usage');
    return DailyUsage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<LotteryInfo>> getLotteries() async {
    final res = await _dio.get('/lotteries');
    final data = res.data as Map<String, dynamic>;
    return (data['data'] as List)
        .map((e) => LotteryInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
