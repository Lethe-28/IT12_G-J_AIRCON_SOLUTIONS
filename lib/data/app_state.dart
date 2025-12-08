import 'package:flutter/material.dart';

enum UserRole { admin, serviceManager }

class AppState {
  static UserRole currentRole = UserRole.admin;
  static String currentUserName = 'Admin';
  static bool isSidebarCollapsed = false;

  // Shared job orders list - accessible by both admin and service manager
  static final List<dynamic> sharedJobOrders = [];
  static bool _jobOrdersSeeded = false;

  static bool get jobOrdersSeeded => _jobOrdersSeeded;
  static void setJobOrdersSeeded(bool value) => _jobOrdersSeeded = value;

  static bool hasShownWelcome = false;

  static String headerWelcomeText() {
    final label = currentRole == UserRole.serviceManager
        ? 'Service Manager'
        : 'Admin';
    return 'Welcome, $label ($currentUserName)';
  }

  static String headerSubtitle() {
    return "";
  }

  static IconData roleAvatarIcon() {
    return currentRole == UserRole.serviceManager
        ? Icons.handyman_outlined
        : Icons.admin_panel_settings_outlined;
  }

  static String roleInitials() {
    if (currentUserName.isNotEmpty) {
      return currentUserName.trim()[0].toUpperCase();
    }
    return currentRole == UserRole.serviceManager ? 'S' : 'A';
  }

  static String roleDisplayName() {
    // If a username is set, show it. Otherwise fall back to role label.
    if (currentUserName.trim().isNotEmpty) {
      return currentUserName;
    }
    return currentRole == UserRole.serviceManager
        ? 'Service Manager'
        : 'Admin User';
  }
}
