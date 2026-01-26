import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/oreum_provider.dart';
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
  List<OreumModel> _filteredOreums = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final oreums = context.read<OreumProvider>().oreums;
      setState(() {
        _filteredOreums = oreums;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterOreums() {
    final provider = context.read<OreumProvider>();
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredOreums = provider.oreums.where((oreum) {
        final matchesQuery = query.isEmpty ||
            oreum.name.toLowerCase().contains(query) ||
            (oreum.trailName?.toLowerCase().contains(query) ?? false);

        final matchesDifficulty = _selectedDifficulty == null ||
            oreum.difficulty == _selectedDifficulty;

        return matchesQuery && matchesDifficulty;
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
            // 뒤로 가기 시 필터 초기화
            context.read<OreumProvider>().clearFilters();
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: _buildOreumList()),
        ],
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
        ],
      ),
    );
  }

  Widget _buildOreumList() {
    if (_filteredOreums.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textHint),
            SizedBox(height: 16),
            Text(
              '검색 결과가 없습니다',
              style: TextStyle(color: AppColors.textSecondary),
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
    final isBookmarked = oreumProvider.isBookmarked(oreum.id);

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
                color: AppColors.surface,
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
                      if (oreum.timeUp != null)
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
