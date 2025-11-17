import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  final int selectedIndex;
  final Widget body;

  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.body,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isCollapsed = false;

  void _onSelect(BuildContext context, int index) {
    const routes = [
      '/dashboard',
      '/scheduling',
      '/expenses',
      '/documents',
      '/reports',
      '/users',
      '/settings',
    ];
    if (index >= 0 && index < routes.length) {
      final route = routes[index];
      if (ModalRoute.of(context)?.settings.name != route) {
        Navigator.of(context).pushReplacementNamed(route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double sidebarWidth = _isCollapsed ? 80 : 240;
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: sidebarWidth,
            color: Colors.white,
            child: SafeArea(
              child: Column(
                crossAxisAlignment:
                    _isCollapsed ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        _isCollapsed ? 12 : 20, 24, _isCollapsed ? 12 : 20, 12),
                    child: Row(
                      mainAxisAlignment: _isCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: const Text('G&J',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                        if (!_isCollapsed) ...[
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('G & J System',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                                SizedBox(height: 2),
                                Text('Schedule & Expense',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.black54)),
                              ],
                            ),
                          ),
                        ],
                        IconButton(
                          icon: Icon(
                            _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                            size: 18,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _isCollapsed = !_isCollapsed;
                            });
                          },
                          tooltip: _isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _navTile(context, 0, Icons.dashboard_outlined, 'Dashboard'),
                        _navTile(context, 1, Icons.event_note_outlined, 'Scheduling'),
                        _navTile(context, 2, Icons.payments_outlined, 'Expenses'),
                        _navTile(context, 3, Icons.folder_outlined, 'Documents'),
                        _sectionHeader('Management'),
                        _navTile(context, 4, Icons.bar_chart_outlined, 'Reports'),
                        _navTile(context, 5, Icons.people_alt_outlined, 'User Management'),
                        _navTile(context, 6, Icons.settings_outlined, 'Settings'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(
                      radius: 16,
                      child: Text('A'),
                    ),
                    title: _isCollapsed
                        ? null
                        : const Text('Admin User',
                            style: TextStyle(fontSize: 14)),
                    subtitle: _isCollapsed
                        ? null
                        : const Text('Admin', style: TextStyle(fontSize: 12)),
                    trailing: _isCollapsed
                        ? null
                        : TextButton(
                            onPressed: () => Navigator.of(context)
                                .pushReplacementNamed('/login'),
                            child: const Text('Logout'),
                          ),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: _isCollapsed ? 16 : 20),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: SafeArea(child: widget.body)),
        ],
      ),
    );
  }

  Widget _navTile(BuildContext context, int index, IconData icon, String label) {
    final bool isSelected = widget.selectedIndex == index;
    return ListTile(
      selected: isSelected,
      selectedTileColor: const Color(0xFFEAF2FF),
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black54,
      ),
      title: _isCollapsed ? null : Text(label),
      onTap: () => _onSelect(context, index),
      dense: true,
      horizontalTitleGap: _isCollapsed ? 0 : 12,
      contentPadding:
          EdgeInsets.symmetric(horizontal: _isCollapsed ? 20 : 16, vertical: 2),
    );
  }

  Widget _sectionHeader(String text) {
    if (_isCollapsed) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black54,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}




