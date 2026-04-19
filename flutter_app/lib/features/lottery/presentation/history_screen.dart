import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../data/lottery_dto.dart';
import '../domain/lottery_service.dart';

// ── Contract group model ───────────────────────────────────────────────────

class _PlayResult {
  final String id;
  final List<int> numbers;
  final String createdAt;
  final List<int> matchedNumbers;
  final bool isWinner;

  _PlayResult({
    required this.id,
    required this.numbers,
    required this.createdAt,
    required this.matchedNumbers,
    required this.isWinner,
  });

  factory _PlayResult.fromJson(Map<String, dynamic> json) => _PlayResult(
        id: json['id'] as String,
        numbers: List<int>.from(json['numbers'] as List),
        createdAt: json['createdAt'] as String? ?? json['created_at'] as String,
        matchedNumbers: List<int>.from(json['matchedNumbers'] as List),
        isWinner: json['isWinner'] as bool,
      );
}

class _ContractGroup {
  final String contractId;
  final String signedAt;
  final String expiresAt;
  final bool isActive;
  final List<_PlayResult> plays;

  _ContractGroup({
    required this.contractId,
    required this.signedAt,
    required this.expiresAt,
    required this.isActive,
    required this.plays,
  });

  factory _ContractGroup.fromJson(Map<String, dynamic> json) => _ContractGroup(
        contractId: json['contractId'] as String,
        signedAt: json['signedAt'] as String,
        expiresAt: json['expiresAt'] as String,
        isActive: json['isActive'] as bool,
        plays: (json['plays'] as List)
            .map((e) => _PlayResult.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── Screen ─────────────────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  final _service = LotteryService();
  final _dio = dioInstance;

  // Contract groups (pull_10)
  List<_ContractGroup> _contractGroups = [];
  // Regular plays
  final List<HistoryRecord> _records = [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _showOnlyMatches = false;

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadContractGroups(), _loadRegularPlays()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadContractGroups() async {
    try {
      final res = await _dio.get('/users/history/contracts');
      final data = res.data as Map<String, dynamic>;
      final groups = (data['data'] as List)
          .map((e) => _ContractGroup.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() => _contractGroups = groups);
    } catch (_) {}
  }

  Future<void> _loadRegularPlays() async {
    try {
      final data = await _service.getHistory(page: 1, limit: 50);
      final items = (data['data'] as List)
          .map((e) => HistoryRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _records.clear();
          _records.addAll(items);
          _total = data['total'] as int;
          _page = 2;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMorePlays() async {
    if (_loadingMore || _records.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final data = await _service.getHistory(page: _page);
      final items = (data['data'] as List)
          .map((e) => HistoryRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _records.addAll(items);
        _page++;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _fmt(String iso) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  String _fmtFull(String iso) {
    try {
      return DateFormat('dd MMM yyyy · HH:mm')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: LuxoraColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.history_rounded,
                        color: LuxoraColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('MI HISTORIAL',
                      style: TextStyle(
                          color: LuxoraColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _showOnlyMatches
                          ? Icons.filter_alt_rounded
                          : Icons.filter_alt_outlined,
                      color: _showOnlyMatches
                          ? LuxoraColors.accent
                          : LuxoraColors.textSecondary,
                    ),
                    onPressed: () =>
                        setState(() => _showOnlyMatches = !_showOnlyMatches),
                    tooltip: 'Filtrar por coincidencias',
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: LuxoraColors.textSecondary),
                    onPressed: _loading ? null : _loadAll,
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: LuxoraColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LuxoraColors.divider),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFE07820), Color(0xFFC8620A)]),
                  borderRadius: BorderRadius.circular(9),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: LuxoraColors.textSecondary,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: 'Jugadas Entregadas (${_contractGroups.length})'),
                  Tab(text: 'Otras Jugadas ($_total)'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _buildContractGroups(),
                        _buildRegularPlays(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Pull de 10 agrupado por contrato ────────────────────────────

  Widget _buildContractGroups() {
    final filtered = _showOnlyMatches
        ? _contractGroups
            .where((g) => g.plays.any((p) => p.matchedNumbers.isNotEmpty))
            .toList()
        : _contractGroups;

    if (filtered.isEmpty) {
      return _buildEmpty(
          _showOnlyMatches
              ? 'No hay jugadas con coincidencias'
              : 'No tienes Jugadas Entregadas aún',
          'Firma un contrato y genera tu primer pull');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _buildContractCard(filtered[i]),
    );
  }

  Widget _buildContractCard(_ContractGroup group) {
    final hasWinner = group.plays.any((p) => p.isWinner);
    final hasMatch = group.plays.any((p) => p.matchedNumbers.isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: LuxoraColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasWinner
              ? Colors.green.withValues(alpha: 0.6)
              : hasMatch
                  ? LuxoraColors.accent.withValues(alpha: 0.4)
                  : LuxoraColors.divider,
          width: hasWinner || hasMatch ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contract header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: group.isActive
                  ? LuxoraColors.primary.withValues(alpha: 0.08)
                  : LuxoraColors.background,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(
                  group.isActive
                      ? Icons.verified_rounded
                      : Icons.history_toggle_off_rounded,
                  color: group.isActive
                      ? LuxoraColors.primary
                      : LuxoraColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.isActive
                            ? 'Jugada entregada activa'
                            : 'Jugada entregada terminada',
                        style: TextStyle(
                          color: group.isActive
                              ? LuxoraColors.primary
                              : LuxoraColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Generada: ${_fmt(group.signedAt)}',
                        style: const TextStyle(
                            color: LuxoraColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (hasWinner)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.4)),
                    ),
                    child: const Text('🏆 GANADOR',
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  )
                else if (hasMatch)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: LuxoraColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('✨ MATCH',
                        style: TextStyle(
                            color: LuxoraColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),

          // Plays
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: group.plays.asMap().entries.map((e) {
                final idx = e.key;
                final play = e.value;
                return _buildPlayRow(idx + 1, play);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayRow(int index, _PlayResult play) {
    final hasAnyMatch = play.matchedNumbers.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: play.isWinner
            ? Colors.green.withValues(alpha: 0.08)
            : hasAnyMatch
                ? LuxoraColors.accent.withValues(alpha: 0.05)
                : LuxoraColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: play.isWinner
              ? Colors.green.withValues(alpha: 0.4)
              : hasAnyMatch
                  ? LuxoraColors.accent.withValues(alpha: 0.3)
                  : LuxoraColors.divider,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text('$index',
                style: const TextStyle(
                    color: LuxoraColors.textSecondary, fontSize: 11)),
          ),
          Expanded(
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: play.numbers.map((n) {
                final isMatched = play.matchedNumbers.contains(n);
                return Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isMatched
                        ? const RadialGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF1B5E20)],
                            center: Alignment(-0.3, -0.3),
                          )
                        : const RadialGradient(
                            colors: [Color(0xFFE07820), Color(0xFF7A3A00)],
                            center: Alignment(-0.3, -0.3),
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: isMatched
                            ? Colors.green.withValues(alpha: 0.5)
                            : LuxoraColors.primary.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text('$n',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ),
          ),
          if (hasAnyMatch)
            Text(
              '${play.matchedNumbers.length}/6',
              style: TextStyle(
                color: play.isWinner ? Colors.green : LuxoraColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  // ── Tab 2: Regular plays ───────────────────────────────────────────────

  Widget _buildRegularPlays() {
    // Note: Regular plays might not have matchedNumbers field in the record yet,
    // so we handle it gracefully.
    final filtered = _showOnlyMatches
        ? _records.where((r) {
            // Check if there are matches in meta or numbers (mock/dummy logic for now if not available)
            // If backend doesn't support matches for regular plays yet, this will be empty.
            return false; 
          }).toList()
        : _records;

    if (filtered.isEmpty) {
      return _buildEmpty(
          _showOnlyMatches
              ? 'No hay jugadas con coincidencias'
              : 'No tienes jugadas aún',
          'Genera tu primera jugada');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length + (_showOnlyMatches ? 0 : 1),
      itemBuilder: (_, i) {
        if (i == filtered.length) {
          if (filtered.length >= _total) return const SizedBox(height: 80);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: OutlinedButton(
              onPressed: _loadingMore ? null : _loadMorePlays,
              child: _loadingMore
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Cargar más'),
            ),
          );
        }
        final r = _records[i];
        final isDream = r.type == 'dream';
        final color = isDream ? LuxoraColors.accent : LuxoraColors.primary;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: LuxoraColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LuxoraColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDream ? Icons.nights_stay_rounded : Icons.casino_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: r.numbers
                          .map((n) => Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const RadialGradient(
                                    colors: [
                                      Color(0xFFE07820),
                                      Color(0xFF7A3A00)
                                    ],
                                    center: Alignment(-0.3, -0.3),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: LuxoraColors.primary
                                          .withValues(alpha: 0.4),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text('$n',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 5),
                    Text(_fmtFull(r.createdAt),
                        style: const TextStyle(
                            color: LuxoraColors.textSecondary, fontSize: 10)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDream ? 'Sueño' : 'Jugada',
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              size: 64,
              color: LuxoraColors.textSecondary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: LuxoraColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  color: LuxoraColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
