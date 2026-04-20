import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../features/auth/domain/auth_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _authService = AuthService();
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final superAdmin = await _authService.isSuperAdmin;
    if (mounted) setState(() => _isSuperAdmin = superAdmin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(
        title: const Text('PANEL ADMIN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await _authService.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Role badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isSuperAdmin
                      ? [const Color(0xFF2A1A00), const Color(0xFF1A1640)]
                      : [LuxoraColors.surface, LuxoraColors.surface],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isSuperAdmin
                      ? LuxoraColors.primary.withValues(alpha: 0.5)
                      : LuxoraColors.divider,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: LuxoraColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isSuperAdmin
                          ? Icons.workspace_premium_rounded
                          : Icons.admin_panel_settings_rounded,
                      color: LuxoraColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isSuperAdmin ? 'Super Administrador' : 'Administrador',
                        style: const TextStyle(
                          color: LuxoraColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _isSuperAdmin
                            ? 'Acceso total al sistema'
                            : 'Acceso a gestión de usuarios',
                        style: const TextStyle(
                          color: LuxoraColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Admin section
            _SectionTitle(title: 'GESTIÓN'),
            const SizedBox(height: 12),
            _AdminCard(
              icon: Icons.people_rounded,
              title: 'Usuarios',
              subtitle: 'Ver, activar y desactivar cuentas',
              onTap: () => context.go('/admin/users'),
            ),
            const SizedBox(height: 10),
            _AdminCard(
              icon: Icons.message_rounded,
              title: 'Mensajes predefinidos',
              subtitle: 'Gestionar mensajes del sistema',
              onTap: () => context.go('/admin/messages'),
            ),
            const SizedBox(height: 10),
            _AdminCard(
              icon: Icons.description_rounded,
              title: 'Contratos',
              subtitle: 'Ver contratos de compromiso firmados',
              onTap: () => context.go('/admin/contracts'),
            ),

            if (_isSuperAdmin) ...[
              const SizedBox(height: 24),
              const _SectionTitle(title: 'SUPER ADMIN'),
              const SizedBox(height: 12),
              _AdminCard(
                icon: Icons.download_rounded,
                title: 'Carga de resultados',
                subtitle: 'Scraper de Loto Más — Leidsa',
                color: LuxoraColors.accent,
                onTap: () => context.go('/admin/scraper'),
              ),
              const SizedBox(height: 10),
              _AdminCard(
                icon: Icons.analytics_rounded,
                title: 'Estadísticas LTFree',
                subtitle: 'Media, z-score, pares, posición, ciclos',
                color: LuxoraColors.accent,
                onTap: () => context.go('/stats'),
              ),
              const SizedBox(height: 10),
              _AdminCard(
                icon: Icons.auto_awesome_rounded,
                title: 'Motor de Combinaciones',
                subtitle: 'Generar lote masivo (Pool) y ver estado',
                color: LuxoraColors.primary,
                onTap: () => context.go('/admin/engine-pool'),
              ),
              const SizedBox(height: 10),
              _AdminCard(
                icon: Icons.workspace_premium_rounded,
                title: 'Top 10 Probables',
                subtitle: 'Las 10 mejores jugadas según el motor',
                color: LuxoraColors.primary,
                onTap: () => context.go('/admin/top-probables'),
              ),
              const SizedBox(height: 10),
              _AdminCard(
                icon: Icons.bar_chart_rounded,
                title: 'Estadísticas del sistema',
                subtitle: 'Overview y actividad',
                onTap: () => context.go('/admin/stats'),
              ),
              const SizedBox(height: 10),
              _AdminCard(
                icon: Icons.error_outline_rounded,
                title: 'Logs de errores',
                subtitle: 'Errores y auditoría',
                onTap: () => context.go('/admin/logs'),
              ),
              const SizedBox(height: 10),
              _AdminCard(
                icon: Icons.price_change_rounded,
                title: 'Tarifas',
                subtitle: 'Configurar precios del sistema',
                onTap: () => context.go('/admin/tariffs'),
              ),
              const SizedBox(height: 10),
              _AdminCard(
                icon: Icons.account_balance_rounded,
                title: 'Cuentas bancarias',
                subtitle: 'CRUD de cuentas de la empresa',
                onTap: () => context.go('/admin/bank-accounts-mgmt'),
              ),
              const SizedBox(height: 10),
              _AdminCard(
                icon: Icons.lock_rounded,
                title: 'OAuth Providers',
                subtitle: 'Google, Facebook — configuración',
                onTap: () => context.go('/admin/oauth'),
              ),
              const SizedBox(height: 10),
              _AdminCard(
                icon: Icons.report_rounded,
                title: 'Reportes',
                subtitle: 'Contratos por usuario y acertaciones',
                onTap: () => context.go('/admin/reports'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: LuxoraColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final VoidCallback onTap;

  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? LuxoraColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LuxoraColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LuxoraColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: c, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: LuxoraColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: LuxoraColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: LuxoraColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
