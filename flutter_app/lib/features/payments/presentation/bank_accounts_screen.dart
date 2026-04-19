import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';
import '../data/bank_account_dto.dart';
import '../data/bank_account_repository.dart';

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  final _repo = BankAccountRepository();
  List<BankAccount> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Como es la vista de admin, cargamos todas las cuentas
      final accounts = await _repo.getAllBankAccounts();
      setState(() => _accounts = accounts);
    } catch (_) {
      setState(() => _error = 'Acceso denegado o error de conexión.\nSolo Super Admins pueden gestionar cuentas.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editAccount([BankAccount? account]) async {
    final isEdit = account != null;
    final bankCtrl = TextEditingController(text: account?.bankName);
    final numberCtrl = TextEditingController(text: account?.accountNumber);
    final holderCtrl = TextEditingController(text: account?.accountHolder);
    final descCtrl = TextEditingController(text: account?.description);
    String type = account?.accountType ?? 'savings';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Editar Cuenta' : 'Nueva Cuenta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: bankCtrl, decoration: const InputDecoration(labelText: 'Banco')),
                TextField(controller: numberCtrl, decoration: const InputDecoration(labelText: 'Número de Cuenta')),
                TextField(controller: holderCtrl, decoration: const InputDecoration(labelText: 'Titular')),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'savings', child: Text('Ahorros')),
                    DropdownMenuItem(value: 'checking', child: Text('Corriente')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción (Opcional)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true), 
              child: Text(isEdit ? 'GUARDAR' : 'CREAR')
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final data = {
          'bank_name': bankCtrl.text,
          'account_number': numberCtrl.text,
          'account_holder': holderCtrl.text,
          'account_type': type,
          'description': descCtrl.text,
        };
        if (isEdit) {
          await _repo.update(account.id, data);
        } else {
          await _repo.create(data);
        }
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _toggleStatus(BankAccount a) async {
    try {
      await _repo.setStatus(a.id, !a.isActive);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _delete(BankAccount a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text('¿Estás seguro de eliminar esta cuenta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('NO')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('SÍ, ELIMINAR')),
        ],
      )
    );

    if (confirm == true) {
      try {
        await _repo.delete(a.id);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GESTIÓN DE CUENTAS'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_person_rounded, size: 64, color: LuxoraColors.error),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _accounts.length,
                  itemBuilder: (context, index) {
                    final a = _accounts[index];
                    return Card(
                      color: LuxoraColors.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: a.isActive ? LuxoraColors.primary : Colors.grey,
                          child: const Icon(Icons.account_balance, color: Colors.white, size: 20),
                        ),
                        title: Text(a.bankName),
                        subtitle: Text('${a.accountNumber}\n${a.accountHolder}'),
                        isThreeLine: true,
                        trailing: PopupMenuButton(
                          onSelected: (val) {
                            if (val == 'edit') _editAccount(a);
                            if (val == 'status') _toggleStatus(a);
                            if (val == 'delete') _delete(a);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(value: 'status', child: Text(a.isActive ? 'Desactivar' : 'Activar')),
                            const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editAccount(),
        backgroundColor: LuxoraColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}
