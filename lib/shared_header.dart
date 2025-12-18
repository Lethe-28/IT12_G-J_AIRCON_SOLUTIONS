import 'package:flutter/material.dart';

class SharedHeader extends StatelessWidget {
  final String welcomeText;
  final String subtitleText;
  final int notificationCount;
  final bool showGreeting;
  final bool showSearch;
  final bool showNotifications;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onNotificationTap;
  final Widget? customTitle;

  const SharedHeader({
    super.key,
    this.welcomeText = '', // Default to empty if using customTitle
    this.subtitleText = '',
    this.notificationCount = 0,
    this.showGreeting = true,
    this.showSearch = true,
    this.showNotifications = true,
    this.onSearchChanged,
    this.onNotificationTap,
    this.customTitle,
  });

  Color _getNotificationColor(int count) {
    if (count >= 10) return Colors.red;
    if (count >= 5) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final notificationColor = _getNotificationColor(notificationCount);
    final isServiceManager = welcomeText.contains('Service Manager');
    final titleFontSize = showGreeting
        ? (isServiceManager ? 28.0 : 24.0)
        : 24.0;
    final subtitleFontSize = showGreeting
        ? (isServiceManager ? 16.0 : 14.0)
        : 14.0;
    final searchFontSize = isServiceManager ? 16.0 : 14.0;

    return Container(
      color: const Color(0xFFF5F5F5),
      padding: EdgeInsets.all(showGreeting ? (isServiceManager ? 24 : 20) : 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;
          
          final notificationButton = showNotifications ? InkWell(
            onTap: onNotificationTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.notifications_none,
                      color: Colors.black54,
                      size: 24,
                    ),
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: notificationColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          notificationCount > 99 ? '99+' : notificationCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ) : const SizedBox.shrink();

          final titleSection = customTitle ?? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (welcomeText.isNotEmpty)
                Text(
                  welcomeText,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              if (welcomeText.isNotEmpty) const SizedBox(height: 4),
              if (subtitleText.isNotEmpty)
                Text(
                  subtitleText,
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: Colors.black54,
                  ),
                ),
            ],
          );

          if (isCompact) {
             // Mobile: Title on top, Search + Notification on bottom
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleSection,
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (showSearch)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            onChanged: onSearchChanged,
                            style: TextStyle(fontSize: searchFontSize),
                            decoration: InputDecoration(
                              hintText: 'Search anything...',
                              hintStyle: TextStyle(fontSize: searchFontSize),
                              prefixIcon: const Icon(Icons.search, color: Colors.black54),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: isServiceManager ? 16 : 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (showNotifications) ...[
                      SizedBox(width: showSearch ? 12 : 0),
                      notificationButton,
                    ],
                  ],
                ),
              ],
            );
          }
          
          // Desktop: Title | Search | Notification
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 2, child: titleSection),
              const SizedBox(width: 24),
              if (showSearch)
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      onChanged: onSearchChanged,
                      style: TextStyle(fontSize: searchFontSize),
                      decoration: InputDecoration(
                        hintText: 'Search anything...',
                        hintStyle: TextStyle(fontSize: searchFontSize),
                        prefixIcon: const Icon(Icons.search, color: Colors.black54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isServiceManager ? 16 : 12,
                        ),
                      ),
                    ),
                  ),
                ),
              if (showNotifications) ...[
                const SizedBox(width: 16),
                notificationButton,
              ],
            ],
          );
        },
      ),
    );
  }
}

