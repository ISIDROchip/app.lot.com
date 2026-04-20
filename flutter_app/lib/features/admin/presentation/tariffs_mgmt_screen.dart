import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class TariffsMgmtScreen extends StatefulWidget {
  const TariffsMgmtScreen({super.key});

  @override
  State<TariffsMgmtScreen> createState() => _TariffsMgmtScreenState();
}

class _TariffsMgmtScreenState extends State<TariffsMgmtScreen> {
  final _baseCostCtrl = TextEditingController();
  final _subscriptionCostCtrl = TextEditingController();
  final _discountPercentCtrl = TextEditingController();
  final _minPlaysCtrl = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTariffs();
  }

  Future<void> _fetchTariffs() async {
    setState(() => _isLoading = true);
    try {
      final response = await dioInstance.get('/admin/tariffs');
      final data = response.data;
      setState(() {
        _baseCostCtrl.text = data['base_cost_per_play'].toString();
        _subscriptionCostCtrl.text = data['subscription_cost'].toString();
        _discountPercentCtrl.text = data['discount_percentage'].toString();
        _minPlaysCtrl.text = data['min_plays_for_discount'].toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar tarifas: $e')),
        );
      }
    }
  }

  Future<void> _saveTariffs() async {
    try {
      final data = {
        'base_cost_per_play': double.parse(_baseCostCtrl.text),
        'subscription_cost': double.parse(_subscriptionCostCtrl.text),
        'discount_percentage': double.parse(_discountPercentCtrl.text),
        'min_plays_for_discount': int.parse(_minPlaysCtrl.text),
      };
      await dioInstance.put('/admin/tariffs', data: data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarifas actualizadas correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(title: const Text('CONFIGURAR TARIFAS')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCard(
                    title: 'PRECIOS BASE',
                    icon: Icons.attach_money_rounded,
                    children: [
                      _buildTextField(_baseCostCtrl, 'Costo base por jugada (RD\$)', 'Ej: 50.00'),
                      const SizedBox(height: 16),
                      _buildTextField(_subscriptionCostCtrl, 'Costo de suscripción (RD\$)', 'Ej: 500.00'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildCard(
                    title: 'DESCUENTOS',
                    icon: Icons.percent_rounded,
                    children: [
                      _buildTextField(_discountPercentCtrl, 'Porcentaje de descuento (%)', 'Ej: 10.00'),
                      const SizedBox(height: 16),
                      _buildTextField(_minPlaysCtrl, 'Mínimo de jugadas para descuento', 'Ej: 5', isInteger: true),
                    ],
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: _saveTariffs,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('GUARDAR CAMBIOS'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LuxoraColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LuxoraColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: LuxoraColors.primary, size: 20),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: LuxoraColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, String hint, {bool isInteger = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: isInteger ? null : 'RD\$ ',
      ),
    );
  }
}
