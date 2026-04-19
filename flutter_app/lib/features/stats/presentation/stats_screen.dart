import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';
import '../data/stats_dto.dart';
import '../domain/stats_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  final _service = StatsService();
  AdvancedStats? _stats;
  List<FrequencyRecord> _frequencies = [];
  bool _loading = true;
  String? _error;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getAdvancedStats(),
        _service.getFrequency(),
      ]);
      setState(() {
        _stats = results[0] as AdvancedStats;
        _frequencies = results[1] as List<FrequencyRecord>;
      });
    } catch (_) {
      setState(() => _error = 'Error al cargar estadísticas');
    } finally {
      if (mounted) setState(() => _loading = false);
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: LuxoraColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.analytics_rounded,
                        color: LuxoraColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ESTADÍSTICAS',
                          style: TextStyle(
                              color: LuxoraColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1)),
                      if (_stats != null)
                        Text('${_stats!.totalDraws} sorteos analizados',
                            style: const TextStyle(
                                color: LuxoraColors.textSecondary,
                                fontSize: 11)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: LuxoraColors.textSecondary),
                    onPressed: _loading ? null : _load,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

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
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFE07820), Color(0xFFC8620A)]),
                  borderRadius: BorderRadius.circular(9),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: LuxoraColors.textSecondary,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Resumen'),
                  Tab(text: 'Calientes'),
                  Tab(text: 'Frecuencias'),
                  Tab(text: 'Pares'),
                  Tab(text: 'Posición'),
                  Tab(text: 'Patrones'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : _stats == null
                          ? _buildNoData()
                          : TabBarView(
                              controller: _tabCtrl,
                              children: [
                                _buildResumen(),
                                _buildCalientes(),
                                _buildFrecuencias(),
                                _buildPares(),
                                _buildPosicion(),
                                _buildPatrones(),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Resumen (media, desviación, mediana, moda) ──────────────────

  Widget _buildResumen() {
    final s = _stats!;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Stats grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _StatCard(
                label: 'Media',
                value: s.mean.toStringAsFixed(2),
                icon: Icons.show_chart_rounded,
                color: LuxoraColors.primary),
            _StatCard(
                label: 'Desv. Estándar',
                value: s.stdDev.toStringAsFixed(2),
                icon: Icons.bar_chart_rounded,
                color: LuxoraColors.accent),
            _StatCard(
                label: 'Mediana',
                value: s.median.toStringAsFixed(1),
                icon: Icons.linear_scale_rounded,
                color: const Color(0xFF9C27B0)),
            _StatCard(
                label: 'Moda',
                value: '${s.mode}',
                icon: Icons.star_rounded,
                color: LuxoraColors.primary),
          ],
        ),
        const SizedBox(height: 16),

        // Cycles — números vencidos
        if (s.cycles.isNotEmpty) ...[
          _SectionHeader(
              title: 'NÚMEROS VENCIDOS', subtitle: 'Sin aparecer más sorteos'),
          const SizedBox(height: 10),
          ...s.cycles.take(5).map((c) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: LuxoraColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: c.drawsSinceLast > 10
                        ? LuxoraColors.accent.withValues(alpha: 0.4)
                        : LuxoraColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: LuxoraColors.accent.withValues(alpha: 0.15),
                        border: Border.all(
                            color: LuxoraColors.accent.withValues(alpha: 0.4)),
                      ),
                      alignment: Alignment.center,
                      child: Text('${c.number}',
                          style: const TextStyle(
                              color: LuxoraColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${c.drawsSinceLast} sorteos sin aparecer',
                              style: const TextStyle(
                                  color: LuxoraColors.textPrimary,
                                  fontSize: 13)),
                          if (c.avgCycle != null)
                            Text(
                                'Ciclo promedio: ${c.avgCycle!.toStringAsFixed(1)} sorteos',
                                style: const TextStyle(
                                    color: LuxoraColors.textSecondary,
                                    fontSize: 11)),
                        ],
                      ),
                    ),
                    if (c.drawsSinceLast > 10)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: LuxoraColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('VENCIDO',
                            style: TextStyle(
                                color: LuxoraColors.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              )),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  // ── Tab 2: Calientes y Fríos ───────────────────────────────────────────

  Widget _buildCalientes() {
    final s = _stats!;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _SectionHeader(
            title: 'NÚMEROS CALIENTES',
            subtitle: 'Z-score positivo — aparecen más que el promedio'),
        const SizedBox(height: 10),
        ...s.hotNumbers.map((n) => _ZScoreRow(item: n, isHot: true)),
        const SizedBox(height: 20),
        _SectionHeader(
            title: 'NÚMEROS FRÍOS',
            subtitle: 'Z-score negativo — aparecen menos que el promedio'),
        const SizedBox(height: 10),
        ...s.coldNumbers.map((n) => _ZScoreRow(item: n, isHot: false)),
        const SizedBox(height: 80),
      ],
    );
  }

  // ── Tab 3: Frecuencias ─────────────────────────────────────────────────

  Widget _buildFrecuencias() {
    if (_frequencies.isEmpty) return _buildNoData();
    final maxCount =
        _frequencies.first.count > 0 ? _frequencies.first.count : 1;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _frequencies.length + 1,
      itemBuilder: (_, i) {
        if (i == _frequencies.length) return const SizedBox(height: 80);
        final f = _frequencies[i];
        final ratio = f.count / maxCount;
        final isTop3 = i < 3;
        return Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: LuxoraColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isTop3
                  ? LuxoraColors.primary.withValues(alpha: 0.4)
                  : LuxoraColors.divider,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                  width: 22,
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: isTop3
                              ? LuxoraColors.primary
                              : LuxoraColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold))),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isTop3
                      ? const RadialGradient(
                          colors: [Color(0xFFE07820), Color(0xFF7A3A00)],
                          center: Alignment(-0.3, -0.3),
                        )
                      : null,
                  color: isTop3
                      ? null
                      : LuxoraColors.primary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: isTop3
                        ? LuxoraColors.accent.withValues(alpha: 0.4)
                        : LuxoraColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text('${f.number}',
                    style: TextStyle(
                        color: isTop3 ? Colors.white : LuxoraColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 7,
                    backgroundColor: LuxoraColors.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isTop3
                          ? LuxoraColors.primary
                          : LuxoraColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${f.count}',
                  style: TextStyle(
                      color: isTop3
                          ? LuxoraColors.primary
                          : LuxoraColors.textSecondary,
                      fontSize: 11,
                      fontWeight:
                          isTop3 ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 4: Pares frecuentes ────────────────────────────────────────────

  Widget _buildPares() {
    final pairs = _stats!.topPairs;
    if (pairs.isEmpty) return _buildNoData();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _SectionHeader(
            title: 'PARES MÁS FRECUENTES',
            subtitle: 'Números que salen juntos con más frecuencia'),
        const SizedBox(height: 10),
        ...pairs.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LuxoraColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LuxoraColors.divider),
            ),
            child: Row(
              children: [
                Text('${i + 1}',
                    style: const TextStyle(
                        color: LuxoraColors.textSecondary, fontSize: 11)),
                const SizedBox(width: 12),
                _SmallBall(number: p.numberA),
                const SizedBox(width: 6),
                const Text('+',
                    style: TextStyle(
                        color: LuxoraColors.textSecondary, fontSize: 16)),
                const SizedBox(width: 6),
                _SmallBall(number: p.numberB),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: LuxoraColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${p.frequency}x',
                      style: const TextStyle(
                          color: LuxoraColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }

  // ── Tab 5: Frecuencia por posición ────────────────────────────────────

  // ── Tab 6: Patrones (Par/Impar, Sumas, Segmentos) ────────────────────

  Widget _buildPatrones() {
    final s = _stats!;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Even/Odd Balance
        _SectionHeader(
            title: 'BALANCE PAR / IMPAR',
            subtitle: 'Distribución porcentual de los números extraídos'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: LuxoraColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LuxoraColors.divider),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _PatternIndicator(
                      label: 'PARES',
                      percent: s.evenOddRatio.evens,
                      color: LuxoraColors.primary),
                  const SizedBox(width: 20),
                  _PatternIndicator(
                      label: 'IMPARES',
                      percent: s.evenOddRatio.odds,
                      color: LuxoraColors.accent),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      Expanded(
                          flex: s.evenOddRatio.evens,
                          child: Container(color: LuxoraColors.primary)),
                      Expanded(
                          flex: s.evenOddRatio.odds,
                          child: Container(color: LuxoraColors.accent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Sum Distribution
        _SectionHeader(
            title: 'DISTRIBUCIÓN DE SUMAS',
            subtitle: 'Frecuencia de la suma total de los bolos'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LuxoraColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LuxoraColors.divider),
          ),
          child: Column(
            children: s.sumDistribution.map((sd) {
              final maxCount = s.sumDistribution
                  .fold(0, (prev, e) => e.count > prev ? e.count : prev);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                        width: 60,
                        child: Text(sd.range,
                            style: const TextStyle(
                                color: LuxoraColors.textSecondary,
                                fontSize: 11))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: sd.count / (maxCount == 0 ? 1 : maxCount),
                          minHeight: 8,
                          backgroundColor: LuxoraColors.divider,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF9C27B0)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${sd.count}',
                        style: const TextStyle(
                            color: LuxoraColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),

        // Segment Analysis
        _SectionHeader(
            title: 'ACTIVIDAD POR SEGMENTO',
            subtitle: 'Frecuencia de aparición por rangos de números'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: s.segmentAnalysis.map((sa) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: LuxoraColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LuxoraColors.divider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 24,
                    decoration: BoxDecoration(
                      color: LuxoraColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sa.segment,
                            style: const TextStyle(
                                color: LuxoraColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        Text('${sa.frequency} apariciones',
                            style: const TextStyle(
                                color: LuxoraColors.textSecondary,
                                fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildPosicion() {
    final posFreqs = _stats!.positionFrequency;
    if (posFreqs.isEmpty) return _buildNoData();

    // Group by position
    final Map<int, List<PositionFrequency>> byPos = {};
    for (final pf in posFreqs) {
      byPos.putIfAbsent(pf.position, () => []).add(pf);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _SectionHeader(
            title: 'FRECUENCIA POR POSICIÓN',
            subtitle: 'Top 3 números más frecuentes en cada posición'),
        const SizedBox(height: 10),
        ...byPos.entries.map((entry) {
          final pos = entry.key;
          final items = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LuxoraColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LuxoraColors.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: LuxoraColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text('P$pos',
                      style: const TextStyle(
                          color: LuxoraColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: items
                        .map((pf) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Column(
                                children: [
                                  _SmallBall(number: pf.number),
                                  const SizedBox(height: 3),
                                  Text('${pf.frequency}x',
                                      style: const TextStyle(
                                          color: LuxoraColors.textSecondary,
                                          fontSize: 9)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_rounded,
                size: 64,
                color: LuxoraColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );

  Widget _buildNoData() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 64, color: Color(0x33FFFFFF)),
            SizedBox(height: 16),
            Text('Sin datos — carga resultados históricos primero',
                style: TextStyle(color: LuxoraColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      );
}

// ── Widgets ────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: LuxoraColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: const TextStyle(
                color: LuxoraColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LuxoraColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color, fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label,
                  style: const TextStyle(
                      color: LuxoraColors.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZScoreRow extends StatelessWidget {
  final NumberWithZScore item;
  final bool isHot;
  const _ZScoreRow({required this.item, required this.isHot});

  @override
  Widget build(BuildContext context) {
    final color = isHot ? LuxoraColors.primary : LuxoraColors.textSecondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LuxoraColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LuxoraColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isHot
                  ? const RadialGradient(
                      colors: [Color(0xFFE07820), Color(0xFF7A3A00)],
                      center: Alignment(-0.3, -0.3),
                    )
                  : null,
              color: isHot ? null : LuxoraColors.surface,
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Text('${item.number}',
                style: TextStyle(
                    color: isHot ? Colors.white : LuxoraColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Frecuencia: ${item.frequency}',
                    style: const TextStyle(
                        color: LuxoraColors.textPrimary, fontSize: 12)),
                Text(
                    'Z-score: ${item.zScore > 0 ? '+' : ''}${item.zScore.toStringAsFixed(2)}',
                    style: TextStyle(color: color, fontSize: 11)),
              ],
            ),
          ),
          Container(
            width: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (item.zScore.abs() / 3).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: LuxoraColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBall extends StatelessWidget {
  final int number;
  const _SmallBall({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFE07820), Color(0xFF7A3A00)],
          center: Alignment(-0.3, -0.3),
        ),
        boxShadow: [
          BoxShadow(
              color: LuxoraColors.primary.withValues(alpha: 0.4),
              blurRadius: 6),
        ],
      ),
      alignment: Alignment.center,
      child: Text('$number',
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
class _PatternIndicator extends StatelessWidget {
  final String label;
  final int percent;
  final Color color;
  const _PatternIndicator(
      {required this.label, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$percent%',
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: LuxoraColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
