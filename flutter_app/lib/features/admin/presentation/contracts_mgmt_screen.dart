import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class ContractsMgmtScreen extends StatefulWidget {
  const ContractsMgmtScreen({super.key});

  @override
  State<ContractsMgmtScreen> createState() => _ContractsMgmtScreenState();
}

class _ContractsMgmtScreenState extends State<ContractsMgmtScreen> {
  List<dynamic> _contracts = [];
  bool _isLoading = true;
  String _search = '';
  int _page = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _fetchContracts();
  }

  Future<void> _fetchContracts() async {
    setState(() => _isLoading = true);
    try {
      final response = await dioInstance.get('/admin/commitment/contracts', queryParameters: {
        'page': _page,
        'limit': 20,
        'search': _search,
      });
      setState(() {
        _contracts = response.data['data'];
        _total = response.data['total'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar contratos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(title: const Text('CONTRATOS FIRMADOS')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) {
                _search = v;
                _page = 1;
                _fetchContracts();
              },
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o cédula...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _contracts.isEmpty
                    ? const Center(child: Text('No se encontraron contratos', style: TextStyle(color: LuxoraColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _contracts.length,
                        itemBuilder: (context, index) {
                          final c = _contracts[index];
                          final date = DateTime.parse(c['signed_at']);
                          return Card(
                            color: LuxoraColors.surface,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text('${c['first_name']} ${c['last_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Cédula: ${c['cedula']} • ${DateFormat('dd/MM/yyyy HH:mm').format(date)}'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                // Navegar al reporte detallado pasándole el userId
                                context.go('/admin/reports', extra: c['user_id']);
                              },
                            ),
                          );
                        },
                      ),
          ),
          if (_total > 20)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _page > 1 ? () { setState(() => _page--); _fetchContracts(); } : null,
                  ),
                  Text('Página $_page de ${(_total / 20).ceil()}'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _page < (_total / 20).ceil() ? () { setState(() => _page++); _fetchContracts(); } : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
