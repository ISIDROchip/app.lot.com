import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class OAuthMgmtScreen extends StatefulWidget {
  const OAuthMgmtScreen({super.key});

  @override
  State<OAuthMgmtScreen> createState() => _OAuthMgmtScreenState();
}

class _OAuthMgmtScreenState extends State<OAuthMgmtScreen> {
  List<dynamic> _providers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProviders();
  }

  Future<void> _fetchProviders() async {
    setState(() => _isLoading = true);
    try {
      final response = await dioInstance.get('/admin/oauth');
      setState(() {
        _providers = response.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus(String provider, bool currentStatus) async {
    try {
      await dioInstance.patch('/admin/oauth/$provider/status', data: {'is_active': !currentStatus});
      _fetchProviders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar estado: $e')),
        );
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> provider) {
    final name = provider['provider_name'];
    final clientIdCtrl = TextEditingController(text: provider['client_id'] ?? '');
    final clientSecretCtrl = TextEditingController(text: provider['client_secret'] ?? '');
    final redirectUriCtrl = TextEditingController(text: provider['redirect_uri'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LuxoraColors.surface,
        title: Text('CONFIGURAR ${name.toString().toUpperCase()}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: clientIdCtrl, decoration: const InputDecoration(labelText: 'Client ID')),
              const SizedBox(height: 12),
              TextField(controller: clientSecretCtrl, decoration: const InputDecoration(labelText: 'Client Secret'), obscureText: true),
              const SizedBox(height: 12),
              TextField(controller: redirectUriCtrl, decoration: const InputDecoration(labelText: 'Redirect URI')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              try {
                final data = {
                  'client_id': clientIdCtrl.text,
                  'client_secret': clientSecretCtrl.text,
                  'redirect_uri': redirectUriCtrl.text,
                };
                await dioInstance.put('/admin/oauth/$name', data: data);
                if (mounted) Navigator.pop(context);
                _fetchProviders();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al guardar: $e')),
                );
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(title: const Text('OAUTH PROVIDERS')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _providers.length,
              itemBuilder: (context, index) {
                final p = _providers[index];
                final bool isActive = p['is_active'] ?? false;
                final isGoogle = p['provider_name'] == 'google';
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: LuxoraColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isActive ? LuxoraColors.primary : LuxoraColors.divider),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(isGoogle ? Icons.g_mobiledata_rounded : Icons.facebook_rounded, 
                               color: isGoogle ? Colors.red : Colors.blue, size: 40),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['provider_name'].toString().toUpperCase(), 
                                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(isActive ? 'Activo' : 'Inactivo', 
                                     style: TextStyle(color: isActive ? LuxoraColors.accent : LuxoraColors.textSecondary)),
                              ],
                            ),
                          ),
                          Switch(
                            value: isActive,
                            onChanged: (v) => _toggleStatus(p['provider_name'], isActive),
                            activeColor: LuxoraColors.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showEditDialog(p),
                              icon: const Icon(Icons.settings_rounded, size: 18),
                              label: const Text('CONFIGURAR'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
