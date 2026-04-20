import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class EnginePoolScreen extends StatefulWidget {
  const EnginePoolScreen({super.key});

  @override
  State<EnginePoolScreen> createState() => _EnginePoolScreenState();
}

class _EnginePoolScreenState extends State<EnginePoolScreen> {
  int _availableCount = 0;
  bool _isLoading = true;
  bool _isGenerating = false;
  final TextEditingController _amountController = TextEditingController(text: '1000');

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() => _isLoading = true);
    try {
      final response = await dioInstance.get('/admin/engine/pool-status');
      setState(() {
        _availableCount = response.data['available'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener estado: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePool() async {
    final amount = int.tryParse(_amountController.text) ?? 1000;
    if (amount < 1) return;

    setState(() => _isGenerating = true);
    try {
      final response = await dioInstance.post(
        '/admin/engine/generate-pool',
        data: {'amount': amount},
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Éxito: Se generaron ${response.data['total']} combinaciones')),
        );
        _fetchStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar pool: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(
        title: const Text('MOTOR DE COMBINACIONES'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Stats Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A1640), Color(0xFF0A0A0A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: LuxoraColors.primary.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: LuxoraColors.primary.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: LuxoraColors.primary, size: 40),
                      const SizedBox(height: 16),
                      const Text(
                        'COMBINACIONES DISPONIBLES',
                        style: TextStyle(
                          color: LuxoraColors.textSecondary,
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_availableCount',
                        style: const TextStyle(
                          color: LuxoraColors.textPrimary,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  'GENERACIÓN MASIVA (MODO LTFREE)',
                  style: TextStyle(
                    color: LuxoraColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Este proceso utiliza el motor de Python para generar miles de combinaciones que cumplen con todas las reglas de LTFree y el scoring de Luxora. Las mejores se guardan en el pool para ser entregadas a los usuarios.',
                  style: TextStyle(color: LuxoraColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: LuxoraColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Cantidad a generar',
                    labelStyle: const TextStyle(color: LuxoraColors.textSecondary),
                    filled: true,
                    fillColor: LuxoraColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.numbers, color: LuxoraColors.primary),
                  ),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isGenerating ? null : _generatePool,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LuxoraColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isGenerating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'GENERAR LOTE Y GUARDAR EN BASE DE DATOS',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
                
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _isLoading ? null : _fetchStatus,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('ACTUALIZAR ESTADO'),
                  style: TextButton.styleFrom(foregroundColor: LuxoraColors.textSecondary),
                ),
              ],
            ),
          ),
    );
  }
}
