import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/dreams/presentation/dream_screen.dart';
import '../../features/lottery/presentation/lottery_screen.dart';
import '../../features/lottery/presentation/history_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import '../../features/payments/presentation/bank_accounts_screen.dart';
import '../../features/payments/presentation/donations_screen.dart';
import '../../features/commitment/presentation/pull10_screen.dart';
import '../../features/admin/presentation/scraper_screen.dart';
import '../../features/admin/presentation/admin_panel_screen.dart';
import '../../features/admin/presentation/reports_screen.dart';
import '../../features/admin/presentation/engine_pool_screen.dart';
import '../../features/admin/presentation/user_management_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      // Don't redirect from splash — it handles its own navigation
      if (state.matchedLocation == '/splash') return null;
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      final isAuth = token != null;
      final isLoginRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (!isAuth && !isLoginRoute) return '/login';
      if (isAuth && isLoginRoute) return '/lottery';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/lottery', builder: (_, __) => const LotteryScreen()),
      GoRoute(path: '/dreams', builder: (_, __) => const DreamScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/stats', builder: (_, __) => const StatsScreen()),
      GoRoute(
          path: '/bank-accounts',
          builder: (_, __) => const BankAccountsScreen()),
      GoRoute(path: '/donations', builder: (_, __) => const DonationsScreen()),
      GoRoute(path: '/pull-10', builder: (_, __) => const Pull10Screen()),
      GoRoute(
          path: '/admin/scraper', builder: (_, __) => const ScraperScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminPanelScreen()),
      GoRoute(path: '/admin/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/admin/engine-pool', builder: (_, __) => const EnginePoolScreen()),
      GoRoute(path: '/admin/users', builder: (_, __) => const UserManagementScreen()),
    ],
  );
});
