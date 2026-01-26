import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class InquiryService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 문의 유형
  static const Map<String, String> inquiryCategories = {
    'app_usage': '앱 사용 문의',
    'error': '오류 신고',
    'feature': '기능 제안',
    'account': '계정 문의',
    'other': '기타',
  };

  // 문의하기
  Future<void> createInquiry({
    required String category,
    required String email,
    required String title,
    required String content,
  }) async {
    final userId = _client.auth.currentUser?.id;

    await _client.from('inquiries').insert({
      'user_id': userId,
      'category': category,
      'email': email,
      'title': title,
      'content': content,
      'status': 'pending',
    });
  }

  // 내 문의 목록 가져오기
  Future<List<Map<String, dynamic>>> getMyInquiries() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('inquiries')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
