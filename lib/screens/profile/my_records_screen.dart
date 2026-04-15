import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/stamp_provider.dart';
import 'hiking_detail_screen.dart';

class MyRecordsScreen extends StatefulWidget {
  const MyRecordsScreen({super.key});

  @override
  State<MyRecordsScreen> createState() => _MyRecordsScreenState();
}

class _MyRecordsScreenState extends State<MyRecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stampProvider = context.watch<StampProvider>();
    final stamps = stampProvider.stamps;

    final filtered = _searchQuery.isEmpty
        ? stamps
        : stamps
            .where((s) =>
                s.oreumName.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('내 기록 (${stamps.length})'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: '오름 이름 검색',
                prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textHint),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _searchQuery.isEmpty ? Icons.hiking : Icons.search_off,
                          size: 48,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? '아직 등반 기록이 없습니다'
                              : '검색 결과가 없습니다',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final stamp = filtered[index];
                      final date = stamp.stampedAt;
                      final dateStr =
                          '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

                      return InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HikingDetailScreen(stamp: stamp),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: stamp.imageUrl != null
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Image.network(
                                              stamp.imageUrl!,
                                              fit: BoxFit.cover,
                                              width: 44,
                                              height: 44,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.terrain,
                                                      color: AppColors.primary,
                                                      size: 24),
                                            ),
                                          )
                                        : const Icon(Icons.terrain,
                                            color: AppColors.primary, size: 24),
                                  ),
                                  if (stampProvider.getVisitCount(stamp.oreumId) > 1)
                                    Positioned(
                                      top: -2,
                                      right: -2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(7),
                                        ),
                                        child: Text(
                                          'x${stampProvider.getVisitCount(stamp.oreumId)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stamp.oreumName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateStr +
                                          (stamp.distanceWalked != null
                                              ? ' · ${(stamp.distanceWalked! / 1000).toStringAsFixed(1)}km'
                                              : ''),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('기록 삭제'),
                                      content: Text(
                                        stamp.isStamp
                                            ? '${stamp.oreumName} 기록을 목록에서 삭제할까요?\n(스탬프 뱃지는 유지됩니다)'
                                            : '${stamp.oreumName} 등반 기록을 삭제할까요?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('취소'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('삭제',
                                              style: TextStyle(
                                                  color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && context.mounted) {
                                    if (stamp.isStamp) {
                                      await context
                                          .read<StampProvider>()
                                          .hideStampRecord(stamp.id);
                                    } else {
                                      await context
                                          .read<StampProvider>()
                                          .deleteHikingLog(stamp.id);
                                    }
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.delete_outline,
                                      color: Colors.red, size: 20),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: AppColors.textHint,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
