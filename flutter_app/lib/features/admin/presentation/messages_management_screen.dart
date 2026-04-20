import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class MessagesManagementScreen extends StatefulWidget {
  const MessagesManagementScreen({super.key});

  @override
  State<MessagesManagementScreen> createState() => _MessagesManagementScreenState();
}

class _MessagesManagementScreenState extends State<MessagesManagementScreen> {
  List<dynamic> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    try {
      final response = await dioInstance.get('/admin/messages');
      setState(() {
        _messages = response.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar mensajes: $e')),
        );
      }
    }
  }

  Future<void> _toggleStatus(String id, bool currentStatus) async {
    try {
      await dioInstance.patch('/admin/messages/$id/status', data: {'is_active': !currentStatus});
      _fetchMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar estado: $e')),
        );
      }
    }
  }

  void _showEditDialog([Map<String, dynamic>? message]) {
    final isEditing = message != null;
    final titleCtrl = TextEditingController(text: message?['title'] ?? '');
    final bodyCtrl = TextEditingController(text: message?['body'] ?? '');
    final typeCtrl = TextEditingController(text: message?['message_type'] ?? 'info');
    final roleCtrl = TextEditingController(text: message?['role'] ?? 'general');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LuxoraColors.surface,
        title: Text(isEditing ? 'EDITAR MENSAJE' : 'NUEVO MENSAJE'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bodyCtrl,
                decoration: const InputDecoration(labelText: 'Cuerpo'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: typeCtrl.text,
                items: ['info', 'warning', 'success', 'error']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                    .toList(),
                onChanged: (v) => typeCtrl.text = v!,
                decoration: const InputDecoration(labelText: 'Tipo'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: roleCtrl.text,
                items: ['sender', 'receiver', 'general']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
                    .toList(),
                onChanged: (v) => roleCtrl.text = v!,
                decoration: const InputDecoration(labelText: 'Rol'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              try {
                final data = {
                  'title': titleCtrl.text,
                  'body': bodyCtrl.text,
                  'message_type': typeCtrl.text,
                  'role': roleCtrl.text,
                };
                if (isEditing) {
                  await dioInstance.put('/admin/messages/${message['id']}', data: data);
                } else {
                  await dioInstance.post('/admin/messages', data: data);
                }
                if (mounted) Navigator.pop(context);
                _fetchMessages();
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
        title: const Text('MENSAJES PREDEFINIDOS'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchMessages),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? const Center(child: Text('No hay mensajes predefinidos', style: TextStyle(color: LuxoraColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final bool isActive = msg['is_active'] ?? true;
                    return Card(
                      color: LuxoraColors.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isActive ? LuxoraColors.primary.withValues(alpha: 0.3) : LuxoraColors.divider),
                      ),
                      child: ListTile(
                        title: Text(msg['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(msg['body'], maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isActive,
                              onChanged: (v) => _toggleStatus(msg['id'], isActive),
                              activeColor: LuxoraColors.primary,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 20),
                              onPressed: () => _showEditDialog(msg),
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
