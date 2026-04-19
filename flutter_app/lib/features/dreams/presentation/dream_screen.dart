import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';
import '../data/dream_dto.dart';
import '../domain/dream_service.dart';

class DreamScreen extends StatefulWidget {
  const DreamScreen({super.key});

  @override
  State<DreamScreen> createState() => _DreamScreenState();
}

class _DreamScreenState extends State<DreamScreen>
    with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _service = DreamService();
  bool _loading = false;
  String? _error;
  DreamResponse? _result;

  late AnimationController _circuitCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _scanCtrl;

  @override
  void initState() {
    super.initState();
    _circuitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _circuitCtrl.dispose();
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  Future<void> _interpret() async {
    final text = _ctrl.text.trim();
    if (text.length < 10) {
      setState(() => _error = 'Describe tu sueño con al menos 10 caracteres');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    _scanCtrl.repeat();
    try {
      final res = await _service.interpret(text);
      setState(() => _result = res);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        setState(() => _error = e.response?.data['error'] ?? 'Solo puedes realizar una interpretación por día.');
      } else {
        _error = e.response?.statusCode == 503
            ? 'Servicio IA no disponible, intenta más tarde'
            : 'Error al interpretar el sueño';
      }
    } on ArgumentError catch (e) {
      _error = e.message;
    } finally {
      _scanCtrl.stop();
      _scanCtrl.reset();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      body: Stack(
        children: [
          // Animated circuit background
          AnimatedBuilder(
            animation: _circuitCtrl,
            builder: (_, __) => CustomPaint(
              painter: _CircuitPainter(_circuitCtrl.value),
              child: const SizedBox.expand(),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // AI Header
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // AI Robot avatar
                        _buildAIAvatar(),
                        const SizedBox(height: 20),
                        // Input card
                        _buildInputCard(),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _buildErrorCard(),
                        ],
                        const SizedBox(height: 16),
                        _buildInterpretButton(),
                        if (_result != null) ...[
                          const SizedBox(height: 28),
                          _ResultCard(result: _result!),
                        ],
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) {
              final glow = 0.3 + _pulseCtrl.value * 0.4;
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1050),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: LuxoraColors.accent.withValues(alpha: glow),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: LuxoraColors.accent.withValues(alpha: glow * 0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: LuxoraColors.accent, size: 24),
              );
            },
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEURAL DREAM AI',
                    style: TextStyle(
                        color: LuxoraColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 2)),
                SizedBox(height: 2),
                Text('Motor de interpretación cuántica',
                    style: TextStyle(
                        color: LuxoraColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: LuxoraColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: LuxoraColors.accent.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: LuxoraColors.accent, size: 6),
                SizedBox(width: 5),
                Text('ONLINE',
                    style: TextStyle(
                        color: LuxoraColors.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAvatar() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final scale = 1.0 + _pulseCtrl.value * 0.03;
        final glowAlpha = 0.15 + _pulseCtrl.value * 0.15;
        return Center(
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    LuxoraColors.accent.withValues(alpha: 0.2),
                    LuxoraColors.surfaceAlt,
                    LuxoraColors.surface,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                border: Border.all(
                  color: LuxoraColors.accent.withValues(alpha: glowAlpha + 0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: LuxoraColors.accent.withValues(alpha: glowAlpha),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: LuxoraColors.accent.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                  ),
                  // Robot face
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Eyes
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _RobotEye(animation: _pulseCtrl),
                          const SizedBox(width: 16),
                          _RobotEye(animation: _pulseCtrl),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Mouth - scanning line
                      AnimatedBuilder(
                        animation: _loading ? _scanCtrl : _pulseCtrl,
                        builder: (_, __) {
                          final width = _loading
                              ? 20.0 + _scanCtrl.value * 16.0
                              : 24.0;
                          return Container(
                            width: width,
                            height: 3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: _loading
                                  ? LuxoraColors.primary
                                  : LuxoraColors.accent
                                      .withValues(alpha: 0.6),
                              boxShadow: [
                                BoxShadow(
                                  color: (_loading
                                          ? LuxoraColors.primary
                                          : LuxoraColors.accent)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: LuxoraColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _ctrl.text.isNotEmpty
              ? LuxoraColors.accent.withValues(alpha: 0.4)
              : LuxoraColors.divider,
        ),
        boxShadow: [
          BoxShadow(
            color: LuxoraColors.accent.withValues(alpha: 0.05),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terminal-style header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: LuxoraColors.surfaceAlt.withValues(alpha: 0.5),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal_rounded,
                    color: LuxoraColors.accent.withValues(alpha: 0.7),
                    size: 14),
                const SizedBox(width: 8),
                Text('dream_input.neural',
                    style: TextStyle(
                        color: LuxoraColors.accent.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5)),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _ctrl.text.isNotEmpty
                        ? LuxoraColors.accent
                        : LuxoraColors.textSecondary.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          TextFormField(
            controller: _ctrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '> Describe tu sueño aquí...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              hintStyle: TextStyle(
                  color: LuxoraColors.textSecondary.withValues(alpha: 0.5),
                  fontFamily: 'monospace'),
              counterStyle: const TextStyle(
                  color: LuxoraColors.textSecondary, fontSize: 11),
            ),
            maxLines: 6,
            maxLength: 2000,
            style: const TextStyle(
                color: LuxoraColors.textPrimary, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: LuxoraColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LuxoraColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: LuxoraColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(_error!,
                  style: const TextStyle(
                      color: LuxoraColors.error, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildInterpretButton() {
    return GestureDetector(
      onTap: _loading ? null : _interpret,
      child: AnimatedBuilder(
        animation: _loading ? _scanCtrl : _pulseCtrl,
        builder: (_, __) {
          final borderAlpha =
              _loading ? 0.4 + _scanCtrl.value * 0.4 : 0.4;
          return Container(
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: _loading
                  ? LinearGradient(colors: [
                      LuxoraColors.primary.withValues(alpha: 0.3),
                      LuxoraColors.accent.withValues(alpha: 0.2),
                    ])
                  : const LinearGradient(
                      colors: [Color(0xFF1A1050), Color(0xFF231E55)],
                    ),
              border: Border.all(
                color: (_loading ? LuxoraColors.primary : LuxoraColors.accent)
                    .withValues(alpha: borderAlpha),
                width: 1.5,
              ),
              boxShadow: _loading
                  ? [
                      BoxShadow(
                        color:
                            LuxoraColors.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color:
                            LuxoraColors.accent.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_loading) ...[
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: LuxoraColors.primary)),
                  const SizedBox(width: 12),
                  const Text('PROCESANDO SUEÑO...',
                      style: TextStyle(
                          color: LuxoraColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                ] else ...[
                  const Icon(Icons.smart_toy_rounded,
                      color: LuxoraColors.accent, size: 20),
                  const SizedBox(width: 10),
                  const Text('ANALIZAR CON IA',
                      style: TextStyle(
                          color: LuxoraColors.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Robot Eye widget ─────────────────────────────────────────────────────────

class _RobotEye extends StatelessWidget {
  final AnimationController animation;
  const _RobotEye({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final glow = 0.5 + animation.value * 0.5;
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LuxoraColors.accent.withValues(alpha: glow),
            boxShadow: [
              BoxShadow(
                color: LuxoraColors.accent.withValues(alpha: glow * 0.6),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Circuit background painter ───────────────────────────────────────────────

class _CircuitPainter extends CustomPainter {
  final double progress;
  static final _rng = math.Random(99);
  static final _nodes = List.generate(
      20,
      (_) => Offset(
            _rng.nextDouble(),
            _rng.nextDouble(),
          ));

  const _CircuitPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final dotPaint = Paint()..style = PaintingStyle.fill;

    // Draw circuit lines between nearby nodes
    for (int i = 0; i < _nodes.length; i++) {
      final p1 = Offset(_nodes[i].dx * size.width, _nodes[i].dy * size.height);
      for (int j = i + 1; j < _nodes.length; j++) {
        final p2 =
            Offset(_nodes[j].dx * size.width, _nodes[j].dy * size.height);
        final dist = (p1 - p2).distance;
        if (dist < size.width * 0.3) {
          final phase = (progress + i / _nodes.length) % 1.0;
          final alpha = (math.sin(phase * 2 * math.pi) * 0.5 + 0.5) * 0.08;
          linePaint.color =
              const Color(0xFF7ED321).withValues(alpha: alpha);
          canvas.drawLine(p1, p2, linePaint);
        }
      }

      // Draw node dots
      final phase = (progress + i / _nodes.length) % 1.0;
      final dotAlpha = (math.sin(phase * 2 * math.pi) * 0.5 + 0.5) * 0.25;
      dotPaint.color =
          const Color(0xFF7ED321).withValues(alpha: dotAlpha);
      canvas.drawCircle(p1, 2.0, dotPaint);
    }

    // Traveling data particle
    final particleIndex = (progress * _nodes.length).floor() % _nodes.length;
    final nextIndex = (particleIndex + 1) % _nodes.length;
    final t = (progress * _nodes.length) % 1.0;
    final px = _nodes[particleIndex].dx * size.width +
        (_nodes[nextIndex].dx * size.width -
                _nodes[particleIndex].dx * size.width) *
            t;
    final py = _nodes[particleIndex].dy * size.height +
        (_nodes[nextIndex].dy * size.height -
                _nodes[particleIndex].dy * size.height) *
            t;
    dotPaint.color = const Color(0xFFC8620A).withValues(alpha: 0.6);
    canvas.drawCircle(Offset(px, py), 3.0, dotPaint);
    dotPaint.color = const Color(0xFFC8620A).withValues(alpha: 0.2);
    canvas.drawCircle(Offset(px, py), 8.0, dotPaint);
  }

  @override
  bool shouldRepaint(_CircuitPainter old) => old.progress != progress;
}

// ── Result card with AI styling ──────────────────────────────────────────────

class _ResultCard extends StatefulWidget {
  final DreamResponse result;
  const _ResultCard({required this.result});

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _revealCtrl;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _revealCtrl,
      builder: (_, __) {
        return Opacity(
          opacity: _revealCtrl.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _revealCtrl.value)),
            child: _buildContent(),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AI analysis header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: LuxoraColors.accent.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
                color: LuxoraColors.accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.smart_toy_rounded,
                  color: LuxoraColors.accent, size: 14),
              const SizedBox(width: 8),
              Text('ANÁLISIS NEURAL COMPLETO',
                  style: TextStyle(
                      color: LuxoraColors.accent.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
              const Spacer(),
              const Icon(Icons.check_circle_outline_rounded,
                  color: LuxoraColors.accent, size: 14),
            ],
          ),
        ),
        // Numbers section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1050), Color(0xFF0D0B2B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              left: BorderSide(
                  color: LuxoraColors.accent.withValues(alpha: 0.2)),
              right: BorderSide(
                  color: LuxoraColors.accent.withValues(alpha: 0.2)),
            ),
            boxShadow: [
              BoxShadow(
                color: LuxoraColors.accent.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: LuxoraColors.primary, size: 16),
                  const SizedBox(width: 8),
                  const Text('NÚMEROS GENERADOS POR IA',
                      style: TextStyle(
                          color: LuxoraColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: widget.result.numbers.asMap().entries.map((entry) {
                  final delay = entry.key * 0.12;
                  final show =
                      _revealCtrl.value > delay ? 1.0 : 0.0;
                  return Opacity(
                    opacity: show,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFFE07820), Color(0xFF7A3A00)],
                          center: Alignment(-0.3, -0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: LuxoraColors.primary
                                .withValues(alpha: 0.5),
                            blurRadius: 14,
                          ),
                        ],
                        border: Border.all(
                            color: LuxoraColors.accent
                                .withValues(alpha: 0.4),
                            width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text('${entry.value}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        // Keywords section
        if (widget.result.keywords.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LuxoraColors.surface,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border.all(
                  color: LuxoraColors.accent.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.memory_rounded,
                        color: LuxoraColors.textSecondary.withValues(alpha: 0.6),
                        size: 14),
                    const SizedBox(width: 8),
                    const Text('PATRONES DETECTADOS',
                        style: TextStyle(
                            color: LuxoraColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.result.keywords
                      .map((k) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color:
                                  LuxoraColors.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: LuxoraColors.accent
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tag_rounded,
                                    color: LuxoraColors.accent
                                        .withValues(alpha: 0.6),
                                    size: 12),
                                const SizedBox(width: 4),
                                Text(k,
                                    style: const TextStyle(
                                        color: LuxoraColors.accent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
