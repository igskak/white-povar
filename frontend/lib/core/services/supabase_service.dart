import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  
  SupabaseService._();
  
  late final SupabaseClient _client;
  
  SupabaseClient get client => _client;
  
  Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    
    _client = Supabase.instance.client;
  }
  
  // Authentication methods
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }
  
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
  
  User? get currentUser => _client.auth.currentUser;
  
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  
  // Storage methods
  Future<String> uploadFile(String bucket, String path, List<int> fileBytes) async {
    await _client.storage.from(bucket).uploadBinary(path, fileBytes);
    return _client.storage.from(bucket).getPublicUrl(path);
  }
  
  Future<void> deleteFile(String bucket, String path) async {
    await _client.storage.from(bucket).remove([path]);
  }
  
  // Database methods
  SupabaseQueryBuilder from(String table) => _client.from(table);
  
  // Real-time subscriptions
  RealtimeChannel channel(String name) => _client.channel(name);
}
