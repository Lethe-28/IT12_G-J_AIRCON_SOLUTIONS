import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityLogger {
  static final _supabase = Supabase.instance.client;

  /// Call this whenever a user does something important
  static Future<void> log({
    required String type, // e.g., 'Create', 'Delete', 'Payment'
    required String details, // e.g., 'Created Job JO-1234'
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Get the current user's name (optional, but looks better)
      // You might already have this in AppState, but fetching it here is safe.
      final userDetails = await _supabase
          .from('app_users') // Or your profiles table
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      final name = userDetails?['full_name'] ?? user.email ?? 'Unknown User';

      // 2. Insert the log
      await _supabase.from('activity_logs').insert({
        'user_id': user.id,
        'user_name': name,
        'action_type': type,
        'details': details,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Fail silently so we don't crash the app if logging fails
      print('Failed to log activity: $e');
    }
  }
}
