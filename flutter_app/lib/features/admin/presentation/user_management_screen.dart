import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<dynamic> _users = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalUsers = 0;
  final int _limit = 20;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _users = [];
      });
    }

    setState(() => _isLoading = true);
    try {
      final response = await dioInstance.get(
        '/admin/users',
        queryParameters: {
          'page': _currentPage,
          'limit': _limit,
          'search': _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        },
      );
      
      final data = response.data;
      setState(() {
        _users = data['data'];
        _totalUsers = data['total'];
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error al cargar usuarios: $e';
      });
    }
  }

  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    try {
      await dioInstance.patch(
        '/admin/users/$userId/status',
        data: {'is_active': !currentStatus},
      );
      _fetchUsers(); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar estado: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(
        title: const Text('GESTIÓN DE USUARIOS'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: LuxoraColors.textPrimary),
              onSubmitted: (_) => _fetchUsers(refresh: true),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o email...',
                hintStyle: const TextStyle(color: LuxoraColors.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, color: LuxoraColors.primary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded, color: LuxoraColors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    _fetchUsers(refresh: true);
                  },
                ),
                filled: true,
                fillColor: LuxoraColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: LuxoraColors.error)),
            ),

          Expanded(
            child: _isLoading && _users.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _fetchUsers(refresh: true),
                    child: _users.isEmpty
                        ? const Center(
                            child: Text(
                              'No se encontraron usuarios',
                              style: TextStyle(color: LuxoraColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              final bool isActive = user['is_active'] ?? false;
                              final bool isAdmin = user['is_admin'] ?? false;
                              final bool isSuperAdmin = user['is_super_admin'] ?? false;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: LuxoraColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: LuxoraColors.divider),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: CircleAvatar(
                                    backgroundColor: (isSuperAdmin || isAdmin) 
                                        ? LuxoraColors.primary.withValues(alpha: 0.2)
                                        : LuxoraColors.divider,
                                    child: Icon(
                                      isSuperAdmin 
                                          ? Icons.workspace_premium_rounded 
                                          : (isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded),
                                      color: (isSuperAdmin || isAdmin) ? LuxoraColors.primary : LuxoraColors.textSecondary,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          user['full_name'] ?? 'N/A',
                                          style: const TextStyle(
                                            color: LuxoraColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (!isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: LuxoraColors.error.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'INACTIVO',
                                            style: TextStyle(color: LuxoraColors.error, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(user['email'] ?? 'N/A', style: const TextStyle(color: LuxoraColors.textSecondary, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text('ID: ${user['id']}', style: const TextStyle(color: LuxoraColors.textSecondary, fontSize: 10, fontFamily: 'monospace')),
                                    ],
                                  ),
                                  trailing: Switch(
                                    value: isActive,
                                    activeColor: LuxoraColors.primary,
                                    onChanged: (isSuperAdmin) ? null : (val) => _toggleUserStatus(user['id'], isActive),
                                  ),
                                  onTap: () {
                                    // Navigate to user reports or details
                                    context.go('/admin/reports', extra: user['id']);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
          ),
          
          // Pagination Info
          if (_totalUsers > 0)
            Container(
              padding: const EdgeInsets.all(16),
              color: LuxoraColors.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: $_totalUsers usuarios',
                    style: const TextStyle(color: LuxoraColors.textSecondary, fontSize: 12),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: _currentPage > 1 ? () {
                          setState(() => _currentPage--);
                          _fetchUsers();
                        } : null,
                      ),
                      Text('Pág. $_currentPage', style: const TextStyle(color: LuxoraColors.textPrimary)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: (_currentPage * _limit) < _totalUsers ? () {
                          setState(() => _currentPage++);
                          _fetchUsers();
                        } : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
