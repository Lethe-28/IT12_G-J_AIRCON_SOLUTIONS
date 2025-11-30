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

  static String headerWelcomeText() {
    final label = currentRole == UserRole.serviceManager ? 'Service Manager' : 'Admin';
    return 'Welcome, $label ($currentUserName)!';
  }

  static String headerSubtitle() {
    if (currentRole == UserRole.serviceManager) {
      return "Quick overview of today's jobs, schedules, and expenses.";
    }
    return "Here's what happening with your business today.";
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
    final label = currentRole == UserRole.serviceManager ? 'Service Manager' : 'Admin User';
    return currentUserName.isEmpty ? label : label;
  }
}
