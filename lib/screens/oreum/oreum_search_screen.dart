import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import '../../providers/oreum_provider.dart';
import '../../providers/stamp_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/oreum_model.dart';
import '../../services/inquiry_service.dart';
import '../../utils/login_guard.dart';
import 'oreum_detail_screen.dart';

class OreumSearchScreen extends StatefulWidget {
  final String? initialTitle;

  const OreumSearchScreen({super.key, this.initialTitle});

  @override
  State<OreumSearchScreen> createState() => _OreumSearchScreenState();
}

class _OreumSearchScreenState extends State<OreumSearchScreen> {
  final _searchController = TextEditingController();
  String _stampFilter = '전체'; // 전체, 인증, 미인증
  String? _selectedDifficulty;
  String? _selectedTrailStatus;
  String _sortBy = '이름순'; // 이름순, 거리순, 난이도순
  List<OreumModel> _filteredOreums = [];
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryLoadPosition();
      _filterOreums();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _tryLoadPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _currentPosition = pos);
    } catch (_) {}
  }

  double? _distanceTo(OreumModel oreum) {
    if (_currentPosition == null) return null;
    final lat = oreum.startLat ?? oreum.summitLat;
    final lng = oreum.startLng ?? oreum.summitLng;
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude, _currentPosition!.longitude, lat, lng,
    );
  }

  int _difficultyOrder(String? d) {
    switch (d) {
      case '쉬움': return 0;
      case '보통': return 1;
      case '어려움': return 2;
      default: return 3;
    }
  }

  void _filterOreums() {
    final oreumProvider = context.read<OreumProvider>();
    final stampProvider = context.read<StampProvider>();
    final query = _searchController.text.toLowerCase();

    // 테마 필터가 적용된 경우 oreums(필터된 목록), 아니면 전체 목록 사용
    final baseList = oreumProvider.currentCategoryFilter != null
        ? oreumProvider.oreums
        : oreumProvider.allOreumsForStamp;

    var list = baseList.where((oreum) {
      // 검색어
      final matchesQuery = query.isEmpty ||
          oreum.name.toLowerCase().contains(query) ||
          (oreum.trailName?.toLowerCase().contains(query) ?? false);

      // 인증 필터
      final isStamped = stampProvider.hasStamp(oreum.id);
      final isAnyCertified = stampProvider.isAnyCertified(oreum.id);
      final matchesStamp = _stampFilter == '전체' ||
          (_stampFilter == '내 인증' && isStamped) ||
          (_stampFilter == '내 미인증' && !isStamped) ||
          (_stampFilter == '누군가 인증' && isAnyCertified) ||
          (_stampFilter == '아무도 미인증' && !isAnyCertified);

      // 난이도
      final matchesDifficulty = _selectedDifficulty == null ||
          oreum.difficulty == _selectedDifficulty;

      // 등산로 정보 (geojson 유무 기준)
      final hasTrailData = oreum.geojsonPath != null && oreum.geojsonPath!.isNotEmpty;
      final matchesTrailStatus = _selectedTrailStatus == null ||
          (_selectedTrailStatus == 'verified' && hasTrailData) ||
          (_selectedTrailStatus == 'checking' && !hasTrailData);

      return matchesQuery && matchesStamp && matchesDifficulty && matchesTrailStatus;
    }).toList();

    // 정렬
    switch (_sortBy) {
      case '이름순':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case '거리순':
        if (_currentPosition != null) {
          list.sort((a, b) {
            final da = _distanceTo(a);
            final db = _distanceTo(b);
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
        }
        break;
      case '난이도순':
        list.sort((a, b) => _difficultyOrder(a.difficulty).compareTo(_difficultyOrder(b.difficulty)));
        break;
    }

    setState(() => _filteredOreums = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialTitle ?? '오름 검색'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.read<OreumProvider>().clearFilters();
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilters(),
          _buildResultCount(),
          Expanded(child: _buildOreumList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _filterOreums(),
        decoration: InputDecoration(
          hintText: '오름 이름으로 검색',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterOreums();
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          // 1행: 정렬
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    isDense: true,
                    icon: const Icon(Icons.sort, size: 16),
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    items: ['이름순', '거리순', '난이도순'].map((s) =>
                      DropdownMenuItem(value: s, child: Text(s)),
                    ).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      if (val == '거리순' && _currentPosition == null) {
                        _tryLoadPosition().then((_) {
                          setState(() => _sortBy = val);
                          _filterOreums();
                        });
                        return;
                      }
                      setState(() => _sortBy = val);
                      _filterOreums();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 2행: 인증 + 난이도 + 등산로 상태
          Row(
            children: [
              _buildDropdownChip(
                label: '인증',
                value: _stampFilter == '전체' ? null : _stampFilter,
                items: ['내 인증', '내 미인증', '누군가 인증', '아무도 미인증'],
                colorMap: {
                  '내 인증': Colors.green,
                  '내 미인증': Colors.orange,
                  '누군가 인증': Colors.blue,
                  '아무도 미인증': Colors.grey,
                },
                onChanged: (val) {
                  setState(() => _stampFilter = val ?? '전체');
                  _filterOreums();
                },
              ),
              const SizedBox(width: 8),
              _buildDropdownChip(
                label: '난이도',
                value: _selectedDifficulty,
                items: ['쉬움', '보통', '어려움'],
                colorMap: {
                  '쉬움': AppColors.difficultyEasy,
                  '보통': AppColors.difficultyMedium,
                  '어려움': AppColors.difficultyHard,
                },
                onChanged: (val) {
                  setState(() => _selectedDifficulty = val);
                  _filterOreums();
                },
              ),
              const SizedBox(width: 8),
              _buildDropdownChip(
                label: '등산로',
                value: _selectedTrailStatus == 'verified' ? '정보 있음' : _selectedTrailStatus == 'checking' ? '정보 없음' : null,
                items: ['정보 있음', '정보 없음'],
                colorMap: {
                  '정보 있음': Colors.green,
                  '정보 없음': Colors.orange,
                },
                onChanged: (val) {
                  setState(() {
                    if (val == '정보 있음') _selectedTrailStatus = 'verified';
                    else if (val == '정보 없음') _selectedTrailStatus = 'checking';
                    else _selectedTrailStatus = null;
                  });
                  _filterOreums();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownChip({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    Map<String, Color>? colorMap,
  }) {
    final isActive = value != null;
    final activeColor = (isActive && colorMap != null) ? colorMap[value] ?? AppColors.primary : AppColors.primary;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          if (isActive)
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                onChanged(null);
                              },
                              child: const Text('초기화', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                        ],
                      ),
                    ),
                    ...items.map((item) {
                      final selected = value == item;
                      final itemColor = colorMap?[item] ?? AppColors.primary;
                      return ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: itemColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(item),
                        trailing: selected ? Icon(Icons.check, color: itemColor) : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          onChanged(selected ? null : item);
                        },
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? activeColor : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive ? '$label: $value' : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? activeColor : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isActive ? activeColor : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChipGroup(List<String> items, String selected, Function(String) onTap) {
    return items.map((item) {
      final isSelected = selected == item;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onTap: () => onTap(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildResultCount() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        '${_filteredOreums.length}개',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildOreumList() {
    if (_filteredOreums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text(
              '조건에 맞는 오름이 없습니다',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _showOreumRequestDialog,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_location_alt_outlined, size: 14, color: AppColors.textHint),
                  SizedBox(width: 4),
                  Text(
                    '찾는 오름이 없나요? 추가 요청하기',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredOreums.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final oreum = _filteredOreums[index];
        return _buildOreumCard(oreum);
      },
    );
  }

  void _showOreumRequestDialog() {
    if (!LoginGuard.check(context, message: '오름 추가 요청은 로그인이 필요합니다.\n로그인 하시겠습니까?')) return;

    final nameController = TextEditingController();
    final locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오름 추가 요청', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '목록에 없는 오름 정보를 알려주시면\n검토 후 추가하겠습니다.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '오름 이름',
                hintText: '예: ○○오름',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: '위치 정보 (선택)',
                hintText: '예: 서귀포시 ○○리 근처',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('오름 이름을 입력해주세요')),
                );
                return;
              }
              try {
                await InquiryService().createInquiry(
                  category: 'oreum_request',
                  email: '',
                  title: '오름 추가 요청: $name',
                  content: '오름 이름: $name\n위치: ${locationController.text.trim()}',
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('오름 추가 요청이 접수되었습니다')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('요청 전송에 실패했습니다')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('요청하기'),
          ),
        ],
      ),
    );
  }

  Widget _buildOreumCard(OreumModel oreum) {
    final oreumProvider = context.watch<OreumProvider>();
    final stampProvider = context.watch<StampProvider>();
    final isBookmarked = oreumProvider.isBookmarked(oreum.id);
    final isStamped = stampProvider.hasStamp(oreum.id);
    final dist = _distanceTo(oreum);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OreumDetailScreen(oreum: oreum)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: oreum.stampUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        oreum.stampUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.terrain, color: AppColors.textHint,
                        ),
                      ),
                    )
                  : const Icon(Icons.terrain, color: AppColors.textHint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          oreum.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isStamped)
                        const Icon(Icons.verified, color: Colors.green, size: 18),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (oreum.difficulty != null)
                        _buildBadge(oreum.difficulty!, _difficultyColor(oreum.difficulty!)),
                      _buildBadge(
                        (oreum.geojsonPath != null && oreum.geojsonPath!.isNotEmpty) ? '정보 있음' : '정보 없음',
                        (oreum.geojsonPath != null && oreum.geojsonPath!.isNotEmpty) ? Colors.green : Colors.orange,
                      ),
                      if (oreum.restriction != null && oreum.restriction!.isNotEmpty)
                        _buildBadge(oreum.restriction!, const Color(0xFFB71C1C)),
                    ],
                  ),
                  if (dist != null || (oreum.timeUp != null && oreum.timeUp! > 0)) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (dist != null)
                          Text(
                            dist < 1000
                                ? '${dist.toInt()}m'
                                : '${(dist / 1000).toStringAsFixed(1)}km',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        if (dist != null && oreum.timeUp != null && oreum.timeUp! > 0)
                          const Text(' · ', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                        if (oreum.timeUp != null && oreum.timeUp! > 0)
                          Text(
                            '등반 ${oreum.timeUp}분',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isBookmarked)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.favorite, color: Colors.red, size: 18),
              ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case '쉬움': return AppColors.difficultyEasy;
      case '보통': return AppColors.difficultyMedium;
      case '어려움': return AppColors.difficultyHard;
      default: return AppColors.textSecondary;
    }
  }
}
