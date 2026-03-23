import 'package:flutter/material.dart';

/// MainScaffold provides a responsive layout with a persistent left sidebar for desktop/web
/// and a drawer for mobile. It is intended to be used as the root layout for all main app screens.
class MainScaffold extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  final VoidCallback? themeToggle;
  final ThemeMode? themeMode;
  const MainScaffold({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.themeToggle,
    this.themeMode,
  });

  static const List<_NavItem> _navItems = [
    _NavItem('Dashboard', Icons.dashboard_outlined),
    _NavItem('Deadlines', Icons.event_note_outlined),
    _NavItem('Assignments', Icons.assignment_outlined),
    _NavItem('Profile', Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      drawer: isWide ? null : Drawer(
        child: _SidebarContent(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          themeToggle: themeToggle,
          themeMode: themeMode,
        ),
      ),
      body: Row(
        children: [
          if (isWide)
            SizedBox(
              width: 220,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 2,
                child: _SidebarContent(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  themeToggle: themeToggle,
                  themeMode: themeMode,
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? themeToggle;
  final ThemeMode? themeMode;

  const _SidebarContent({
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.themeToggle,
    this.themeMode,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'UniDash',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (themeToggle != null)
                Builder(builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return IconButton(
                    icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                    tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                    onPressed: themeToggle,
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ...List.generate(MainScaffold._navItems.length, (i) {
          final item = MainScaffold._navItems[i];
          return ListTile(
            leading: Icon(item.icon, color: i == selectedIndex ? Theme.of(context).colorScheme.primary : null),
            title: Text(item.label),
            selected: i == selectedIndex,
            onTap: () => onDestinationSelected(i),
          );
        }),
      ],
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}
