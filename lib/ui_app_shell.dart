import 'package:flutter/material.dart';
import 'data/app_state.dart';

class AppShell extends StatefulWidget {
  final int selectedIndex;
  final Widget body;

  const AppShell({super.key, required this.selectedIndex, required this.body});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Key to control the mobile drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State for the sub-menu expansion
  bool _adminMenuExpanded = true;

  // State for the desktop sidebar collapse (minimized vs full)
  bool _desktopSidebarCollapsed = false;

  void _onSelect(BuildContext context, int index) {
    // Map navigation indices to routes
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
      // If we are on mobile and the drawer is open, close it first
      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
        Navigator.of(context).pop();
      }

      // Small delay to ensure drawer closing animation finishes smoothly
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && ModalRoute.of(context)?.settings.name != route) {
          Navigator.of(context).pushReplacementNamed(route);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // HCI STANDARD: Breakpoint usually around 700-900px
        final bool isMobile = constraints.maxWidth < 800;

        // --- MOBILE LAYOUT (Infinix Note 50) ---
        if (isMobile) {
          return Scaffold(
            key: _scaffoldKey, // Required to open drawer programmatically
            backgroundColor: const Color(0xFFF5F5F5),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 1,
              title: _MobileAppBarTitle(selectedIndex: widget.selectedIndex),
              iconTheme: const IconThemeData(color: Colors.black87),
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
            // The "Floating" Sidebar
            drawer: Drawer(
              width: 280,
              backgroundColor: Colors.white,
              child: Column(
                children: [
                  _MobileDrawerHeader(),
                  const Divider(height: 1),
                  Expanded(
                    child: _NavigationList(
                      selectedIndex: widget.selectedIndex,
                      adminMenuExpanded: _adminMenuExpanded,
                      onAdminExpandToggle: () => setState(
                        () => _adminMenuExpanded = !_adminMenuExpanded,
                      ),
                      onSelect: (index) => _onSelect(context, index),
                    ),
                  ),
                  _UserFooter(isCollapsed: false),
                ],
              ),
            ),
            body: widget.body,
          );
        }

        // --- DESKTOP LAYOUT (PC / Large Tablet) ---
        final double sidebarWidth = _desktopSidebarCollapsed ? 70 : 250;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Row(
            children: [
              // Permanent Sidebar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: sidebarWidth,
                color: Colors.white,
                child: Column(
                  children: [
                    _DesktopSidebarHeader(
                      isCollapsed: _desktopSidebarCollapsed,
                      onToggle: () => setState(
                        () => _desktopSidebarCollapsed =
                            !_desktopSidebarCollapsed,
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _NavigationList(
                        selectedIndex: widget.selectedIndex,
                        adminMenuExpanded: _adminMenuExpanded,
                        onAdminExpandToggle: () => setState(
                          () => _adminMenuExpanded = !_adminMenuExpanded,
                        ),
                        onSelect: (index) => _onSelect(context, index),
                        isDesktopCollapsed: _desktopSidebarCollapsed,
                      ),
                    ),
                    const Divider(height: 1),
                    _UserFooter(isCollapsed: _desktopSidebarCollapsed),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              // Main Content Area
              Expanded(child: widget.body),
            ],
          ),
        );
      },
    );
  }
}

// ==============================================================================
// HELPER WIDGETS (Extracted to keep the main logic clean)
// ==============================================================================

class _NavigationList extends StatelessWidget {
  final int selectedIndex;
  final bool adminMenuExpanded;
  final VoidCallback onAdminExpandToggle;
  final Function(int) onSelect;
  final bool isDesktopCollapsed;

  const _NavigationList({
    required this.selectedIndex,
    required this.adminMenuExpanded,
    required this.onAdminExpandToggle,
    required this.onSelect,
    this.isDesktopCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _navTile(0, Icons.dashboard_outlined, 'Dashboard'),
        _navTile(1, Icons.calendar_today, 'Job Order & Scheduling'),
        _navTile(2, Icons.payments_outlined, 'Expenses'),
        _navTile(3, Icons.description, 'Documents'),
        _navTile(4, Icons.bar_chart, 'Reports'),

        if (AppState.currentRole == UserRole.admin) ...[
          const Divider(height: 16),
          _adminNavGroup([
            _navTile(5, Icons.people_outline, 'Customers'),
            _navTile(6, Icons.handyman_outlined, 'Technicians'),
            _navTile(7, Icons.ac_unit, 'Aircon Units'),
            _navTile(8, Icons.inventory_2_outlined, 'Service Items'),
            _navTile(9, Icons.settings_applications, 'Master Data'),
            _navTile(10, Icons.people_alt_outlined, 'User Management'),
          ]),
        ],

        const Divider(height: 16),
        _navTile(
          AppState.currentRole == UserRole.admin ? 11 : 5,
          Icons.settings_outlined,
          'Settings',
        ),
      ],
    );
  }

  Widget _navTile(int index, IconData icon, String label) {
    final bool isSelected = selectedIndex == index;

    // If desktop is collapsed, we show a Tooltip. On mobile, we never need a tooltip.
    Widget content = ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.black87 : Colors.black54,
        size: 20,
      ),
      title: isDesktopCollapsed
          ? null
          : Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black87 : Colors.black54,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
      onTap: () => onSelect(index),
      dense: true,
      horizontalTitleGap: isDesktopCollapsed ? 0 : 12,
      contentPadding: EdgeInsets.symmetric(
        horizontal: isDesktopCollapsed ? 12 : 20,
        vertical: 0,
      ),
      minLeadingWidth: isDesktopCollapsed ? 0 : 32,
    );

    if (isDesktopCollapsed) {
      content = Tooltip(message: label, child: content);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF3F4F6) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: content,
    );
  }

  Widget _adminNavGroup(List<Widget> children) {
    if (isDesktopCollapsed) {
      // In collapsed mode, we just list the items without the dropdown logic
      return Column(children: children);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(
            Icons.layers_outlined,
            color: Colors.black54,
            size: 20,
          ),
          title: const Text(
            'Records & Data',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          trailing: Icon(
            adminMenuExpanded ? Icons.expand_less : Icons.expand_more,
            color: Colors.black54,
            size: 18,
          ),
          onTap: onAdminExpandToggle,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        if (adminMenuExpanded) Column(children: children),
      ],
    );
  }
}

class _MobileDrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(25),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Image.asset(
                'lib/image/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => const Icon(Icons.ac_unit),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'G & J',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Solutions',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopSidebarHeader extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;

  const _DesktopSidebarHeader({
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 12 : 20,
        vertical: 20,
      ),
      child: Row(
        mainAxisAlignment: isCollapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: [
          if (!isCollapsed) ...[
            SizedBox(
              width: 32,
              height: 32,
              child: Image.asset(
                'lib/image/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => const Icon(Icons.ac_unit),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'G & J System',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
          IconButton(
            icon: Icon(isCollapsed ? Icons.menu : Icons.menu_open),
            onPressed: onToggle,
            tooltip: isCollapsed ? 'Expand' : 'Collapse',
          ),
        ],
      ),
    );
  }
}

class _UserFooter extends StatelessWidget {
  final bool isCollapsed;
  const _UserFooter({required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(isCollapsed ? 8 : 20),
      child: Column(
        children: [
          if (!isCollapsed)
            const Row(
              children: [
                CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Signed in',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        'Admin User',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/login'),
            icon: const Icon(Icons.logout, size: 16),
            label: isCollapsed ? const SizedBox.shrink() : const Text('Logout'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
              padding: isCollapsed ? EdgeInsets.zero : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileAppBarTitle extends StatelessWidget {
  final int selectedIndex;
  const _MobileAppBarTitle({required this.selectedIndex});

  String? _labelForIndex(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Job Order & Scheduling';
      case 2:
        return 'Expenses';
      case 3:
        return 'Documents';
      case 4:
        return 'Reports';
      case 5:
        return AppState.currentRole == UserRole.admin ? 'Customers' : 'Settings';
      case 6:
        return 'Technicians';
      case 7:
        return 'Aircon Units';
      case 8:
        return 'Service Items';
      case 9:
        return 'Master Data';
      case 10:
        return 'User Management';
      case 11:
        return 'Settings';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _labelForIndex(selectedIndex);
    // Show only the current section name on mobile (per user request).
    if (subtitle != null) {
      return Text(
        subtitle,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // Fallback to company name if no section label is available.
    return const Text(
      'G & J System',
      style: TextStyle(
        color: Colors.black87,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
