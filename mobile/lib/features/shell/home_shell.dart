import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin/admin_repository.dart';
import '../auth/auth_controller.dart';

/// Branch indexes of the tab shell; must match the branch order in router.dart.
abstract final class Tabs {
  static const scan = 0;
  static const search = 1;
  static const map = 2;
  static const me = 3;
  static const admin = 4;
}

/// Exposes the visible tab to screens the shell keeps alive in the background
/// (the camera, in particular), so they can pause themselves. Driven straight
/// from the router's current branch, so redirects keep it in sync too.
class ActiveTab extends InheritedWidget {
  const ActiveTab({super.key, required this.index, required super.child});

  final int index;

  /// Registers a dependency: the caller's didChangeDependencies runs when the
  /// visible tab changes.
  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ActiveTab>()?.index ?? Tabs.scan;

  @override
  bool updateShouldNotify(ActiveTab oldWidget) => oldWidget.index != index;
}

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(authControllerProvider).value?.isAdmin ?? false;
    final unreadReports = isAdmin ? ref.watch(unreadReportsProvider).value ?? 0 : 0;

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.qr_code_scanner_outlined),
        selectedIcon: Icon(Icons.qr_code_scanner),
        label: 'Scan',
      ),
      const NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
      const NavigationDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map),
        label: 'Pharmacies',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Me',
      ),
      if (isAdmin)
        NavigationDestination(
          icon: Badge(
            isLabelVisible: unreadReports > 0,
            label: Text('$unreadReports'),
            child: const Icon(Icons.admin_panel_settings_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: unreadReports > 0,
            label: Text('$unreadReports'),
            child: const Icon(Icons.admin_panel_settings),
          ),
          label: 'Admin',
        ),
    ];

    // The admin tab is the last branch, so for everyone else the visible
    // destinations line up with branch indexes 0..3. The clamp covers the
    // single frame between an admin logging out on the admin tab and the
    // router's redirect moving them off it.
    return ActiveTab(
      index: navigationShell.currentIndex,
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: min(navigationShell.currentIndex, destinations.length - 1),
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: destinations,
        ),
      ),
    );
  }
}
