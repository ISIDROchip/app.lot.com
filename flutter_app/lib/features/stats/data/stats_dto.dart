class FrequencyRecord {
  final int number;
  final int count;
  FrequencyRecord({required this.number, required this.count});
  factory FrequencyRecord.fromJson(Map<String, dynamic> json) =>
      FrequencyRecord(
          number: json['number'] as int, count: json['count'] as int);
}

class TrendsResponse {
  final List<int> mostFrequent;
  final List<int> leastFrequent;
  TrendsResponse({required this.mostFrequent, required this.leastFrequent});
  factory TrendsResponse.fromJson(Map<String, dynamic> json) => TrendsResponse(
        mostFrequent: List<int>.from(json['mostFrequent'] as List),
        leastFrequent: List<int>.from(json['leastFrequent'] as List),
      );
}

// ── Advanced Stats (LTFree equivalent) ────────────────────────────────────

class NumberWithZScore {
  final int number;
  final int frequency;
  final double zScore;
  NumberWithZScore(
      {required this.number, required this.frequency, required this.zScore});
  factory NumberWithZScore.fromJson(Map<String, dynamic> json) =>
      NumberWithZScore(
        number: json['number'] as int,
        frequency: json['frequency'] as int,
        zScore: (json['zScore'] as num).toDouble(),
      );
}

class PairFrequency {
  final int numberA;
  final int numberB;
  final int frequency;
  PairFrequency(
      {required this.numberA, required this.numberB, required this.frequency});
  factory PairFrequency.fromJson(Map<String, dynamic> json) => PairFrequency(
        numberA: json['numberA'] as int,
        numberB: json['numberB'] as int,
        frequency: json['frequency'] as int,
      );
}

class PositionFrequency {
  final int position;
  final int number;
  final int frequency;
  PositionFrequency(
      {required this.position, required this.number, required this.frequency});
  factory PositionFrequency.fromJson(Map<String, dynamic> json) =>
      PositionFrequency(
        position: json['position'] as int,
        number: json['number'] as int,
        frequency: json['frequency'] as int,
      );
}

class NumberCycle {
  final int number;
  final int drawsSinceLast;
  final double? avgCycle;
  NumberCycle(
      {required this.number,
      required this.drawsSinceLast,
      required this.avgCycle});
  factory NumberCycle.fromJson(Map<String, dynamic> json) => NumberCycle(
        number: json['number'] as int,
        drawsSinceLast: json['drawsSinceLast'] as int,
        avgCycle: json['avgCycle'] != null
            ? (json['avgCycle'] as num).toDouble()
            : null,
      );
}

class EvenOddRatio {
  final int evens;
  final int odds;
  EvenOddRatio({required this.evens, required this.odds});
  factory EvenOddRatio.fromJson(Map<String, dynamic> json) => EvenOddRatio(
        evens: json['evens'] as int,
        odds: json['odds'] as int,
      );
}

class SumRange {
  final String range;
  final int count;
  SumRange({required this.range, required this.count});
  factory SumRange.fromJson(Map<String, dynamic> json) => SumRange(
        range: json['range'] as String,
        count: json['count'] as int,
      );
}

class SegmentStat {
  final String segment;
  final int frequency;
  SegmentStat({required this.segment, required this.frequency});
  factory SegmentStat.fromJson(Map<String, dynamic> json) => SegmentStat(
        segment: json['segment'] as String,
        frequency: json['frequency'] as int,
      );
}

class AdvancedStats {
  final int totalDraws;
  final double mean;
  final double stdDev;
  final double median;
  final int mode;
  final List<NumberWithZScore> hotNumbers;
  final List<NumberWithZScore> coldNumbers;
  final List<PairFrequency> topPairs;
  final List<PositionFrequency> positionFrequency;
  final List<NumberCycle> cycles;
  final EvenOddRatio evenOddRatio;
  final List<SumRange> sumDistribution;
  final List<SegmentStat> segmentAnalysis;

  AdvancedStats({
    required this.totalDraws,
    required this.mean,
    required this.stdDev,
    required this.median,
    required this.mode,
    required this.hotNumbers,
    required this.coldNumbers,
    required this.topPairs,
    required this.positionFrequency,
    required this.cycles,
    required this.evenOddRatio,
    required this.sumDistribution,
    required this.segmentAnalysis,
  });

  factory AdvancedStats.fromJson(Map<String, dynamic> json) => AdvancedStats(
        totalDraws: json['totalDraws'] as int,
        mean: (json['mean'] as num).toDouble(),
        stdDev: (json['stdDev'] as num).toDouble(),
        median: (json['median'] as num).toDouble(),
        mode: json['mode'] as int,
        hotNumbers: (json['hotNumbers'] as List)
            .map((e) => NumberWithZScore.fromJson(e as Map<String, dynamic>))
            .toList(),
        coldNumbers: (json['coldNumbers'] as List)
            .map((e) => NumberWithZScore.fromJson(e as Map<String, dynamic>))
            .toList(),
        topPairs: (json['topPairs'] as List)
            .map((e) => PairFrequency.fromJson(e as Map<String, dynamic>))
            .toList(),
        positionFrequency: (json['positionFrequency'] as List)
            .map((e) => PositionFrequency.fromJson(e as Map<String, dynamic>))
            .toList(),
        cycles: (json['cycles'] as List)
            .map((e) => NumberCycle.fromJson(e as Map<String, dynamic>))
            .toList(),
        evenOddRatio: EvenOddRatio.fromJson(json['evenOddRatio'] as Map<String, dynamic>),
        sumDistribution: (json['sumDistribution'] as List)
            .map((e) => SumRange.fromJson(e as Map<String, dynamic>))
            .toList(),
        segmentAnalysis: (json['segmentAnalysis'] as List)
            .map((e) => SegmentStat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
