import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart';
import '../../../shared/theme/app_theme.dart';
import '../data/lottery_dto.dart';
import '../domain/lottery_service.dart';
import '../../auth/domain/auth_service.dart';

class LotteryScreen extends StatefulWidget {
  const LotteryScreen({super.key});

  @override
  State<LotteryScreen> createState() => _LotteryScreenState();
}

class _LotteryScreenState extends State<LotteryScreen>
    with TickerProviderStateMixin {
  final _service = LotteryService();
  final _authService = AuthService();
  final _tipos = ['Loto', 'Pale', 'Tripleta', 'Número'];
  String _selectedTipo = 'Loto';
  bool _loading = false;
  String? _error;
  LotteryResponse? _result;
  int _activeNav = 0;
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  DailyUsage? _dailyUsage;
  List<LotteryInfo> _lotteries = [];
  LotteryInfo? _selectedLottery;

  late AnimationController _ballsCtrl;
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _ballsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerCtrl.forward();
    _authService.isAdmin.then((v) {
      if (mounted) setState(() => _isAdmin = v);
    });
    _authService.isSuperAdmin.then((v) {
      if (mounted) setState(() => _isSuperAdmin = v);
    });
    _loadDailyUsage();
    _loadLotteries();
  }

  Future<void> _loadLotteries() async {
    try {
      final list = await _service.getLotteries();
      if (mounted) {
        setState(() {
          _lotteries = list;
          if (list.isNotEmpty) _selectedLottery = list.first;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDailyUsage() async {
    try {
      final usage = await _service.getDailyUsage();
      if (mounted) setState(() => _dailyUsage = usage);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ballsCtrl.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  void _showLotteryDetail(LotteryInfo lot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: LuxoraColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(lot.emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lot.name,
                          style: const TextStyle(
                              color: LuxoraColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                      Text(lot.shortName,
                          style: const TextStyle(
                              color: LuxoraColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DetailRow(
                label: 'Números por jugada', value: '${lot.numbersCount}'),
            _DetailRow(
                label: 'Rango de números', value: '1 – ${lot.numberRange}'),
            _DetailRow(label: 'Días de sorteo', value: lot.drawDaysLabel),
            _DetailRow(label: 'Límite Loto/día', value: '1 jugada'),
            _DetailRow(
                label: 'Límite Pale/Tripleta/Número', value: '10 jugadas/día'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedLottery = lot;
                    _result = null;
                    _error = null;
                  });
                  _loadDailyUsage();
                },
                icon: const Icon(Icons.casino_rounded),
                label: Text('Jugar ${lot.name}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToPull10() async {
    if (!mounted) return;
    context.go('/pull-10');
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    _ballsCtrl.reset();
    try {
      final res = await _service.requestNumber(_selectedTipo,
          lotteryId: _selectedLottery?.id);
      setState(() => _result = res);
      _ballsCtrl.forward();
      _loadDailyUsage(); // refresh counters
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('429') || msg.contains('DAILY_LIMIT')) {
        setState(() => _error = _selectedTipo == 'Loto'
            ? 'Ya generaste tu jugada Loto de hoy. Vuelve mañana.'
            : 'Límite diario alcanzado para $_selectedTipo (10/día).');
      } else {
        setState(() => _error = 'Error al generar jugada. Intenta de nuevo');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  LuxoraColors.primary.withValues(alpha: 0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────
                FadeTransition(
                  opacity: _headerFade,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [Color(0xFFE07820), Color(0xFF7A3A00)],
                              center: Alignment(-0.3, -0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    LuxoraColors.primary.withValues(alpha: 0.5),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.star_rounded,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [LuxoraColors.accent, Colors.white],
                          ).createShader(b),
                          child: const Text(
                            'LUXORA BETIX',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined,
                              color: LuxoraColors.textSecondary),
                          onPressed: () async {
                            const AndroidNotificationDetails androidDetails =
                                AndroidNotificationDetails(
                              'luxora_channel',
                              'Luxora Notifications',
                              channelDescription: 'Notificaciones de Luxora',
                              importance: Importance.max,
                              priority: Priority.high,
                            );
                            const NotificationDetails details =
                                NotificationDetails(android: androidDetails);
                            await flutterLocalNotificationsPlugin.show(
                              0,
                              '¡Números generados!',
                              'Tus números de lotería están listos.',
                              details,
                            );
                          },
                        ),
                        if (_isAdmin)
                          IconButton(
                            icon: const Icon(Icons.admin_panel_settings_rounded,
                                color: LuxoraColors.primary),
                            onPressed: () => context.go('/admin'),
                            tooltip: 'Panel Admin',
                          ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded,
                              color: LuxoraColors.textSecondary),
                          onPressed: () async {
                            await _authService.logout();
                            if (mounted) context.go('/login');
                          },
                          tooltip: 'Cerrar sesión',
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Pull de 10 banner ──────────────────────────
                        GestureDetector(
                          onTap: _navigateToPull10,
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2A1A00), Color(0xFF1A1640)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color:
                                    LuxoraColors.primary.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: LuxoraColors.primary
                                      .withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: LuxoraColors.primary
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                      Icons.workspace_premium_rounded,
                                      color: LuxoraColors.primary,
                                      size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Pull de 10',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '10 combinaciones optimizadas',
                                        style: TextStyle(
                                          color: LuxoraColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: LuxoraColors.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'PREMIUM',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Lottery selector ───────────────────────────
                        if (_lotteries.isNotEmpty) ...[
                          Text(
                            'LOTERÍA',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(letterSpacing: 2, fontSize: 11),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _lotteries.map((lot) {
                                final selected = _selectedLottery?.id == lot.id;
                                return GestureDetector(
                                  onTap: () => setState(() {
                                    _selectedLottery = lot;
                                    _result = null;
                                    _error = null;
                                    _loadDailyUsage();
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(right: 10),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? LuxoraColors.primary
                                              .withValues(alpha: 0.15)
                                          : LuxoraColors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected
                                            ? LuxoraColors.primary
                                            : LuxoraColors.divider,
                                        width: selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(lot.emoji,
                                            style:
                                                const TextStyle(fontSize: 18)),
                                        const SizedBox(width: 8),
                                        Text(
                                          lot.name,
                                          style: TextStyle(
                                            color: selected
                                                ? LuxoraColors.primary
                                                : LuxoraColors.textSecondary,
                                            fontWeight: selected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Selected lottery card ──────────────────
                          if (_selectedLottery != null)
                            GestureDetector(
                              onTap: () =>
                                  _showLotteryDetail(_selectedLottery!),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1A1050),
                                      Color(0xFF0D0B2B)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: LuxoraColors.primary
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(_selectedLottery!.emoji,
                                        style: const TextStyle(fontSize: 28)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedLottery!.name,
                                            style: const TextStyle(
                                              color: LuxoraColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Rango: 1-${_selectedLottery!.numberRange} · ${_selectedLottery!.numbersCount} números · ${_selectedLottery!.drawDaysLabel}',
                                            style: const TextStyle(
                                              color: LuxoraColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded,
                                        color: LuxoraColors.textSecondary,
                                        size: 18),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],

                        // ── Tipo selector ──────────────────────────────
                        Text(
                          'TIPO DE JUGADA',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(letterSpacing: 2, fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: LuxoraColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: LuxoraColors.divider),
                          ),
                          child: Row(
                            children: _tipos.map((t) {
                              final selected = t == _selectedTipo;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedTipo = t),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 11),
                                    decoration: BoxDecoration(
                                      gradient: selected
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFFE07820),
                                                Color(0xFFC8620A)
                                              ],
                                            )
                                          : null,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: selected
                                          ? [
                                              BoxShadow(
                                                color: LuxoraColors.primary
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 8,
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: Text(
                                      t,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : LuxoraColors.textSecondary,
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Daily usage indicator ──────────────────────
                        if (_dailyUsage != null) ...[
                          Builder(builder: (context) {
                            final entry = _dailyUsage!.forTipo(_selectedTipo);
                            final isFull = entry.remaining == 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isFull
                                    ? LuxoraColors.error.withValues(alpha: 0.08)
                                    : LuxoraColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isFull
                                      ? LuxoraColors.error
                                          .withValues(alpha: 0.3)
                                      : LuxoraColors.divider,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isFull
                                        ? Icons.block_rounded
                                        : Icons.today_rounded,
                                    color: isFull
                                        ? LuxoraColors.error
                                        : LuxoraColors.textSecondary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isFull
                                          ? _selectedTipo == 'Loto'
                                              ? 'Límite diario alcanzado — vuelve mañana'
                                              : 'Límite diario alcanzado (${entry.limit}/día)'
                                          : '${entry.used}/${entry.limit} jugadas hoy · ${entry.remaining} restantes',
                                      style: TextStyle(
                                        color: isFull
                                            ? LuxoraColors.error
                                            : LuxoraColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // ── Generate button ────────────────────────────
                        Builder(builder: (context) {
                          final isLimitReached = _dailyUsage != null &&
                              _dailyUsage!.forTipo(_selectedTipo).remaining ==
                                  0;
                          final isDisabled = _loading || isLimitReached;
                          return GestureDetector(
                            onTap: isDisabled ? null : _generate,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              height: 58,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: _loading
                                    ? LinearGradient(colors: [
                                        LuxoraColors.primary
                                            .withValues(alpha: 0.4),
                                        LuxoraColors.primary
                                            .withValues(alpha: 0.4),
                                      ])
                                    : const LinearGradient(
                                        colors: [
                                          Color(0xFFE07820),
                                          Color(0xFFC8620A)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                boxShadow: _loading
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: LuxoraColors.primary
                                              .withValues(alpha: 0.45),
                                          blurRadius: 20,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_loading)
                                    const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  else
                                    const Icon(Icons.casino_rounded,
                                        color: Colors.white, size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    _loading
                                        ? 'Generando...'
                                        : 'GENERAR JUGADA',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        // ── Error ──────────────────────────────────────
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: LuxoraColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: LuxoraColors.error
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: LuxoraColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_error!,
                                      style: const TextStyle(
                                          color: LuxoraColors.error,
                                          fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // ── Result ─────────────────────────────────────
                        if (_result != null) ...[
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: LuxoraColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: LuxoraColors.divider),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.auto_awesome,
                                        color: LuxoraColors.accent, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'TUS NÚMEROS',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(letterSpacing: 2),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                AnimatedBuilder(
                                  animation: _ballsCtrl,
                                  builder: (_, __) {
                                    return Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: _result!.numbers
                                          .asMap()
                                          .entries
                                          .map((e) {
                                        final delay = e.key * 0.12;
                                        final progress = math.max(
                                            0.0,
                                            math.min(
                                                1.0,
                                                (_ballsCtrl.value - delay) /
                                                    (1.0 - delay)));
                                        final scale = Curves.elasticOut
                                            .transform(progress);
                                        return Transform.scale(
                                          scale: scale,
                                          child: _NumberBall(number: e.value),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Navigation ────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              decoration: BoxDecoration(
                color: LuxoraColors.surface,
                border: Border(
                    top: BorderSide(color: LuxoraColors.divider, width: 1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.casino_rounded,
                    label: 'Jugar',
                    active: _activeNav == 0,
                    onTap: () => setState(() => _activeNav = 0),
                  ),
                  _NavItem(
                    icon: Icons.history_rounded,
                    label: 'Historial',
                    active: _activeNav == 1,
                    onTap: () {
                      setState(() => _activeNav = 1);
                      context.go('/history');
                    },
                  ),
                  _NavItem(
                    icon: Icons.nights_stay_rounded,
                    label: 'Sueños',
                    active: _activeNav == 2,
                    onTap: () {
                      setState(() => _activeNav = 2);
                      context.go('/dreams');
                    },
                  ),
                  _NavItem(
                    icon: Icons.favorite_rounded,
                    label: 'Donar',
                    active: _activeNav == 3,
                    onTap: () {
                      setState(() => _activeNav = 3);
                      context.go('/donations');
                    },
                  ),
                  if (_isAdmin)
                    _NavItem(
                      icon: Icons.account_balance_rounded,
                      label: 'Cuentas',
                      active: _activeNav == 4,
                      onTap: () {
                        setState(() => _activeNav = 4);
                        context.go('/bank-accounts');
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Number Ball ────────────────────────────────────────────────────────────

class _NumberBall extends StatelessWidget {
  final int number;
  const _NumberBall({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFE07820), Color(0xFF7A3A00)],
          center: Alignment(-0.3, -0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: LuxoraColors.primary.withValues(alpha: 0.6),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
            color: LuxoraColors.accent.withValues(alpha: 0.5), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
        ),
      ),
    );
  }
}

// ── Nav Item ───────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? LuxoraColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? LuxoraColors.primary : LuxoraColors.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color:
                    active ? LuxoraColors.primary : LuxoraColors.textSecondary,
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: LuxoraColors.textSecondary, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: LuxoraColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
