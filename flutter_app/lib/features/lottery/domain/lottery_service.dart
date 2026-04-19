import '../data/lottery_repository.dart';
import '../data/lottery_dto.dart';

class LotteryService {
  final _repo = LotteryRepository();

  Future<LotteryResponse> requestNumber(String tipo, {String? lotteryId}) =>
      _repo.requestNumber(LotteryRequest(tipo: tipo, lotteryId: lotteryId));

  Future<Map<String, dynamic>> getHistory({int page = 1, int limit = 20}) =>
      _repo.getHistory(page: page, limit: limit);

  Future<DailyUsage> getDailyUsage() => _repo.getDailyUsage();
  Future<List<LotteryInfo>> getLotteries() => _repo.getLotteries();
}
