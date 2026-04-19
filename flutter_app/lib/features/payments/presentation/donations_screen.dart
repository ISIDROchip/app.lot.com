import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card, BankAccount;
import '../../../shared/theme/app_theme.dart';
import '../data/bank_account_dto.dart';
import '../data/bank_account_repository.dart';
import '../../../core/api/api_client.dart';

class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  final _repo = BankAccountRepository();
  List<BankAccount> _accounts = [];
  bool _loading = true;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final accounts = await _repo.getActiveBankAccounts();
      setState(() => _accounts = accounts);
    } catch (_) {
      setState(() => _error = 'Error al cargar cuentas de donación');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _donate() async {
    // Diálogo para monto
    final amountText = await showDialog<String>(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController(text: '10');
        return AlertDialog(
          title: const Text('Donar a la causa'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Monto (USD)', prefixText: '\$ '),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
            ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('DONAR')),
          ],
        );
      }
    );

    if (amountText == null) return;
    final amount = double.tryParse(amountText) ?? 0;
    if (amount <= 0) return;

    setState(() => _processing = true);
    try {
      final res = await dioInstance.post('/donations/intent', data: {'amount': amount});
      final data = res.data;

      if (kIsWeb || (data['isMock'] == true)) {
        // Simular éxito en web o si es mock
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Gracias por tu donación! (Simulado)'), backgroundColor: Colors.green),
          );
        }
      } else {
        // Stripe nativo
        Stripe.publishableKey = data['publishableKey'];
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: data['clientSecret'],
            merchantDisplayName: 'Smart Lottery Donations',
            style: ThemeMode.dark,
          ),
        );
        await Stripe.instance.presentPaymentSheet();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Gracias por tu generosa donación!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar: $e'), backgroundColor: LuxoraColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(
        title: const Text('DONACIONES'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          _buildInfoHero(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _accounts.isEmpty
                    ? _buildEmptyState()
                    : _buildAccountsList(),
          ),
          _buildDonateButton(),
        ],
      ),
    );
  }

  Widget _buildInfoHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [LuxoraColors.primary, LuxoraColors.primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.favorite_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Tu apoyo hace la diferencia',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Ayúdanos a seguir mejorando el motor de inteligencia artificial y a mantener el servicio gratuito para todos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _accounts.length,
      itemBuilder: (context, index) {
        final a = _accounts[index];
        return Card(
          elevation: 0,
          color: LuxoraColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: LuxoraColors.divider),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: LuxoraColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_rounded, color: LuxoraColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.bankName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(a.accountHolder, style: const TextStyle(fontSize: 12, color: LuxoraColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(a.accountNumber, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: LuxoraColors.accent)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    // Copiar al portapapeles
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volunteer_activism_rounded, size: 64, color: LuxoraColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('No hay cuentas de depósito directo registradas', style: TextStyle(color: LuxoraColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDonateButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: LuxoraColors.surface,
        border: Border(top: BorderSide(color: LuxoraColors.divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _processing ? null : _donate,
          style: ElevatedButton.styleFrom(
            backgroundColor: LuxoraColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _processing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.payment_rounded),
          label: Text(_processing ? 'PROCESANDO...' : 'DONAR CON STRIPE'),
        ),
      ),
    );
  }
}
