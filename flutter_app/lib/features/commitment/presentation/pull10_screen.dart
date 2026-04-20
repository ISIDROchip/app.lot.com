import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../features/lottery/data/lottery_dto.dart';
import '../../../features/lottery/domain/lottery_service.dart';
import '../data/commitment_dto.dart';
import '../domain/commitment_service.dart';

class Pull10Screen extends StatefulWidget {
  const Pull10Screen({super.key});

  @override
  State<Pull10Screen> createState() => _Pull10ScreenState();
}

class _Pull10ScreenState extends State<Pull10Screen> {
  final _service = CommitmentService();
  final _lotteryService = LotteryService();

  Pull10Response? _result;
  bool _loading = false;
  bool _loadingLotteries = true;
  String? _error;

  List<LotteryInfo> _lotteries = [];
  LotteryInfo? _selectedLottery;

  @override
  void initState() {
    super.initState();
    _loadLotteries();
  }

  Future<void> _loadLotteries() async {
    setState(() => _loadingLotteries = true);
    try {
      final list = await _lotteryService.getLotteries();
      if (mounted) {
        setState(() {
          _lotteries = list;
          if (list.isNotEmpty) _selectedLottery = list.first;
          _loadingLotteries = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLotteries = false);
    }
  }

  Future<void> _generate() async {
    if (_selectedLottery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una lotería primero')),
      );
      return;
    }

    // Check if Stripe is properly configured
    // flutter_stripe does NOT support web, so always skip native Stripe on web
    final stripeKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
    final stripeConfigured = !kIsWeb && stripeKey.isNotEmpty && !stripeKey.contains('your_stripe');

    if (!stripeConfigured) {
      // Development / web mode: show info message but continue
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kIsWeb
            ? 'Modo web: generando Pull-10 sin pago nativo'
            : 'Modo desarrollo: generando Pull-10 sin pago')),
      );
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      // Step 1: Create payment intent
      final paymentResponse = await _service.createPaymentIntent();
      final clientSecret = paymentResponse['clientSecret'] as String;
      final paymentIntentId = paymentResponse['paymentIntentId'] as String;

      if (stripeConfigured) {
        // Step 2: Initialize Payment Sheet
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'Luxora Smart Lottery',
            style: ThemeMode.dark,
          ),
        );

        // Step 3: Present Payment Sheet
        await Stripe.instance.presentPaymentSheet();
      } else {
        // Development mode: simulate successful payment
        print('Development mode: simulating successful payment');
        await Future.delayed(const Duration(seconds: 1)); // Simulate payment processing
      }

      // Step 4: If payment successful, generate Pull10
      final result = await _service.requestPull10(
        lotteryId: _selectedLottery!.id,
        paymentIntentId: paymentIntentId,
      );

      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } on StripeException catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Pago cancelado o fallido: ${e.error.localizedMessage}';
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      debugPrint('Pull10 DioException: status=${e.response?.statusCode} data=${e.response?.data} type=${e.type}');
      if (e.response?.statusCode == 400) {
        final serverMsg = e.response?.data is Map ? (e.response?.data['error'] ?? '') : '';
        if (serverMsg.contains('15')) {
          setState(() {
            _error = 'Has alcanzado el límite total de 15 Pulls de 10 autorizados.';
            _loading = false;
          });
          return;
        }
      }
      
      // Show detailed error for debugging
      final statusCode = e.response?.statusCode;
      final serverMsg = e.response?.data is Map
          ? (e.response?.data['error'] ?? e.response?.data['message'] ?? '')
          : e.message;
      setState(() {
        _error = statusCode != null
            ? 'Error del servidor ($statusCode): $serverMsg'
            : 'Error de red: ${e.message}';
        _loading = false;
      });
    } catch (e) {
      debugPrint('Pull10 error: $e');
      if (mounted) {
        setState(() {
          _error = 'Error al procesar pago: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(title: const Text('PULL DE 10')),
      body: _loadingLotteries
          ? const Center(child: CircularProgressIndicator())
          : _result != null
              ? _buildResult()
              : _buildSelector(),
    );
  }

  // ── Lottery selector + generate ────────────────────────────────────────

  Widget _buildSelector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2A1A00), Color(0xFF1A1640)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: LuxoraColors.primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: LuxoraColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: LuxoraColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pull de 10',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                      SizedBox(height: 3),
                      Text('10 combinaciones optimizadas para tu lotería',
                          style: TextStyle(
                              color: LuxoraColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Lottery selector
          const Text('SELECCIONA LA LOTERÍA',
              style: TextStyle(
                  color: LuxoraColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          const SizedBox(height: 12),

          if (_lotteries.isEmpty)
            const Center(
              child: Text('No hay loterías disponibles',
                  style: TextStyle(color: LuxoraColors.textSecondary)),
            )
          else
            ...(_lotteries.map((lot) {
              final selected = _selectedLottery?.id == lot.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedLottery = lot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected
                        ? LuxoraColors.primary.withValues(alpha: 0.1)
                        : LuxoraColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? LuxoraColors.primary
                          : LuxoraColors.divider,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(lot.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lot.name,
                                style: TextStyle(
                                  color: selected
                                      ? LuxoraColors.primary
                                      : LuxoraColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                )),
                            const SizedBox(height: 3),
                            Text(
                              'Rango 1-${lot.numberRange} · ${lot.numbersCount} números · ${lot.drawDaysLabel}',
                              style: const TextStyle(
                                  color: LuxoraColors.textSecondary,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle_rounded,
                            color: LuxoraColors.primary, size: 22)
                      else
                        const Icon(Icons.radio_button_unchecked_rounded,
                            color: LuxoraColors.textSecondary, size: 22),
                    ],
                  ),
                ),
              );
            })),

          const SizedBox(height: 24),

          // Error
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LuxoraColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: LuxoraColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: LuxoraColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: LuxoraColors.error, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Generate button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: (_loading || _selectedLottery == null) ? null : _generate,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: (_loading || _selectedLottery == null)
                      ? LinearGradient(colors: [
                          LuxoraColors.primary.withValues(alpha: 0.4),
                          LuxoraColors.primary.withValues(alpha: 0.4),
                        ])
                      : const LinearGradient(
                          colors: [Color(0xFFE07820), Color(0xFFC8620A)],
                        ),
                  boxShadow: (_loading || _selectedLottery == null)
                      ? []
                      : [
                          BoxShadow(
                            color: LuxoraColors.primary.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                alignment: Alignment.center,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _selectedLottery != null
                            ? 'GENERAR PULL — ${_selectedLottery!.name}'
                            : 'SELECCIONA UNA LOTERÍA',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Results ────────────────────────────────────────────────────────────

  Widget _buildResult() {
    final r = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LuxoraColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: LuxoraColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedLottery != null)
                  Row(
                    children: [
                      Text(_selectedLottery!.emoji,
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(_selectedLottery!.name,
                          style: const TextStyle(
                              color: LuxoraColors.primary,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                const SizedBox(height: 6),
                if (r.contractId != null)
                  Text('Contrato: ${r.contractId}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('TUS 10 COMBINACIONES',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(letterSpacing: 2),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),

          ...r.combinations.asMap().entries.map((entry) {
            final idx = entry.key;
            final combo = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: LuxoraColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LuxoraColors.divider),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('${idx + 1}',
                        style: const TextStyle(
                            color: LuxoraColors.textSecondary, fontSize: 12)),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children:
                          combo.map((n) => _NumberBall(number: n)).toList(),
                    ),
                  ),
                ],
              ),
            );
          }),
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
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFE07820), Color(0xFF7A3A00)],
          center: Alignment(-0.3, -0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: LuxoraColors.primary.withValues(alpha: 0.6),
            blurRadius: 12,
          ),
        ],
        border: Border.all(
            color: LuxoraColors.accent.withValues(alpha: 0.4), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text('$number',
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}
