import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/ranking_service.dart';
import '../../config/supabase_config.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  List<RankingUser> _rankings = [];
  bool _isLoading = true;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = SupabaseConfig.client.auth.currentUser?.id;
    _loadRanking();
  }

  Future<void> _loadRanking() async {
    setState(() => _isLoading = true);
    final rankings = await RankingService.getRanking(limit: 100);
    if (mounted) {
      setState(() {
        _rankings = rankings;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('랭킹'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRanking,
              child: _rankings.isEmpty
                  ? const Center(child: Text('아직 랭킹 데이터가 없습니다'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rankings.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildTop3();
                        final user = _rankings[index - 1];
                        if (user.rank <= 3) return const SizedBox.shrink();
                        return _buildRankItem(user);
                      },
                    ),
            ),
    );
  }

  Widget _buildTop3() {
    final top3 = _rankings.where((u) => u.rank <= 3).toList();
    if (top3.isEmpty) return const SizedBox.shrink();

    RankingUser? first = top3.where((u) => u.rank == 1).firstOrNull;
    RankingUser? second = top3.where((u) => u.rank == 2).firstOrNull;
    RankingUser? third = top3.where((u) => u.rank == 3).firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('TOP 3', style: TextStyle(
            color: Color(0xFFD4A853), fontSize: 13, fontWeight: FontWeight.w700,
            letterSpacing: 3,
          )),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (second != null) _buildTopUser(second, 64, const Color(0xFFA8A8A8), 80),
              if (first != null) _buildTopUser(first, 80, const Color(0xFFD4A853), 100),
              if (third != null) _buildTopUser(third, 56, const Color(0xFFB87333), 65),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopUser(RankingUser user, double avatarSize, Color accentColor, double podiumHeight) {
    final isMe = user.userId == _myUserId;
    final initial = user.nickname.isNotEmpty ? user.nickname[0].toUpperCase() : '?';

    return SizedBox(
      width: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${user.rank}',
                style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accentColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: user.profileImage != null
                  ? Image.network(
                      user.profileImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF3A3A3A),
                        child: Center(child: Text(initial, style: TextStyle(
                          fontSize: avatarSize * 0.35, fontWeight: FontWeight.bold, color: accentColor,
                        ))),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF3A3A3A),
                      child: Center(child: Text(initial, style: TextStyle(
                        fontSize: avatarSize * 0.35, fontWeight: FontWeight.bold, color: accentColor,
                      ))),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isMe ? '${user.nickname} (나)' : user.nickname,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isMe ? accentColor : Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Lv.${user.level}',
              style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${user.stampCount}개 완등',
            style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildRankItem(RankingUser user) {
    final isMe = user.userId == _myUserId;
    final initial = user.nickname.isNotEmpty ? user.nickname[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFFEEEEEE),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${user.rank}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isMe ? AppColors.primary : AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
            ),
            child: ClipOval(
              child: user.profileImage != null
                  ? Image.network(
                      user.profileImage!,
                      fit: BoxFit.cover,
                      width: 42,
                      height: 42,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.primary,
                        child: Center(child: Text(initial, style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
                        ))),
                      ),
                    )
                  : Container(
                      color: AppColors.primary,
                      child: Center(child: Text(initial, style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
                      ))),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${user.nickname} (나)' : user.nickname,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                    color: isMe ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${user.stampCount}개 완등',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Lv.${user.level}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isMe ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
