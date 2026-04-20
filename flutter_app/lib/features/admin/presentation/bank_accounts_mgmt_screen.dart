import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class BankAccountsMgmtScreen extends StatefulWidget {
  const BankAccountsMgmtScreen({super.key});

  @override
  State<BankAccountsMgmtScreen> createState() => _BankAccountsMgmtScreenState();
}

class _BankAccountsMgmtScreenState extends State<BankAccountsMgmtScreen> {
  List<dynamic> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    setState(() => _isLoading = true);
    try {
      final response = await dioInstance.get('/admin/bank-accounts');
      setState(() {
        _accounts = response.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar cuentas: $e')),
        );
      }
    }
  }

  Future<void> _toggleStatus(String id, bool currentStatus) async {
    try {
      await dioInstance.patch('/admin/bank-accounts/$id/status', data: {'is_active': !currentStatus});
      _fetchAccounts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar estado: $e')),
        );
      }
    }
  }

  Future<void> _deleteAccount(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ELIMINAR CUENTA'),
        content: const Text('¿Estás seguro de que deseas eliminar esta cuenta bancaria?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ELIMINAR', style: TextStyle(color: LuxoraColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await dioInstance.delete('/admin/bank-accounts/$id');
        _fetchAccounts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  void _showEditDialog([Map<String, dynamic>? account]) {
    final isEditing = account != null;
    final bankCtrl = TextEditingController(text: account?['bank_name'] ?? '');
    final numberCtrl = TextEditingController(text: account?['account_number'] ?? '');
    final typeCtrl = TextEditingController(text: account?['account_type'] ?? '');
    final holderCtrl = TextEditingController(text: account?['account_holder'] ?? '');
    final descCtrl = TextEditingController(text: account?['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LuxoraColors.surface,
        title: Text(isEditing ? 'EDITAR CUENTA' : 'NUEVA CUENTA'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: bankCtrl, decoration: const InputDecoration(labelText: 'Nombre del Banco')),
              const SizedBox(height: 12),
              TextField(controller: numberCtrl, decoration: const InputDecoration(labelText: 'Número de Cuenta')),
              const SizedBox(height: 12),
              TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Tipo (Ahorro/Corriente)')),
              const SizedBox(height: 12),
              TextField(controller: holderCtrl, decoration: const InputDecoration(labelText: 'Titular')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción (Opcional)'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              try {
                final data = {
                  'bank_name': bankCtrl.text,
                  'account_number': numberCtrl.text,
                  'account_type': typeCtrl.text,
                  'account_holder': holderCtrl.text,
                  'description': descCtrl.text,
                };
                if (isEditing) {
                  await dioInstance.put('/admin/bank-accounts/${account['id']}', data: data);
                } else {
                  await dioInstance.post('/admin/bank-accounts', data: data);
                }
                if (mounted) Navigator.pop(context);
                _fetchAccounts();
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
      appBar: AppBar(
        title: const Text('CUENTAS BANCARIAS'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchAccounts),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? const Center(child: Text('No hay cuentas registradas', style: TextStyle(color: LuxoraColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _accounts.length,
                  itemBuilder: (context, index) {
                    final acc = _accounts[index];
                    final bool isActive = acc['is_active'] ?? true;
                    return Card(
                      color: LuxoraColors.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: LuxoraColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.account_balance_rounded, color: LuxoraColors.primary, size: 20),
                        ),
                        title: Text(acc['bank_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${acc['account_number']} - ${acc['account_holder']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isActive,
                              onChanged: (v) => _toggleStatus(acc['id'], isActive),
                              activeColor: LuxoraColors.primary,
                            ),
                            IconButton(icon: const Icon(Icons.edit_rounded, size: 20), onPressed: () => _showEditDialog(acc)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: LuxoraColors.error),
                              onPressed: () => _deleteAccount(acc['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        backgroundColor: LuxoraColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}
