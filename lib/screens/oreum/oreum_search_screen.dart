import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/oreum_provider.dart';
import '../../providers/stamp_provider.dart';
import '../../models/oreum_model.dart';
import 'oreum_detail_screen.dart';

class OreumSearchScreen extends StatefulWidget {
  final String? initialTitle;

  const OreumSearchScreen({super.key, this.initialTitle});

  @override
  State<OreumSearchScreen> createState() => _OreumSearchScreenState();
}

class _OreumSearchScreenState extends State<OreumSearchScreen> {
  final _searchController = TextEditingController();
  String? _selectedDifficulty;
  String? _selectedTrailStatus; // 'verified' or 'checking'
  int _selectedTab = 0; // 0: 인증된 오름, 1: 미인증 오름
  List<OreumModel> _filteredOreums = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _filterOreums();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OreumModel> _getBaseList() {
    final oreumProvider = context.read<OreumProvider>();
    final stampProvider = context.read<StampProvider>();

    switch (_selectedTab) {
      case 0: // 인증된 오름
        return oreumProvider.allOreumsForStamp
            .where((o) => stampProvider.hasStamp(o.id))
            .toList();
      case 1: // 미인증 오름
        return oreumProvider.allOreumsForStamp
            .where((o) => !stampProvider.hasStamp(o.id))
            .toList();
      default:
        return oreumProvider.allOreumsForStamp;
    }
  }

  void _filterOreums() {
    final query = _searchController.text.toLowerCase();
    final baseList = _getBaseList();

    setState(() {
      _filteredOreums = baseList.where((oreum) {
        final matchesQuery = query.isEmpty ||
            oreum.name.toLowerCase().contains(query) ||
            (oreum.trailName?.toLowerCase().contains(query) ?? false);

        final matchesDifficulty = _selectedDifficulty == null ||
            oreum.difficulty == _selectedDifficulty;

        final matchesTrailStatus = _selectedTrailStatus == null ||
            (oreum.trailStatus ?? 'checking') == _selectedTrailStatus;

        return matchesQuery && matchesDifficulty && matchesTrailStatus;
      }).toList();
    });
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
          _buildTabSelector(),
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: _buildOreumList()),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    final stampProvider = context.watch<StampProvider>();
    final oreumProvider = context.watch<OreumProvider>();
    final stampedCount = oreumProvider.allOreumsForStamp
        .where((o) => stampProvider.hasStamp(o.id))
        .length;
    final unstampedCount = oreumProvider.allOreumsForStamp
        .where((o) => !stampProvider.hasStamp(o.id))
        .length;

    final tabs = [
      {'label': '인증된 오름', 'count': stampedCount},
      {'label': '미인증 오름', 'count': unstampedCount},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = index;
                });
                _filterOreums();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      tabs[index]['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tabs[index]['count']}개',
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.white70 : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
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

  Widget _buildFilterChips() {
    final difficulties = ['쉬움', '보통', '어려움'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          FilterChip(
            label: const Text('전체'),
            selected: _selectedDifficulty == null,
            onSelected: (selected) {
              setState(() {
                _selectedDifficulty = null;
              });
              _filterOreums();
            },
          ),
          const SizedBox(width: 8),
          ...difficulties.map((difficulty) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(difficulty),
                selected: _selectedDifficulty == difficulty,
                onSelected: (selected) {
                  setState(() {
                    _selectedDifficulty = selected ? difficulty : null;
                  });
                  _filterOreums();
                },
              ),
            );
          }),
          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: Colors.grey.shade300),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('확인됨'),
            selected: _selectedTrailStatus == 'verified',
            selectedColor: Colors.green.shade100,
            onSelected: (selected) {
              setState(() {
                _selectedTrailStatus = selected ? 'verified' : null;
              });
              _filterOreums();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('미확인'),
            selected: _selectedTrailStatus == 'checking',
            selectedColor: Colors.orange.shade100,
            onSelected: (selected) {
              setState(() {
                _selectedTrailStatus = selected ? 'checking' : null;
              });
              _filterOreums();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOreumList() {
    if (_filteredOreums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedTab == 0 ? Icons.verified_outlined : Icons.search_off,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedTab == 0 ? '아직 인증된 오름이 없습니다' : '모든 오름이 인증되었습니다',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredOreums.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final oreum = _filteredOreums[index];
        return _buildOreumCard(oreum);
      },
    );
  }

  Widget _buildOreumCard(OreumModel oreum) {
    final oreumProvider = context.watch<OreumProvider>();
    final stampProvider = context.watch<StampProvider>();
    final isBookmarked = oreumProvider.isBookmarked(oreum.id);
    final isStamped = stampProvider.hasStamp(oreum.id);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OreumDetailScreen(oreum: oreum),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                          Icons.terrain,
                          color: AppColors.textHint,
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
                  Text(
                    oreum.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (oreum.difficulty != null) ...[
                        _buildDifficultyBadge(oreum.difficulty!),
                        const SizedBox(width: 8),
                      ],
                      _buildTrailStatusBadge(oreum.trailStatus ?? 'checking'),
                      const SizedBox(width: 8),
                      if (oreum.timeUp != null && oreum.timeUp! > 0)
                        Text(
                          '${oreum.timeUp}분',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (isStamped)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.verified, color: Colors.green, size: 20),
              ),
            if (isBookmarked)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.star, color: Colors.amber, size: 20),
              ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailStatusBadge(String status) {
    final isVerified = status == 'verified';
    final color = isVerified ? Colors.green : Colors.orange;
    final label = isVerified ? '확인됨' : '미확인';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty) {
    Color color;
    switch (difficulty) {
      case '쉬움':
        color = AppColors.difficultyEasy;
        break;
      case '보통':
        color = AppColors.difficultyMedium;
        break;
      case '어려움':
        color = AppColors.difficultyHard;
        break;
      default:
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
