import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';

class ScraperScreen extends StatefulWidget {
  const ScraperScreen({super.key});

  @override
  State<ScraperScreen> createState() => _ScraperScreenState();
}

class _ScraperScreenState extends State<ScraperScreen> {
  final _dio = dioInstance;

  // Form fields
  final _urlCtrl = TextEditingController(
    text: 'https://loteriasdominicanas.com/leidsa/loto-mas',
  );
  DateTime _dateFrom = DateTime(2024, 1, 1);
  DateTime _dateTo = DateTime.now();
  final List<int> _weekDays = [3, 6]; // Wed=3, Sat=6
  int _delayMs = 1500;

  // Job state
  String? _jobId; // used to track polling and reset
  Map<String, dynamic>? _progress;
  Timer? _pollTimer;
  bool _starting = false;
  final ScrollController _logScroll = ScrollController();

  @override
  void dispose() {
    _pollTimer?.cancel();
    _urlCtrl.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _dateFrom : _dateTo,
      firstDate: DateTime(2018),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: LuxoraColors.primary,
            surface: LuxoraColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom)
          _dateFrom = picked;
        else
          _dateTo = picked;
      });
    }
  }

  Future<void> _startScraper() async {
    setState(() => _starting = true);
    try {
      final res = await _dio.post('/admin/scraper/run', data: {
        'baseUrl': _urlCtrl.text.trim(),
        'dateFrom': DateFormat('yyyy-MM-dd').format(_dateFrom),
        'dateTo': DateFormat('yyyy-MM-dd').format(_dateTo),
        'weekDays': _weekDays,
        'delayMs': _delayMs,
      });
      final jobId = res.data['jobId'] as String;
      setState(() => _jobId = jobId);
      _startPolling(jobId);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? e.response!.data['error']
          : 'Error al iniciar el scraper';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _startPolling(String jobId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final res = await _dio.get('/admin/scraper/progress/$jobId');
        final data = res.data as Map<String, dynamic>;
        if (mounted) {
          setState(() => _progress = data);
          // Auto-scroll log to bottom
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_logScroll.hasClients) {
              _logScroll.animateTo(
                _logScroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
          // Stop polling when done
          if (data['status'] == 'completed' || data['status'] == 'error') {
            _pollTimer?.cancel();
          }
        }
      } catch (_) {}
    });
  }

  void _reset() {
    _pollTimer?.cancel();
    setState(() {
      _jobId = null;
      _progress = null;
    });
  }

  bool get _isRunning => _progress?['status'] == 'running';
  bool get _isDone =>
      _progress?['status'] == 'completed' || _progress?['status'] == 'error';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(title: const Text('CARGA DE RESULTADOS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Config card ──────────────────────────────────────────
            _SectionCard(
              title: 'CONFIGURACIÓN',
              icon: Icons.settings_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // URL
                  TextFormField(
                    controller: _urlCtrl,
                    enabled: !_isRunning,
                    decoration: const InputDecoration(
                      labelText: 'URL base del sitio',
                      prefixIcon: Icon(Icons.link,
                          color: LuxoraColors.textSecondary, size: 18),
                    ),
                    style: const TextStyle(
                        color: LuxoraColors.textPrimary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Date range
                  Row(
                    children: [
                      Expanded(
                        child: _DateButton(
                          label: 'Desde',
                          date: _dateFrom,
                          enabled: !_isRunning,
                          onTap: () => _pickDate(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateButton(
                          label: 'Hasta',
                          date: _dateTo,
                          enabled: !_isRunning,
                          onTap: () => _pickDate(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Week days
                  Text('Días de sorteo',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _DayChip(
                          label: 'Lun',
                          value: 1,
                          selected: _weekDays.contains(1),
                          enabled: !_isRunning,
                          onToggle: _toggleDay),
                      _DayChip(
                          label: 'Mar',
                          value: 2,
                          selected: _weekDays.contains(2),
                          enabled: !_isRunning,
                          onToggle: _toggleDay),
                      _DayChip(
                          label: 'Mié',
                          value: 3,
                          selected: _weekDays.contains(3),
                          enabled: !_isRunning,
                          onToggle: _toggleDay),
                      _DayChip(
                          label: 'Jue',
                          value: 4,
                          selected: _weekDays.contains(4),
                          enabled: !_isRunning,
                          onToggle: _toggleDay),
                      _DayChip(
                          label: 'Vie',
                          value: 5,
                          selected: _weekDays.contains(5),
                          enabled: !_isRunning,
                          onToggle: _toggleDay),
                      _DayChip(
                          label: 'Sáb',
                          value: 6,
                          selected: _weekDays.contains(6),
                          enabled: !_isRunning,
                          onToggle: _toggleDay),
                      _DayChip(
                          label: 'Dom',
                          value: 0,
                          selected: _weekDays.contains(0),
                          enabled: !_isRunning,
                          onToggle: _toggleDay),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Delay
                  Row(
                    children: [
                      Text('Espera entre requests: ${_delayMs}ms',
                          style: Theme.of(context).textTheme.bodySmall),
                      const Spacer(),
                      Slider(
                        value: _delayMs.toDouble(),
                        min: 500,
                        max: 5000,
                        divisions: 9,
                        activeColor: LuxoraColors.primary,
                        onChanged: _isRunning
                            ? null
                            : (v) => setState(() => _delayMs = v.toInt()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Action button ────────────────────────────────────────
            if (!_isRunning && !_isDone)
              ElevatedButton.icon(
                onPressed: _starting ? null : _startScraper,
                icon: _starting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_starting ? 'Iniciando...' : 'EJECUTAR SCRAPER'),
              ),

            if (_isDone)
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Nueva ejecución'),
              ),

            // ── Progress ─────────────────────────────────────────────
            if (_progress != null) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'PROGRESO',
                icon: Icons.analytics_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stats row
                    Row(
                      children: [
                        _StatBadge(
                          label: 'Total',
                          value: '${_progress!['total'] ?? 0}',
                          color: LuxoraColors.textSecondary,
                        ),
                        _StatBadge(
                          label: 'Insertados',
                          value: '${_progress!['inserted'] ?? 0}',
                          color: LuxoraColors.accent,
                        ),
                        _StatBadge(
                          label: 'Omitidos',
                          value: '${_progress!['skipped'] ?? 0}',
                          color: LuxoraColors.primary,
                        ),
                        _StatBadge(
                          label: 'Errores',
                          value: '${_progress!['errors'] ?? 0}',
                          color: LuxoraColors.error,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Progress bar
                    if ((_progress!['total'] ?? 0) > 0) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_progress!['processed'] ?? 0) /
                              (_progress!['total'] ?? 1),
                          minHeight: 8,
                          backgroundColor: LuxoraColors.divider,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _progress!['status'] == 'error'
                                ? LuxoraColors.error
                                : LuxoraColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_progress!['processed'] ?? 0} / ${_progress!['total'] ?? 0}  •  ${_progress!['currentDate'] ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isRunning)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: LuxoraColors.primary),
                            )
                          else
                            Icon(_statusIcon, color: _statusColor, size: 14),
                          const SizedBox(width: 6),
                          Text(_statusLabel,
                              style: TextStyle(
                                  color: _statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Log ────────────────────────────────────────────────
              _SectionCard(
                title: 'LOG DE EJECUCIÓN',
                icon: Icons.terminal_rounded,
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0820),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    controller: _logScroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: (_progress!['messages'] as List?)?.length ?? 0,
                    itemBuilder: (_, i) {
                      final msg = (_progress!['messages'] as List)[i] as String;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          msg,
                          style: TextStyle(
                            color: _logColor(msg),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleDay(int day) {
    setState(() {
      if (_weekDays.contains(day)) {
        _weekDays.remove(day);
      } else {
        _weekDays.add(day);
      }
    });
  }

  Color get _statusColor {
    switch (_progress?['status']) {
      case 'completed':
        return LuxoraColors.accent;
      case 'error':
        return LuxoraColors.error;
      default:
        return LuxoraColors.primary;
    }
  }

  IconData get _statusIcon {
    switch (_progress?['status']) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'error':
        return Icons.error_rounded;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  String get _statusLabel {
    switch (_progress?['status']) {
      case 'completed':
        return 'COMPLETADO';
      case 'error':
        return 'ERROR';
      default:
        return 'EN EJECUCIÓN';
    }
  }

  Color _logColor(String msg) {
    if (msg.contains('✓') || msg.contains('✅')) return LuxoraColors.accent;
    if (msg.contains('✗') || msg.contains('❌')) return LuxoraColors.error;
    if (msg.contains('⚠')) return const Color(0xFFFFB74D);
    if (msg.contains('⏭')) return LuxoraColors.textSecondary;
    if (msg.startsWith('Sincronizando') || msg.startsWith('Iniciando')) {
      return LuxoraColors.primary;
    }
    return LuxoraColors.textSecondary;
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuxoraColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LuxoraColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: LuxoraColors.primary, size: 16),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: LuxoraColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool enabled;
  final VoidCallback onTap;
  const _DateButton(
      {required this.label,
      required this.date,
      required this.enabled,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: LuxoraColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: LuxoraColors.divider),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                color:
                    enabled ? LuxoraColors.primary : LuxoraColors.textSecondary,
                size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: LuxoraColors.textSecondary, fontSize: 10)),
                Text(DateFormat('dd/MM/yyyy').format(date),
                    style: const TextStyle(
                        color: LuxoraColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final int value;
  final bool selected;
  final bool enabled;
  final void Function(int) onToggle;
  const _DayChip(
      {required this.label,
      required this.value,
      required this.selected,
      required this.enabled,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () => onToggle(value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? LuxoraColors.primary.withValues(alpha: 0.2)
              : LuxoraColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? LuxoraColors.primary : LuxoraColors.divider,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color:
                  selected ? LuxoraColors.primary : LuxoraColors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBadge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: LuxoraColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}
