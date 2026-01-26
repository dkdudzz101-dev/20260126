import 'package:flutter/material.dart';
import '../models/oreum_model.dart';
import '../services/oreum_service.dart';
import '../services/bookmark_service.dart';

class OreumProvider extends ChangeNotifier {
  final OreumService _oreumService = OreumService();
  final BookmarkService _bookmarkService = BookmarkService();

  List<OreumModel> _allOreums = [];
  List<OreumModel> _oreums = [];
  List<OreumModel> _allOreumsForStamp = []; // 정상인증용 전체 오름 (비활성 포함)
  List<OreumModel> _bookmarkedOreums = [];
  Set<String> _bookmarkedIds = {};
  OreumModel? _selectedOreum;
  bool _isLoading = false;
  bool _isLoadingBookmarks = false;
  String? _error;
  String? _currentDifficultyFilter; // ignore: unused_field
  String? _currentCategoryFilter;

  List<OreumModel> get oreums => _oreums;
  String? get currentCategoryFilter => _currentCategoryFilter;
  List<OreumModel> get allOreums => _allOreums;
  List<OreumModel> get allOreumsForStamp => _allOreumsForStamp; // 정상인증용 전체 오름
  List<OreumModel> get betaOreums => _allOreumsForStamp.where((o) => o.isBeta).toList(); // 베타 오름
  List<OreumModel> get bookmarkedOreums => _bookmarkedOreums;
  OreumModel? get selectedOreum => _selectedOreum;
  bool get isLoading => _isLoading;
  bool get isLoadingBookmarks => _isLoadingBookmarks;
  String? get error => _error;

  // 오름 목록 로드
  Future<void> loadOreums() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 활성화된 오름만 로드 (일반 표시용)
      _allOreums = await _oreumService.getAllOreums();
      _allOreums.sort((a, b) => a.name.compareTo(b.name));
      _oreums = _allOreums;

      // 정상인증용 전체 오름 로드 (비활성 포함)
      _allOreumsForStamp = await _oreumService.getAllOreumsIncludingInactive();
      _allOreumsForStamp.sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 난이도 필터 적용
  void filterByDifficulty(String? difficulty) {
    _currentDifficultyFilter = difficulty;
    if (difficulty == null) {
      _oreums = _allOreums;
    } else {
      _oreums = _allOreums.where((o) => o.difficulty == difficulty).toList();
    }
    notifyListeners();
  }

  // 카테고리 필터 적용 (기존 방식 - 사용 안 함)
  void filterByCategory(String? category) {
    _currentCategoryFilter = category;
    if (category == null || category.isEmpty) {
      _oreums = _allOreums;
    } else {
      _oreums = _allOreums.where((o) => o.categories.contains(category)).toList();
    }
    notifyListeners();
  }

  // 테마별 오름 필터 적용 (oreum_themes 매핑 테이블 사용)
  Future<void> filterByTheme(String themeKey) async {
    _currentCategoryFilter = themeKey;
    _isLoading = true;
    notifyListeners();

    try {
      final themeOreums = await _oreumService.getOreumsByTheme(themeKey);
      _oreums = themeOreums;
    } catch (e) {
      debugPrint('테마별 오름 로드 에러: $e');
      _oreums = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 필터 초기화
  void clearFilters() {
    _currentDifficultyFilter = null;
    _currentCategoryFilter = null;
    _oreums = _allOreums;
    notifyListeners();
  }

  // 오름 선택
  void selectOreum(OreumModel oreum) {
    _selectedOreum = oreum;
    notifyListeners();
  }

  // 오름 선택 해제
  void clearSelectedOreum() {
    _selectedOreum = null;
    notifyListeners();
  }

  // 카테고리별 필터
  List<OreumModel> getOreumsByCategory(String category) {
    return _oreums.where((o) => o.categories.contains(category)).toList();
  }

  // 난이도별 필터
  List<OreumModel> getOreumsByDifficulty(String difficulty) {
    return _oreums.where((o) => o.difficulty == difficulty).toList();
  }

  // 검색
  List<OreumModel> searchOreums(String query) {
    if (query.isEmpty) return _oreums;
    return _oreums
        .where((o) => o.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // 북마크 목록 로드 (Supabase에서)
  Future<void> loadBookmarks() async {
    _isLoadingBookmarks = true;
    notifyListeners();

    try {
      final bookmarkData = await _bookmarkService.getBookmarks();
      _bookmarkedIds.clear();
      _bookmarkedOreums.clear();

      for (final bookmark in bookmarkData) {
        final oreumData = bookmark['oreums'] as Map<String, dynamic>?;
        if (oreumData != null) {
          final oreum = OreumModel.fromJson(oreumData);
          _bookmarkedOreums.add(oreum);
          _bookmarkedIds.add(oreum.id);
        }
      }
    } catch (e) {
      debugPrint('북마크 로드 에러: $e');
    } finally {
      _isLoadingBookmarks = false;
      notifyListeners();
    }
  }

  // 북마크 토글 (Supabase 연동)
  Future<bool> toggleBookmark(OreumModel oreum) async {
    try {
      final isNowBookmarked = await _bookmarkService.toggleBookmark(oreum.id);

      if (isNowBookmarked) {
        _bookmarkedOreums.add(oreum);
        _bookmarkedIds.add(oreum.id);
      } else {
        _bookmarkedOreums.removeWhere((o) => o.id == oreum.id);
        _bookmarkedIds.remove(oreum.id);
      }
      notifyListeners();
      return isNowBookmarked;
    } catch (e) {
      debugPrint('북마크 토글 에러: $e');
      // 로그인 안 된 경우 로컬에서만 처리
      if (_bookmarkedIds.contains(oreum.id)) {
        _bookmarkedOreums.removeWhere((o) => o.id == oreum.id);
        _bookmarkedIds.remove(oreum.id);
        notifyListeners();
        return false;
      } else {
        _bookmarkedOreums.add(oreum);
        _bookmarkedIds.add(oreum.id);
        notifyListeners();
        return true;
      }
    }
  }

  // 북마크 여부 확인
  bool isBookmarked(String oreumId) {
    return _bookmarkedIds.contains(oreumId);
  }

  // 북마크된 오름만 필터
  List<OreumModel> getBookmarkedOreums() {
    return _allOreums.where((o) => _bookmarkedIds.contains(o.id)).toList();
  }
}
