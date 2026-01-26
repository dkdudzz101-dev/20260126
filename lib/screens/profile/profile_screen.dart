import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/stamp_provider.dart';
import '../../providers/oreum_provider.dart';
import '../../providers/badge_provider.dart';
import '../../models/badge_model.dart';
import '../../services/background_location_service.dart';
import '../auth/login_screen.dart';
import 'hiking_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isBackgroundServiceRunning = false;

  @override
  void initState() {
    super.initState();
    _checkBackgroundService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBadges();
    });
  }

  Future<void> _checkBackgroundService() async {
    final isRunning = await BackgroundLocationService.isRunning();
    if (mounted) {
      setState(() {
        _isBackgroundServiceRunning = isRunning;
      });
    }
  }

  Future<void> _pickAndUploadImage(BuildContext dialogContext, Function setModalState) async {
    final authProvider = dialogContext.read<AuthProvider>();

    // 이미지 소스 선택
    final source = await showModalBottomSheet<ImageSource>(
      context: dialogContext,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      // 로딩 표시
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(content: Text('이미지 업로드 중...')),
        );
      }

      // Supabase Storage에 업로드
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) return;

      final fileName = 'profile_$userId.jpg';
      final bytes = await image.readAsBytes();

      await SupabaseConfig.client.storage
          .from('profiles')
          .uploadBinary(fileName, bytes, fileOptions: FileOptions(upsert: true));

      // Public URL 가져오기
      final imageUrl = SupabaseConfig.client.storage
          .from('profiles')
          .getPublicUrl(fileName);

      // 프로필 업데이트
      await authProvider.updateProfile(profileImage: imageUrl);

      if (dialogContext.mounted) {
        setModalState(() {});
        ScaffoldMessenger.of(dialogContext).hideCurrentSnackBar();
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(content: Text('프로필 이미지가 변경되었습니다')),
        );
      }
    } catch (e) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).hideCurrentSnackBar();
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(content: Text('이미지 업로드 실패: $e')),
        );
      }
    }
  }

  Future<void> _loadBadges() async {
    final badgeProvider = context.read<BadgeProvider>();
    final authProvider = context.read<AuthProvider>();

    await badgeProvider.loadAllBadges();

    if (authProvider.isLoggedIn && authProvider.userId != null) {
      await badgeProvider.loadUserBadges(authProvider.userId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('마이오름'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProfileCard(context),
          const SizedBox(height: 16),
          _buildStatsBar(context),
          const SizedBox(height: 16),
          _buildBadgeSection(context),
          const SizedBox(height: 16),
          _buildMyRecords(context),
          const SizedBox(height: 16),
          _buildMenuSection(context),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final stampProvider = context.watch<StampProvider>();
    final level = (stampProvider.stampCount ~/ 10) + 1;

    // 로그인 안했을 때
    if (!authProvider.isLoggedIn) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.surface,
              child: const Icon(Icons.person_outline, size: 24, color: AppColors.textHint),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '로그인이 필요합니다',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('로그인'),
            ),
          ],
        ),
      );
    }

    // 로그인 했을 때
    final nickname = authProvider.nickname ?? '탐험가';
    final profileImage = authProvider.profileImage;
    final initial = nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _showEditProfile(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary,
              backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
              child: profileImage == null
                  ? Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '탭하여 프로필 편집',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Lv.$level',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  static const int totalOreumCount = 368;

  Widget _buildStatsBar(BuildContext context) {
    final stampProvider = context.watch<StampProvider>();
    final stampCount = stampProvider.stampCount;

    // 실제 데이터 사용 (km 단위로 변환)
    final totalDistanceKm = (stampProvider.totalDistance / 1000).toStringAsFixed(1);
    final totalStepsFormatted = stampProvider.totalSteps.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem('$stampCount/$totalOreumCount', '완등 오름'),
          ),
          Container(width: 1, height: 40, color: AppColors.border),
          Expanded(
            child: _buildStatItem('${totalDistanceKm}km', '총 이동거리'),
          ),
          Container(width: 1, height: 40, color: AppColors.border),
          Expanded(
            child: _buildStatItem(totalStepsFormatted, '총 걸음수'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeSection(BuildContext context) {
    final badgeProvider = context.watch<BadgeProvider>();
    final stampCount = context.watch<StampProvider>().stampCount;
    final allBadges = badgeProvider.allBadges;

    // completion 카테고리 뱃지만 필터링 (상위 8개)
    final completionBadges = allBadges
        .where((b) => b.category == 'completion')
        .take(8)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '나의 뱃지',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${badgeProvider.earnedCount}/${badgeProvider.totalCount} 획득',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _showAllBadges(context),
                child: const Text('전체보기'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (badgeProvider.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (completionBadges.isEmpty)
            const Text('뱃지를 불러오는 중...', style: TextStyle(color: AppColors.textSecondary))
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: completionBadges.map((badge) {
                final earned = _isBadgeEarned(badge, stampCount, badgeProvider);
                return _buildBadgeItem(badge, earned);
              }).toList(),
            ),
        ],
      ),
    );
  }

  bool _isBadgeEarned(BadgeModel badge, int stampCount, BadgeProvider badgeProvider) {
    // 사용자가 이미 획득한 경우
    if (badgeProvider.hasBadge(badge.id)) return true;

    // 조건 확인 (로컬 체크)
    if (badge.conditionType == 'oreum_count') {
      return stampCount >= (badge.conditionValue ?? 0);
    }
    return false;
  }

  Widget _buildBadgeItem(BadgeModel badge, bool earned) {
    final color = _getBadgeColor(badge.category ?? 'completion');

    return SizedBox(
      width: 60,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: earned ? color.withOpacity(0.15) : AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: earned
                  ? Text(badge.icon ?? '🏅', style: const TextStyle(fontSize: 24))
                  : const Icon(Icons.lock, color: AppColors.textHint, size: 20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge.name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: earned ? FontWeight.w600 : FontWeight.normal,
              color: earned ? color : AppColors.textHint,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _getBadgeColor(String category) {
    switch (category) {
      case 'completion':
        return Colors.amber;
      case 'time':
        return Colors.blue;
      case 'distance':
        return Colors.green;
      case 'streak':
        return Colors.orange;
      case 'community':
        return Colors.purple;
      case 'category':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMyRecords(BuildContext context) {
    final stampProvider = context.watch<StampProvider>();
    final stamps = stampProvider.stamps;

    // 최근 5개만 표시
    final recentStamps = stamps.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '내 기록',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (stamps.isNotEmpty)
                TextButton(
                  onPressed: () => _showHistory(context),
                  child: const Text('전체보기'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (stamps.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: const Column(
                children: [
                  Icon(Icons.hiking, size: 40, color: AppColors.textHint),
                  SizedBox(height: 8),
                  Text(
                    '아직 등반 기록이 없습니다',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentStamps.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final stamp = recentStamps[index];
                final date = stamp.stampedAt;
                final dateStr = '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HikingDetailScreen(stamp: stamp),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: stamp.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    stamp.imageUrl!,
                                    fit: BoxFit.cover,
                                    width: 44,
                                    height: 44,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.terrain, color: AppColors.primary, size: 24),
                                  ),
                                )
                              : const Icon(Icons.terrain, color: AppColors.primary, size: 24),
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
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
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
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.bookmark_outline,
            title: '저장한 오름',
            onTap: () => _showBookmarks(context),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: '도움말',
            onTap: () => _showHelp(context),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            icon: Icons.info_outline,
            title: '앱 정보',
            onTap: () => _showAppInfo(context),
          ),
          if (authProvider.isLoggedIn) ...[
            const Divider(height: 1),
            _buildMenuItem(
              icon: Icons.logout,
              title: '로그아웃',
              isDestructive: true,
              onTap: () => _logout(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '설정',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('알림 설정'),
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {},
                    activeColor: AppColors.primary,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('위치 권한'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('기기 설정에서 위치 권한을 관리할 수 있습니다')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.gps_fixed),
                  title: const Text('자동 스탬프 인증'),
                  subtitle: const Text('정상 200m 이내 지나가면 자동 인증'),
                  trailing: Switch(
                    value: _isBackgroundServiceRunning,
                    onChanged: (value) async {
                      if (value) {
                        await BackgroundLocationService.startService();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('백그라운드 스탬프 인증이 활성화되었습니다')),
                        );
                      } else {
                        await BackgroundLocationService.stopService();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('백그라운드 스탬프 인증이 비활성화되었습니다')),
                        );
                      }
                      setState(() {
                        _isBackgroundServiceRunning = value;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('다크 모드'),
                  trailing: Switch(
                    value: false,
                    onChanged: (value) {},
                    activeColor: AppColors.primary,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.monitor_weight_outlined),
                  title: const Text('체중 설정'),
                  subtitle: Text(
                    context.watch<AuthProvider>().weight != null
                        ? '${context.watch<AuthProvider>().weight!.toStringAsFixed(1)} kg'
                        : '설정되지 않음',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _showWeightDialog(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditProfile(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final nicknameController = TextEditingController(text: authProvider.nickname ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '프로필 편집',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 프로필 이미지
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.surface,
                          backgroundImage: authProvider.profileImage != null
                              ? NetworkImage(authProvider.profileImage!)
                              : null,
                          child: authProvider.profileImage == null
                              ? const Icon(Icons.person, size: 50, color: AppColors.textSecondary)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _pickAndUploadImage(dialogContext, setModalState),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 닉네임 입력
                  const Text(
                    '닉네임',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nicknameController,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      hintText: '닉네임을 입력하세요',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 저장 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final newNickname = nicknameController.text.trim();
                        if (newNickname.isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('닉네임을 입력해주세요')),
                          );
                          return;
                        }
                        authProvider.updateProfile(nickname: newNickname);
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('프로필이 수정되었습니다')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAllBadges(BuildContext context) {
    final badgeProvider = context.read<BadgeProvider>();
    final stampCount = context.read<StampProvider>().stampCount;
    final allBadges = badgeProvider.allBadges;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            // 카테고리별로 그룹화
            final categories = <String, List<BadgeModel>>{};
            for (final badge in allBadges) {
              final category = badge.category ?? 'other';
              categories.putIfAbsent(category, () => []).add(badge);
            }

            final categoryNames = {
              'completion': '완등 뱃지',
              'time': '시간대 뱃지',
              'distance': '거리 뱃지',
              'streak': '연속 뱃지',
              'community': '커뮤니티 뱃지',
              'category': '카테고리 뱃지',
            };

            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '전체 뱃지',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${badgeProvider.earnedCount}/${badgeProvider.totalCount} 획득',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: allBadges.length,
                      itemBuilder: (context, index) {
                        final badge = allBadges[index];
                        final earned = _isBadgeEarned(badge, stampCount, badgeProvider);
                        final color = _getBadgeColor(badge.category ?? 'completion');
                        final progress = badge.conditionType == 'oreum_count'
                            ? (stampCount / (badge.conditionValue ?? 1)).clamp(0.0, 1.0)
                            : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: earned ? color.withOpacity(0.05) : AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: earned ? color.withOpacity(0.3) : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: earned ? color.withOpacity(0.15) : AppColors.surface,
                                  shape: BoxShape.circle,
                                  border: earned
                                      ? Border.all(color: color, width: 2)
                                      : null,
                                ),
                                child: Center(
                                  child: earned
                                      ? Text(badge.icon ?? '🏅', style: const TextStyle(fontSize: 24))
                                      : const Icon(Icons.lock, color: AppColors.textHint, size: 24),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            badge.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: earned ? color : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (earned)
                                          Icon(Icons.check_circle, size: 18, color: color),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      badge.description ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (badge.conditionType == 'oreum_count') ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                backgroundColor: AppColors.border,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  earned ? color : AppColors.primary,
                                                ),
                                                minHeight: 6,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '$stampCount/${badge.conditionValue ?? 0}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: earned ? color : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBookmarks(BuildContext context) {
    final bookmarks = context.read<OreumProvider>().bookmarkedOreums;

    if (bookmarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장한 오름이 없습니다')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '저장한 오름 (${bookmarks.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    final oreum = bookmarks[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surface,
                        child: const Icon(Icons.terrain, color: AppColors.primary),
                      ),
                      title: Text(oreum.name),
                      subtitle: Text(oreum.difficulty ?? ''),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHistory(BuildContext context) {
    final stamps = context.read<StampProvider>().stamps;

    if (stamps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('탐험 기록이 없습니다')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '탐험 기록 (${stamps.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: stamps.length,
                  itemBuilder: (context, index) {
                    final stamp = stamps[index];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified, color: AppColors.primary),
                      ),
                      title: Text(stamp.oreumName),
                      subtitle: Text(
                        '${stamp.stampedAt.year}.${stamp.stampedAt.month}.${stamp.stampedAt.day}',
                      ),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                      onTap: () {
                        Navigator.pop(context); // 바텀시트 닫기
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HikingDetailScreen(stamp: stamp),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('도움말'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GPS 스탬프 인증',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('오름 정상에서 200m 이내에서 GPS 인증을 하면 스탬프를 획득할 수 있습니다.'),
              SizedBox(height: 16),
              Text(
                '레벨 시스템',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('스탬프 1개당 레벨 1씩 올라갑니다.'),
              SizedBox(height: 16),
              Text(
                '뱃지 획득',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('스탬프를 모으면 다양한 뱃지를 획득할 수 있습니다.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showWeightDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final controller = TextEditingController(
      text: authProvider.weight?.toStringAsFixed(1) ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('체중 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '칼로리 계산에 사용됩니다',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '체중 (kg)',
                suffixText: 'kg',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
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
              final weight = double.tryParse(controller.text);
              if (weight != null && weight > 0 && weight < 500) {
                await authProvider.updateProfile(weight: weight);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('체중이 저장되었습니다')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('올바른 체중을 입력해주세요')),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showAppInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('제주오름'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terrain, size: 64, color: AppColors.primary),
            SizedBox(height: 16),
            Text('버전 1.0.0'),
            SizedBox(height: 8),
            Text(
              '제주의 아름다운 오름을 탐험하고\n나만의 등산 기록을 남겨보세요!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().signOut();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('로그아웃 되었습니다')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}
