import 'package:flutter/material.dart';

import '../localization/app_localizations_x.dart';
import 'dashboard_screen.dart';
import 'restrictions_screen.dart';
import 'settings_screen.dart';

/// Root scaffold after onboarding: bottom navigation between the three tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No extendBody: it let tab content scroll under the nav strip, hiding
      // the last row (e.g. Settings > Send feedback) with no way to reach it.
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          RestrictionsScreen(),
          SettingsScreen(),
        ],
      ),
      // Compact icon row on a semi-transparent dark strip.
      bottomNavigationBar: ColoredBox(
        color: const Color(0xB3070A10),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NavIcon(
                  icon: Icons.home,
                  tooltip: context.l10n.navHome,
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                const SizedBox(width: 56),
                _NavIcon(
                  icon: Icons.lock_outline,
                  tooltip: context.l10n.restrictionsTitle,
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                const SizedBox(width: 56),
                _NavIcon(
                  icon: Icons.settings,
                  tooltip: context.l10n.settingsTitle,
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 22,
      onPressed: onTap,
      isSelected: selected,
      color: selected ? Theme.of(context).colorScheme.primary : Colors.white,
      icon: Icon(icon),
    );
  }
}
