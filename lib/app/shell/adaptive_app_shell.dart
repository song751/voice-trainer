import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/route_names.dart';

class AdaptiveAppShell extends StatelessWidget {
  const AdaptiveAppShell({
    required this.currentPath,
    required this.child,
    super.key,
  });

  final String currentPath;
  final Widget child;

  static const _destinations = <_ShellDestination>[
    _ShellDestination(RoutePaths.home, '首页', Icons.home_outlined),
    _ShellDestination(RoutePaths.livePractice, '练习', Icons.mic_none),
    _ShellDestination(RoutePaths.result, '结果', Icons.summarize_outlined),
    _ShellDestination(RoutePaths.history, '历史', Icons.history),
    _ShellDestination(RoutePaths.settings, '设置', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _destinations.indexWhere(
      (destination) => destination.path == currentPath,
    );
    final index = selectedIndex < 0 ? 0 : selectedIndex;
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final navigation = isWide
        ? NavigationRail(
            selectedIndex: index,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (value) => _go(context, value),
            destinations: _destinations
                .map(
                  (destination) => NavigationRailDestination(
                    icon: Icon(destination.icon),
                    label: Text(destination.label),
                  ),
                )
                .toList(),
          )
        : null;

    return PopScope(
      canPop: currentPath == RoutePaths.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && currentPath != RoutePaths.home) {
          context.go(RoutePaths.home);
        }
      },
      child: Scaffold(
        body: isWide
            ? Row(
                children: <Widget>[
                  SafeArea(child: navigation!),
                  const VerticalDivider(width: 1),
                  Expanded(child: child),
                ],
              )
            : child,
        bottomNavigationBar: isWide
            ? null
            : NavigationBar(
                selectedIndex: index,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (value) => _go(context, value),
                destinations: _destinations
                    .map(
                      (destination) => NavigationDestination(
                        icon: Icon(destination.icon),
                        label: destination.label,
                        tooltip: destination.label,
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  void _go(BuildContext context, int index) {
    context.go(_destinations[index].path);
  }
}

class _ShellDestination {
  const _ShellDestination(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}
