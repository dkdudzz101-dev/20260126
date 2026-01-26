import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 현재 사용자
  User? get currentUser => _client.auth.currentUser;

  // 로그인 상태
  bool get isLoggedIn => currentUser != null;

  // 이메일 로그인
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // 이메일 회원가입
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  // 카카오 로그인
  Future<bool> signInWithKakao() async {
    try {
      final response = await _client.auth.signInWithOAuth(
        OAuthProvider.kakao,
        redirectTo: 'com.jejuoreum.app://login-callback',
      );
      return response;
    } catch (e) {
      print('Kakao login error: $e');
      return false;
    }
  }

  // 애플 로그인
  Future<AuthResponse> signInWithApple() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'com.jejuoreum.app://login-callback',
    ).then((_) => _client.auth.currentSession != null
        ? AuthResponse(session: _client.auth.currentSession, user: currentUser)
        : throw Exception('Apple login failed'));
  }

  // 로그아웃
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // 비밀번호 재설정 이메일 발송
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // 프로필 생성/업데이트
  Future<void> upsertProfile({
    required String id,
    String? nickname,
    String? profileImage,
    String? bio,
    String? provider,
  }) async {
    await _client.from('users').upsert({
      'id': id,
      'nickname': nickname,
      'profile_image': profileImage,
      'bio': bio,
      'provider': provider,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // 프로필 가져오기
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .single();
    return response;
  }
}
