import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/admin/admin_screen.dart';
import 'features/admin/report_detail_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/me/me_screen.dart';
import 'features/medicine/medicine_detail_screen.dart';
import 'features/medicine/search_screen.dart';
import 'features/pharmacies/pharmacies_screen.dart';
import 'features/report/report_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/verify/verify_flow_screen.dart';
import 'models/scan_result.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Re-runs `redirect` whenever the signed-in user changes.
  final authChanges = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => authChanges.value++);
  ref.onDispose(authChanges.dispose);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/scan',
    refreshListenable: authChanges,
    redirect: (context, state) {
      final user = ref.read(authControllerProvider).value;
      if (state.matchedLocation.startsWith('/admin') && !(user?.isAdmin ?? false)) {
        return '/me';
      }
      return null;
    },
    routes: [
      // Full-screen routes pushed over the tab bar.
      GoRoute(
        path: '/verify',
        parentNavigatorKey: _rootNavigatorKey,
        // The scan result travels as `extra`; it isn't restorable from a URL,
        // so a cold deep link here falls back to the scanner.
        redirect: (context, state) => state.extra is ScanResult ? null : '/scan',
        builder: (context, state) => VerifyFlowScreen(result: state.extra! as ScanResult),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/report',
        parentNavigatorKey: _rootNavigatorKey,
        // Reports are tied to an account; openReportForm logs in first, this
        // only guards against arriving here signed out some other way.
        redirect: (context, state) => ref.read(authControllerProvider).value == null ? '/login' : null,
        builder: (context, state) => ReportScreen(target: state.extra as ReportTarget? ?? const ReportTarget()),
      ),
      GoRoute(
        path: '/medicines/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => MedicineDetailScreen(medicineId: state.pathParameters['id']!),
      ),
      // Admin-only, like the /admin tab (see `redirect` above).
      GoRoute(
        path: '/admin/reports/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ReportDetailScreen(reportId: state.pathParameters['id']!),
      ),
      // Branch order must match `Tabs` in home_shell.dart.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/scan', builder: (context, state) => const ScanScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/pharmacies', builder: (context, state) => const PharmaciesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/me', builder: (context, state) => const MeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
