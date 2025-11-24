import 'package:flutter/material.dart';

class SharedHeader extends StatelessWidget {
  final String welcomeText;
  final String subtitleText;
  final int notificationCount;
  final bool showGreeting;
  final bool showSearch;
  final bool showNotifications;

  const SharedHeader({
    super.key,
    required this.welcomeText,
    required this.subtitleText,
    this.notificationCount = 0,
    this.showGreeting = true,
    this.showSearch = true,
    this.showNotifications = true,
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
          final titleSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                welcomeText,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitleText,
                style: TextStyle(
                  fontSize: subtitleFontSize,
                  color: Colors.black54,
                ),
              ),
            ],
          );

          final searchSection = (showSearch || showNotifications)
              ? Row(
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
                        const SizedBox(width: 12),
                        Container(
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
                      ],
                    ],
                  )
              : const SizedBox.shrink();

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleSection,
                if (showSearch || showNotifications) ...[
                  const SizedBox(height: 16),
                  searchSection,
                ],
              ],
            );
          }
          
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleSection),
              if (showSearch || showNotifications) ...[
                const SizedBox(width: 16),
                Expanded(child: searchSection),
              ],
            ],
          );
        },
      ),
    );
  }
}

