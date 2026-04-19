import '../data/stats_repository.dart';
import '../data/stats_dto.dart';

class StatsService {
  final _repo = StatsRepository();

  Future<List<FrequencyRecord>> getFrequency() => _repo.getFrequency();
  Future<TrendsResponse> getTrends() => _repo.getTrends();
  Future<AdvancedStats> getAdvancedStats() => _repo.getAdvancedStats();
}
