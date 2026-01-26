import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://zsodcfgchbmmvpbwhuyu.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpzb2RjZmdjaGJtbXZwYndodXl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc2NjU2MTQsImV4cCI6MjA4MzI0MTYxNH0.XkQHyzl0I-kJ3yZYniry-DXfKTDZ5H_b5qV-uNvmXe8';
  static const String storageUrl = '$supabaseUrl/storage/v1/object/public';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
  }
}
