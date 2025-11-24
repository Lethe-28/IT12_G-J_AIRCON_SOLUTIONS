import 'package:flutter/material.dart';
import 'data/app_state.dart';

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
  bool _adminMenuExpanded = true;

  bool get _isCollapsed => AppState.isSidebarCollapsed;

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset admin menu when widget updates (navigation occurs)
    _adminMenuExpanded = true;
  }

  void _onSelect(BuildContext context, int index) {
    // Map navigation indices to routes based on role
    final routeMap = <int, String>{
      0: '/dashboard',
      1: '/scheduling',
      2: '/expenses',
      3: '/documents',
      4: '/reports',
    };
    
    if (AppState.currentRole == UserRole.admin) {
      routeMap[5] = '/customers';
      routeMap[6] = '/technicians';
      routeMap[7] = '/aircons';
      routeMap[8] = '/service-items';
      routeMap[9] = '/master-data';
      routeMap[10] = '/users';
      routeMap[11] = '/settings';
    } else {
      routeMap[5] = '/settings';
    }
    
    final route = routeMap[index];
    if (route != null) {
      // Delay navigation slightly to avoid conflicts
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && ModalRoute.of(context)?.settings.name != route) {
          Navigator.of(context).pushReplacementNamed(route);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double sidebarWidth = _isCollapsed ? 80 : 240;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Row(
        children: [
          Container(
            width: sidebarWidth,
            constraints: BoxConstraints(maxWidth: sidebarWidth, minWidth: sidebarWidth),
            color: Colors.white,
            child: SafeArea(
              child: Column(
                crossAxisAlignment:
                    _isCollapsed ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        _isCollapsed ? 12 : 20, 24, _isCollapsed ? 12 : 20, 12),
                    child: _isCollapsed
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    'lib/image/logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              IconButton(
                                icon: const Icon(Icons.menu, size: 20),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  AppState.isSidebarCollapsed = !AppState.isSidebarCollapsed;
                                  setState(() {});
                                },
                                tooltip: 'Expand sidebar',
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    'lib/image/logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.menu_open, size: 20),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  AppState.isSidebarCollapsed = !AppState.isSidebarCollapsed;
                                  setState(() {});
                                },
                                tooltip: 'Collapse sidebar',
                              ),
                            ],
                          ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      children: [
                        _navTile(context, 0, Icons.dashboard_outlined, 'Dashboard'),
                        _navTile(context, 1, Icons.calendar_today, 'Job Order & Scheduling'),
                        _navTile(context, 2, Icons.payments_outlined, 'Expenses'),
                        _navTile(context, 3, Icons.description, 'Documents'),
                        _navTile(context, 4, Icons.bar_chart, 'Reports'),
                        if (AppState.currentRole == UserRole.admin) ...[
                          const Divider(height: 16),
                          _adminNavGroup([
                            _navTile(context, 5, Icons.people_outline, 'Customers'),
                            _navTile(context, 6, Icons.handyman_outlined, 'Technicians'),
                            _navTile(context, 7, Icons.ac_unit, 'Aircon Units'),
                            _navTile(context, 8, Icons.inventory_2_outlined, 'Service Items'),
                            _navTile(context, 9, Icons.settings_applications, 'Master Data'),
                            _navTile(context, 10, Icons.people_alt_outlined, 'User Management'),
                          ]),
                        ],
                        _navTile(
                            context,
                            AppState.currentRole == UserRole.admin ? 11 : 5,
                            Icons.settings_outlined,
                            'Settings'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: _isCollapsed ? 16 : 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: _isCollapsed
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        if (!_isCollapsed)
                          const Text('Signed in as',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: _isCollapsed
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              child: Text(AppState.roleInitials()),
                            ),
                            if (!_isCollapsed) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(AppState.roleDisplayName(),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                        if (!_isCollapsed) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context)
                                  .pushReplacementNamed('/login'),
                              icon: const Icon(Icons.logout, size: 16),
                              label: const Text('Logout'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black87,
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: SafeArea(
                child: widget.body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(BuildContext context, int index, IconData icon, String label) {
    final bool isSelected = widget.selectedIndex == index;
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _isCollapsed ? 8 : 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF3F4F6) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.black87 : Colors.black54,
          size: 20,
        ),
        title: _isCollapsed
            ? null
            : Text(label,
                style: TextStyle(
                    color: isSelected ? Colors.black87 : Colors.black54,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
        onTap: () => _onSelect(context, index),
        dense: true,
        horizontalTitleGap: _isCollapsed ? 0 : 12,
        contentPadding:
            EdgeInsets.symmetric(horizontal: _isCollapsed ? 12 : 16, vertical: 4),
        minLeadingWidth: _isCollapsed ? 0 : 40,
      ),
    );
  }

  Widget _adminNavGroup(List<Widget> children) {
    if (_isCollapsed) {
      return Column(children: children);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.layers_outlined, color: Colors.black54),
          title: const Text(
            'Records & Master Data',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: Icon(
            _adminMenuExpanded ? Icons.expand_less : Icons.expand_more,
            color: Colors.black54,
            size: 20,
          ),
          onTap: () {
            setState(() {
              _adminMenuExpanded = !_adminMenuExpanded;
            });
          },
        ),
        AnimatedCrossFade(
          firstChild: Column(children: children),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _adminMenuExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}





