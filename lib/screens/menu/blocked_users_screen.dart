import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/block_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final BlockService _blockService = BlockService();
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);
    try {
      _blockedUsers = await _blockService.getBlockedUsers();
    } catch (e) {
      debugPrint('차단 목록 로드 에러: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unblockUser(String blockedUserId, String nickname) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('차단 해제'),
        content: Text('$nickname 님의 차단을 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('해제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _blockService.unblockUser(blockedUserId);
        await _loadBlockedUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$nickname 님의 차단이 해제되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('차단 해제에 실패했습니다')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('차단 관리'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.block,
                        size: 64,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '차단된 사용자가 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blockedUsers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _blockedUsers[index];
                    final blocked = item['blocked'] as Map<String, dynamic>?;
                    final nickname = blocked?['nickname'] ?? '알 수 없음';
                    final profileImage = blocked?['profile_image'] as String?;
                    final blockedId = blocked?['id'] as String? ?? item['blocked_id'] as String;
                    final createdAt = DateTime.tryParse(item['created_at'] ?? '');

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surface,
                        backgroundImage:
                            profileImage != null ? NetworkImage(profileImage) : null,
                        child: profileImage == null
                            ? const Icon(Icons.person, color: AppColors.textSecondary)
                            : null,
                      ),
                      title: Text(
                        nickname,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: createdAt != null
                          ? Text(
                              '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')} 차단',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textHint,
                              ),
                            )
                          : null,
                      trailing: OutlinedButton(
                        onPressed: () => _unblockUser(blockedId, nickname),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('해제'),
                      ),
                    );
                  },
                ),
    );
  }
}
