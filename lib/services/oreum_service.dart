import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/oreum_model.dart';

class OreumService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 활성화된 오름만 가져오기
  Future<List<OreumModel>> getAllOreums() async {
    final response = await _client
        .from('oreums')
        .select()
        .eq('is_active', true)
        .order('name');

    return (response as List)
        .map((json) => OreumModel.fromJson(json))
        .toList();
  }

  // 모든 오름 가져오기 (비활성화 포함)
  Future<List<OreumModel>> getAllOreumsIncludingInactive() async {
    final response = await _client
        .from('oreums')
        .select()
        .order('name');

    return (response as List)
        .map((json) => OreumModel.fromJson(json))
        .toList();
  }

  // 오름 ID로 가져오기
  Future<OreumModel?> getOreumById(String id) async {
    final response = await _client
        .from('oreums')
        .select()
        .eq('id', id)
        .single();

    return OreumModel.fromJson(response);
  }

  // 카테고리별 오름 가져오기 (활성화된 오름만)
  Future<List<OreumModel>> getOreumsByCategory(String category) async {
    final response = await _client
        .from('oreums')
        .select()
        .eq('is_active', true)
        .contains('category', [category])
        .order('name');

    return (response as List)
        .map((json) => OreumModel.fromJson(json))
        .toList();
  }

  // 난이도별 오름 가져오기 (활성화된 오름만)
  Future<List<OreumModel>> getOreumsByDifficulty(String difficulty) async {
    final response = await _client
        .from('oreums')
        .select()
        .eq('is_active', true)
        .eq('difficulty', difficulty)
        .order('name');

    return (response as List)
        .map((json) => OreumModel.fromJson(json))
        .toList();
  }

  // 오름 검색 (활성화된 오름만)
  Future<List<OreumModel>> searchOreums(String query) async {
    final response = await _client
        .from('oreums')
        .select()
        .eq('is_active', true)
        .ilike('name', '%$query%')
        .order('name');

    return (response as List)
        .map((json) => OreumModel.fromJson(json))
        .toList();
  }

  // 테마별 오름 가져오기 (oreum_themes 매핑 테이블 사용)
  Future<List<OreumModel>> getOreumsByTheme(String themeKey) async {
    // 1. themes 테이블에서 theme_id 가져오기
    final themeResponse = await _client
        .from('themes')
        .select('id')
        .eq('key', themeKey)
        .single();

    final themeId = themeResponse['id'] as int;

    // 2. oreum_themes에서 해당 테마의 oreum_id 목록 가져오기
    final mappingResponse = await _client
        .from('oreum_themes')
        .select('oreum_id')
        .eq('theme_id', themeId);

    final oreumIds = (mappingResponse as List)
        .map((row) => row['oreum_id'].toString())
        .toList();

    if (oreumIds.isEmpty) return [];

    // 3. oreums 테이블에서 해당 오름들 가져오기
    final oreumsResponse = await _client
        .from('oreums')
        .select()
        .inFilter('id', oreumIds)
        .order('name');

    return (oreumsResponse as List)
        .map((json) => OreumModel.fromJson(json))
        .toList();
  }

  // 등산로 점검 상태 업데이트
  Future<void> updateTrailStatus(String oreumId, String status) async {
    await _client.from('oreums').update({
      'trail_status': status,
      'trail_verified_at': status == 'verified'
          ? DateTime.now().toIso8601String()
          : null,
    }).eq('id', oreumId);
  }

  // 오름 데이터 URL 가져오기 (oreum-data 버킷)
  String getOreumDataUrl(String oreumId, String fileName) {
    return _client.storage.from('oreum-data').getPublicUrl('$oreumId/$fileName');
  }

  // GeoJSON 파일 URL
  String getGeojsonUrl(String oreumId) {
    return getOreumDataUrl(oreumId, 'trail.geojson');
  }

  // 대표 이미지 URL
  String getMainImageUrl(String oreumId) {
    return getOreumDataUrl(oreumId, 'main.jpg');
  }

  // 고도 그래프 URL
  String getElevationUrl(String oreumId) {
    return getOreumDataUrl(oreumId, 'elevation.png');
  }

  // 갤러리 이미지 URL
  String getGalleryImageUrl(String oreumId, String fileName) {
    return _client.storage.from('oreum-data').getPublicUrl('$oreumId/gallery/$fileName');
  }

  // 갤러리 이미지 목록 가져오기 (공식 + 커뮤니티) - 병렬 로딩
  Future<Map<String, List<String>>> getGalleryImagesWithSource(String oreumId) async {
    // 1. 공식 이미지와 커뮤니티 이미지 병렬로 로딩
    final results = await Future.wait([
      _getOfficialImages(oreumId),
      _getCommunityImages(oreumId),
    ]);

    final officialImages = results[0];
    final communityImages = results[1];

    print('Gallery for $oreumId: official=${officialImages.length}, community=${communityImages.length}');
    return {
      'official': officialImages,
      'community': communityImages,
    };
  }

  // 공식 이미지 병렬 확인
  Future<List<String>> _getOfficialImages(String oreumId) async {
    final List<String> images = [];

    // 1~20번 이미지 URL 생성
    final urls = List.generate(20, (i) => _client.storage
        .from('oreum-data')
        .getPublicUrl('$oreumId/gallery/${i + 1}.jpg'));

    // 병렬로 HEAD 요청
    final futures = urls.map((url) async {
      try {
        final response = await http.head(Uri.parse(url)).timeout(
          const Duration(seconds: 3),
        );
        return response.statusCode == 200 ? url : null;
      } catch (e) {
        return null;
      }
    });

    final results = await Future.wait(futures);

    // null이 아닌 것만 순서대로 추가
    for (var url in results) {
      if (url != null) {
        images.add(url);
      }
    }

    return images;
  }

  // 커뮤니티 이미지 가져오기
  Future<List<String>> _getCommunityImages(String oreumId) async {
    final List<String> images = [];
    try {
      final posts = await _client
          .from('posts')
          .select('images')
          .eq('oreum_id', oreumId)
          .not('images', 'is', null)
          .order('created_at', ascending: false);  // 최신순 정렬

      for (var post in posts) {
        final postImages = post['images'];
        if (postImages != null && postImages is List) {
          images.addAll(List<String>.from(postImages));
        }
      }
    } catch (e) {
      print('Community images error: $e');
    }
    return images;
  }

  // 기존 메서드 (호환성 유지)
  Future<List<String>> getGalleryImages(String oreumId) async {
    final result = await getGalleryImagesWithSource(oreumId);
    return [...result['official']!, ...result['community']!];
  }

  // 사용자 갤러리 이미지 업로드 (posts 버킷 사용 + 커뮤니티 게시글로 등록)
  /// 갤러리 이미지 1장 업로드 (스토리지만, 게시글 X)
  Future<String> uploadGalleryImage(String oreumId, String filePath) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'gallery_${oreumId}_$timestamp.jpg';
    final storagePath = 'images/$fileName';

    final file = File(filePath);
    final bytes = await file.readAsBytes();

    await _client.storage
        .from('posts')
        .uploadBinary(storagePath, bytes, fileOptions: const FileOptions(
          contentType: 'image/jpeg',
        ));

    return _client.storage.from('posts').getPublicUrl(storagePath);
  }

  /// 갤러리 이미지 여러장을 하나의 게시글로 등록
  Future<void> createGalleryPost(String oreumId, List<String> imageUrls) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');
    if (imageUrls.isEmpty) return;

    await _client.from('posts').insert({
      'user_id': userId,
      'oreum_id': oreumId,
      'content': '📷 갤러리 사진',
      'category': 'gallery',
      'images': imageUrls,
    });
  }

  // 갤러리 사진 삭제 (본인 사진만)
  Future<void> deleteGalleryImage(String imageUrl) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    // 해당 이미지가 포함된 게시글 찾기
    final posts = await _client
        .from('posts')
        .select('id, user_id, images')
        .eq('user_id', userId)
        .eq('category', 'gallery')
        .contains('images', [imageUrl]);

    if ((posts as List).isEmpty) {
      throw Exception('삭제할 수 없는 사진입니다');
    }

    final post = posts.first;

    // 게시글 삭제
    await _client.from('posts').delete().eq('id', post['id']);

    // Storage에서 파일 삭제 시도
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final storagePath = pathSegments.sublist(pathSegments.indexOf('posts') + 1).join('/');
      await _client.storage.from('posts').remove([storagePath]);
    } catch (e) {
      print('Storage delete error (ignored): $e');
    }
  }

  // 갤러리 사진 신고
  Future<void> reportGalleryImage(String imageUrl, String reason) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    try {
      await _client.from('reports').insert({
        'reporter_id': userId,
        'content_type': 'gallery_image',
        'content_url': imageUrl,
        'reason': reason,
      });
    } catch (e) {
      // reports 테이블이 없으면 posts에 신고 내용 저장
      print('Reports table error, using alternative: $e');
      await _client.from('posts').insert({
        'user_id': userId,
        'content': '🚨 신고: $reason\n이미지: $imageUrl',
        'category': 'report',
      });
    }
  }

  // 커뮤니티 이미지 상세 정보 (삭제/신고용)
  Future<Map<String, dynamic>?> getImagePostInfo(String imageUrl) async {
    try {
      final posts = await _client
          .from('posts')
          .select('id, user_id, oreum_id')
          .contains('images', [imageUrl])
          .limit(1);

      if ((posts as List).isNotEmpty) {
        return posts.first;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 갤러리 출처 가져오기
  Future<String?> getGallerySource(String oreumId) async {
    try {
      final response = await _client
          .from('oreum_images')
          .select('image_source')
          .eq('oreum_id', oreumId)
          .limit(1);

      if ((response as List).isNotEmpty && response[0]['image_source'] != null) {
        return response[0]['image_source'] as String;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
