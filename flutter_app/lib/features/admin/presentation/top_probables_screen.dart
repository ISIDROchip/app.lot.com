import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class TopProbablesScreen extends StatefulWidget {
  const TopProbablesScreen({super.key});

  @override
  State<TopProbablesScreen> createState() => _TopProbablesScreenState();
}

class _TopProbablesScreenState extends State<TopProbablesScreen> {
  List<dynamic> _combinations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTopCombinations();
  }

  Future<void> _fetchTopCombinations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await dioInstance.get('/admin/engine/top-combinations');
      setState(() {
        _combinations = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error al cargar las mejores combinaciones: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(
        title: const Text('TOP 10 PROBABILIDADES'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchTopCombinations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: LuxoraColors.error, size: 48),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: LuxoraColors.error), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _fetchTopCombinations,
                          child: const Text('REINTENTAR'),
                        ),
                      ],
                    ),
                  ),
                )
              : _combinations.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay combinaciones en el pool.\nGenera algunas desde el Panel del Motor.',
                        style: TextStyle(color: LuxoraColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _combinations.length,
                      itemBuilder: (context, index) {
                        final combo = _combinations[index];
                        final List<int> numbers = List<int>.from(combo['numbers']);
                        final double score = (combo['score'] as num).toDouble();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                LuxoraColors.surface,
                                LuxoraColors.primary.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: index == 0 
                                  ? LuxoraColors.primary.withValues(alpha: 0.5) 
                                  : LuxoraColors.divider,
                              width: index == 0 ? 2 : 1,
                            ),
                            boxShadow: index == 0 ? [
                              BoxShadow(
                                color: LuxoraColors.primary.withValues(alpha: 0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )
                            ] : [],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: index == 0 ? LuxoraColors.primary : LuxoraColors.divider,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'TOP ${index + 1}',
                                          style: TextStyle(
                                            color: index == 0 ? Colors.white : LuxoraColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      if (index == 0) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.star_rounded, color: LuxoraColors.primary, size: 18),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    'Score: ${score.toStringAsFixed(4)}',
                                    style: const TextStyle(
                                      color: LuxoraColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: numbers.map((n) => _NumberBall(number: n, isTop: index == 0)).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

class _NumberBall extends StatelessWidget {
  final int number;
  final bool isTop;
  const _NumberBall({required this.number, this.isTop = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isTop 
              ? [const Color(0xFFE07820), const Color(0xFF7A3A00)] 
              : [LuxoraColors.surface, LuxoraColors.divider],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isTop ? LuxoraColors.accent.withValues(alpha: 0.5) : LuxoraColors.divider,
          width: 1.5,
        ),
        boxShadow: isTop ? [
          BoxShadow(
            color: LuxoraColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ] : [],
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          color: isTop ? Colors.white : LuxoraColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
