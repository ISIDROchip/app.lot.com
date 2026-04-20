import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class SystemStatsScreen extends StatefulWidget {
  const SystemStatsScreen({super.key});

  @override
  State<SystemStatsScreen> createState() => _SystemStatsScreenState();
}

class _SystemStatsScreenState extends State<SystemStatsScreen> {
  Map<String, dynamic>? _overview;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final response = await dioInstance.get('/admin/stats/overview');
      setState(() {
        _overview = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(title: const Text('ESTADÍSTICAS DEL SISTEMA')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchStats,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('RESUMEN GENERAL'),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        _buildStatCard('Usuarios', _overview?['total_users'].toString() ?? '0', Icons.people_rounded, Colors.blue),
                        _buildStatCard('Contratos', _overview?['total_contracts'].toString() ?? '0', Icons.description_rounded, Colors.orange),
                        _buildStatCard('Jugadas', _overview?['total_plays'].toString() ?? '0', Icons.casino_rounded, Colors.green),
                        _buildStatCard('Aciertos', _overview?['total_hits'].toString() ?? '0', Icons.stars_rounded, Colors.yellow),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle('ACCIÓN RECIENTE (30 días)'),
                    const SizedBox(height: 16),
                    _buildRecentActionRow('Contratos nuevos', _overview?['recent_contracts'].toString() ?? '0', Icons.add_task_rounded),
                    _buildRecentActionRow('Jugadas generadas', _overview?['recent_plays'].toString() ?? '0', Icons.bolt_rounded),
                    _buildRecentActionRow('Usuarios activos', _overview?['active_users'].toString() ?? '0', Icons.person_search_rounded),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: LuxoraColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2));
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuxoraColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LuxoraColors.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: LuxoraColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: LuxoraColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRecentActionRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuxoraColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LuxoraColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: LuxoraColors.primary, size: 20),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(color: LuxoraColors.textPrimary, fontWeight: FontWeight.w600))),
          Text(value, style: const TextStyle(color: LuxoraColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
