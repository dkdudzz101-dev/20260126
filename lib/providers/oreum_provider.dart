import 'package:flutter/material.dart';
import '../models/oreum_model.dart';
import '../services/oreum_service.dart';
import '../services/bookmark_service.dart';
import '../services/offline_service.dart';

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

  // Cache control
  DateTime? _lastLoadTime;
  static const Duration _cacheTtl = Duration(minutes: 10);

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
  Future<void> loadOreums({bool force = false}) async {
    // Return early if cache is fresh and not forced
    if (!force &&
        _lastLoadTime != null &&
        _allOreumsForStamp.isNotEmpty &&
        DateTime.now().difference(_lastLoadTime!) < _cacheTtl) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 전체 오름 1회 로드 (비활성 포함), 활성 오름은 클라이언트에서 필터링
      _allOreumsForStamp = await _oreumService.getAllOreumsIncludingInactive();
      _allOreumsForStamp.sort((a, b) => a.name.compareTo(b.name));

      _allOreums = _allOreumsForStamp.where((o) => o.isActive).toList();
      _oreums = _allOreums;

      _lastLoadTime = DateTime.now();
    } catch (e) {
      _error = e.toString();

      // 네트워크 실패 시 오프라인 데이터 폴백
      if (_allOreums.isEmpty) {
        try {
          final offlineService = OfflineService();
          final offlineData = await offlineService.getOfflineOreums();
          if (offlineData.isNotEmpty) {
            _allOreums = offlineData.map((d) => OreumModel.fromJson(d)).toList();
            _allOreums.sort((a, b) => a.name.compareTo(b.name));
            _oreums = _allOreums;
            _error = null; // 오프라인 데이터로 복구 성공
          }
        } catch (_) {}
      }
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
        final oreumId = bookmark['oreum_id'] as String?;
        if (oreumId != null) {
          _bookmarkedIds.add(oreumId);
          final oreum = _oreums.firstWhere(
            (o) => o.id == oreumId,
            orElse: () => OreumModel(id: oreumId, name: ''),
          );
          if (oreum.name.isNotEmpty) _bookmarkedOreums.add(oreum);
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
