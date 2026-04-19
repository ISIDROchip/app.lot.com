import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import 'stats_dto.dart';

class StatsRepository {
  final Dio _dio;
  StatsRepository() : _dio = dioInstance;

  Future<List<FrequencyRecord>> getFrequency() async {
    final res = await _dio.get('/stats/frequency');
    final data = res.data as Map<String, dynamic>;
    return (data['frequencies'] as List)
        .map((e) => FrequencyRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TrendsResponse> getTrends() async {
    final res = await _dio.get('/stats/trends');
    return TrendsResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AdvancedStats> getAdvancedStats() async {
    final res = await _dio.get('/stats/advanced');
    return AdvancedStats.fromJson(res.data as Map<String, dynamic>);
  }
}
