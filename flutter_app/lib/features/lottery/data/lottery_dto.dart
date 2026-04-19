class LotteryRequest {
  final String tipo;
  final String? lotteryId;
  const LotteryRequest({required this.tipo, this.lotteryId});
  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        if (lotteryId != null) 'lottery_id': lotteryId,
      };
}

class LotteryResponse {
  final String id, tipo, timestamp;
  final List<int> numbers;
  LotteryResponse({
    required this.id,
    required this.tipo,
    required this.numbers,
    required this.timestamp,
  });
  factory LotteryResponse.fromJson(Map<String, dynamic> json) =>
      LotteryResponse(
        id: json['id'] as String,
        tipo: json['tipo'] as String,
        numbers: List<int>.from(json['numbers'] as List),
        timestamp: json['timestamp'] as String,
      );
}

class HistoryRecord {
  final String id, type, createdAt;
  final List<int> numbers;
  HistoryRecord({
    required this.id,
    required this.type,
    required this.numbers,
    required this.createdAt,
  });
  factory HistoryRecord.fromJson(Map<String, dynamic> json) => HistoryRecord(
        id: json['id'] as String,
        type: (json['source'] as String?) ?? 'generated',
        numbers: List<int>.from(json['numbers'] as List),
        createdAt: json['created_at'] as String? ?? json['createdAt'] as String,
      );
}

class DailyUsageEntry {
  final int used;
  final int limit;
  final int remaining;
  const DailyUsageEntry(
      {required this.used, required this.limit, required this.remaining});
  factory DailyUsageEntry.fromJson(Map<String, dynamic> json) =>
      DailyUsageEntry(
        used: json['used'] as int,
        limit: json['limit'] as int,
        remaining: json['remaining'] as int,
      );
}

class DailyUsage {
  final DailyUsageEntry loto;
  final DailyUsageEntry pale;
  final DailyUsageEntry tripleta;
  final DailyUsageEntry numero;

  const DailyUsage(
      {required this.loto,
      required this.pale,
      required this.tripleta,
      required this.numero});

  factory DailyUsage.fromJson(Map<String, dynamic> json) => DailyUsage(
        loto: DailyUsageEntry.fromJson(json['Loto'] as Map<String, dynamic>),
        pale: DailyUsageEntry.fromJson(json['Pale'] as Map<String, dynamic>),
        tripleta:
            DailyUsageEntry.fromJson(json['Tripleta'] as Map<String, dynamic>),
        numero:
            DailyUsageEntry.fromJson(json['Número'] as Map<String, dynamic>),
      );

  DailyUsageEntry forTipo(String tipo) {
    switch (tipo) {
      case 'Loto':
        return loto;
      case 'Pale':
        return pale;
      case 'Tripleta':
        return tripleta;
      default:
        return numero;
    }
  }
}

// ── Lottery catalog ────────────────────────────────────────────────────────

class LotteryInfo {
  final String id;
  final String name;
  final String shortName;
  final int numbersCount;
  final int numberRange;
  final List<int> drawDays;
  final String? scraperUrl;

  const LotteryInfo({
    required this.id,
    required this.name,
    required this.shortName,
    required this.numbersCount,
    required this.numberRange,
    required this.drawDays,
    this.scraperUrl,
  });

  factory LotteryInfo.fromJson(Map<String, dynamic> json) => LotteryInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        shortName: json['short_name'] as String,
        numbersCount: json['numbers_count'] as int,
        numberRange: json['number_range'] as int,
        drawDays: List<int>.from(json['draw_days'] as List),
        scraperUrl: json['scraper_url'] as String?,
      );

  /// Icon based on lottery name
  String get emoji {
    if (name.toLowerCase().contains('loto más') ||
        name.toLowerCase().contains('loto mas')) return '🎯';
    if (name.toLowerCase().contains('real')) return '👑';
    if (name.toLowerCase().contains('kino')) return '🎰';
    if (name.toLowerCase().contains('pale') ||
        name.toLowerCase().contains('quiniela')) return '🎲';
    if (name.toLowerCase().contains('nacional')) return '🏆';
    return '🎱';
  }

  /// Draw days as readable string
  String get drawDaysLabel {
    const days = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    return drawDays.map((d) => days[d % 7]).join(', ');
  }
}
