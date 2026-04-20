import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class LogsMgmtScreen extends StatefulWidget {
  const LogsMgmtScreen({super.key});

  @override
  State<LogsMgmtScreen> createState() => _LogsMgmtScreenState();
}

class _LogsMgmtScreenState extends State<LogsMgmtScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _errorLogs = [];
  List<dynamic> _auditLogs = [];
  bool _isLoadingErrors = true;
  bool _isLoadingAudit = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchErrors();
    _fetchAudit();
  }

  Future<void> _fetchErrors() async {
    setState(() => _isLoadingErrors = true);
    try {
      final response = await dioInstance.get('/admin/logs/errors');
      setState(() {
        _errorLogs = response.data['data'];
        _isLoadingErrors = false;
      });
    } catch (e) {
      setState(() => _isLoadingErrors = false);
    }
  }

  Future<void> _fetchAudit() async {
    setState(() => _isLoadingAudit = true);
    try {
      final response = await dioInstance.get('/admin/logs/audit');
      setState(() {
        _auditLogs = response.data['data'];
        _isLoadingAudit = false;
      });
    } catch (e) {
      setState(() => _isLoadingAudit = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(
        title: const Text('LOGS Y AUDITORÍA'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'ERRORES'),
            Tab(text: 'AUDITORÍA'),
          ],
          indicatorColor: LuxoraColors.primary,
          labelColor: LuxoraColors.primary,
          unselectedLabelColor: LuxoraColors.textSecondary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildErrorList(),
          _buildAuditList(),
        ],
      ),
    );
  }

  Widget _buildErrorList() {
    if (_isLoadingErrors) return const Center(child: CircularProgressIndicator());
    if (_errorLogs.isEmpty) return const Center(child: Text('No hay logs de errores'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _errorLogs.length,
      itemBuilder: (context, index) {
        final log = _errorLogs[index];
        final date = DateTime.parse(log['created_at']);
        return Card(
          color: LuxoraColors.surface,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(log['error_code'] ?? 'ERROR DESCONOCIDO', style: const TextStyle(color: LuxoraColors.error, fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(date)),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mensaje: ${log['message']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Reference ID: ${log['reference_id']}', style: const TextStyle(fontSize: 12, color: LuxoraColors.textSecondary)),
                    if (log['stack_trace'] != null) ...[
                      const SizedBox(height: 12),
                      const Text('Stack Trace:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                        child: Text(log['stack_trace'], style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.greenAccent)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuditList() {
    if (_isLoadingAudit) return const Center(child: CircularProgressIndicator());
    if (_auditLogs.isEmpty) return const Center(child: Text('No hay logs de auditoría'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _auditLogs.length,
      itemBuilder: (context, index) {
        final log = _auditLogs[index];
        final date = DateTime.parse(log['created_at']);
        return Card(
          color: LuxoraColors.surface,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.history_rounded, color: LuxoraColors.primary),
            title: Text(log['action'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('IP: ${log['ip_address'] ?? 'N/A'} • ${DateFormat('dd/MM/yyyy HH:mm:ss').format(date)}'),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('METADATA DE AUDITORÍA'),
                    content: SingleChildScrollView(child: Text(log['metadata'].toString())),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CERRAR'))],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
