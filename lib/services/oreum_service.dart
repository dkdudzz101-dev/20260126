import 'package:supabase_flutter/supabase_flutter.dart';
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
}
