class DreamRequest {
  final String dreamText;
  const DreamRequest({required this.dreamText});
  Map<String, dynamic> toJson() => {'dreamText': dreamText};
}

class DreamResponse {
  final List<int> numbers;
  final List<String> keywords;
  DreamResponse({required this.numbers, required this.keywords});
  factory DreamResponse.fromJson(Map<String, dynamic> json) => DreamResponse(
        numbers: List<int>.from(json['numbers'] as List),
        keywords: List<String>.from(json['keywords'] as List),
      );
}
