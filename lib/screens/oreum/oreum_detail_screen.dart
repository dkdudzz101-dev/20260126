import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../models/oreum_model.dart';
import '../../providers/stamp_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/oreum_provider.dart';
import '../../services/community_service.dart';
import '../../models/post_model.dart';
import '../../services/blog_service.dart';
import '../../services/map_service.dart';
import '../../services/oreum_service.dart';
import '../../services/stamp_service.dart';
import '../hiking/hiking_screen.dart';
import '../map/map_screen.dart';
import 'oreum_error_report_screen.dart';
import 'package:photo_view/photo_view.dart';
import '../../utils/login_guard.dart';
import 'package:photo_view/photo_view_gallery.dart';

class OreumDetailScreen extends StatefulWidget {
  final OreumModel oreum;

  const OreumDetailScreen({super.key, required this.oreum});

  @override
  State<OreumDetailScreen> createState() => _OreumDetailScreenState();
}

class _OreumDetailScreenState extends State<OreumDetailScreen> {
  OreumModel get oreum => widget.oreum;
  final CommunityService _communityService = CommunityService();
  final BlogService _blogService = BlogService();
  final OreumService _oreumService = OreumService();
  final StampService _stampService = StampService();
  List<PostModel> _oreumPosts = [];
  bool _isLoadingPosts = true;
  List<BlogPost> _blogPosts = [];
  bool _isLoadingBlogs = true;
  List<String> _officialImages = [];
  List<String> _communityImages = [];
  String? _gallerySource;
  bool _isLoadingGallery = true;
  bool _isUploadingImage = false;
  List<Map<String, dynamic>> _stampUsers = [];
  bool _isLoadingStampUsers = true;

  @override
  void initState() {
    super.initState();
    _loadOreumPosts();
    _loadBlogPosts();
    _loadGalleryImages();
    _loadStampUsers();
  }

  Future<void> _loadGalleryImages() async {
    try {
      final result = await _oreumService.getGalleryImagesWithSource(oreum.id);
      String? source;
      try {
        source = await _oreumService.getGallerySource(oreum.id);
      } catch (_) {
        // 출처 조회 실패해도 무시
      }
      if (mounted) {
        setState(() {
          _officialImages = result['official'] ?? [];
          _communityImages = result['community'] ?? [];
          _gallerySource = source;
          _isLoadingGallery = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGallery = false);
      }
    }
  }

  Future<void> _loadStampUsers() async {
    try {
      final users = await _stampService.getOreumStampUsers(oreum.id);
      if (mounted) {
        setState(() {
          _stampUsers = users;
          _isLoadingStampUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStampUsers = false);
      }
    }
  }

  List<String> get _allGalleryImages => [..._communityImages, ..._officialImages];  // 최신(커뮤니티) 먼저

  Future<void> _uploadGalleryImage() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      maxWidth: 1024,  // 최대 1024px
      maxHeight: 1024,
      imageQuality: 60,  // 60% 품질 (용량 절약)
    );

    if (pickedFiles.isEmpty) return;

    setState(() => _isUploadingImage = true);

    try {
      int successCount = 0;
      int failCount = 0;
      final List<String> uploadedUrls = [];

      for (final file in pickedFiles) {
        try {
          final url = await _oreumService.uploadGalleryImage(oreum.id, file.path);
          uploadedUrls.add(url);
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('이미지 업로드 실패: $e');
        }
      }

      // 업로드된 이미지를 하나의 게시글로 등록
      if (uploadedUrls.isNotEmpty) {
        await _oreumService.createGalleryPost(oreum.id, uploadedUrls);
      }

      if (mounted) {
        if (failCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$successCount장의 사진이 업로드되었습니다')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$successCount장 성공, $failCount장 실패')),
          );
        }
        _loadGalleryImages(); // 갤러리 새로고침
      }
    } catch (e) {
      debugPrint('에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('업로드에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _loadBlogPosts() async {
    try {
      final posts = await _blogService.searchBlogPosts(oreum.name);
      if (mounted) {
        setState(() {
          _blogPosts = posts;
          _isLoadingBlogs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBlogs = false);
      }
    }
  }

  Future<void> _loadOreumPosts() async {
    try {
      final data = await _communityService.getPostsByOreum(oreum.id);
      if (mounted) {
        setState(() {
          _oreumPosts = data.map((d) => PostModel.fromSupabase(d)).toList();
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPosts = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 출입 제한 경고 배너
                if (oreum.restriction != null && oreum.restriction!.isNotEmpty)
                  _buildRestrictionBanner(),
                // 갤러리 섹션
                _buildGallerySection(),
                _buildOreumInfoList(),
                if (oreum.elevationUrl != null) ...[
                  const SizedBox(height: 16),
                  _buildElevationGraphSection(),
                ],
                const Divider(height: 32),
                // 인증자 순위 섹션
                _buildStampUsersSection(),
                const Divider(height: 32),
                // 블로그 섹션
                _buildBlogSection(),
                const Divider(height: 32),
                // 커뮤니티 게시글
                _buildCommunityPostsSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            oreum.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (oreum.difficulty != null)
                _buildAppBarBadge(
                  oreum.difficulty!,
                  _getDifficultyColor(oreum.difficulty),
                ),
              if (oreum.difficulty != null) const SizedBox(width: 4),
              _buildAppBarBadge(
                (oreum.trailStatus ?? 'checking') == 'verified' ? '확인됨' : '미확인',
                (oreum.trailStatus ?? 'checking') == 'verified' ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              if (oreum.restriction != null && oreum.restriction!.isNotEmpty)
                _buildAppBarBadge(oreum.restriction!, Colors.red)
              else
                _buildAppBarBadge(
                  (oreum.geojsonPath != null && oreum.geojsonPath!.isNotEmpty) ? '등산로 있음' : '등산로 없음',
                  (oreum.geojsonPath != null && oreum.geojsonPath!.isNotEmpty) ? Colors.blue : Colors.grey,
                ),
            ],
          ),
        ],
      ),
      actions: [
        Consumer2<OreumProvider, AuthProvider>(
          builder: (context, oreumProvider, authProvider, _) {
            final isBookmarked = oreumProvider.isBookmarked(oreum.id);
            return IconButton(
              icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
              onPressed: () async {
                // 로그인 체크
                if (!authProvider.isLoggedIn) {
                  _showLoginRequiredDialog();
                  return;
                }
                final result = await oreumProvider.toggleBookmark(oreum);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result ? '북마크에 추가되었습니다' : '북마크가 해제되었습니다'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.report_problem_outlined),
          tooltip: '정보 오류 신고',
          onPressed: () {
            final authProvider = context.read<AuthProvider>();
            if (!authProvider.isLoggedIn) {
              _showLoginRequiredDialog();
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OreumErrorReportScreen(oreum: oreum),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () => _shareOreum(),
        ),
      ],
    );
  }

  Widget _buildOreumInfoList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 기본 정보
          if (oreum.difficulty != null)
            _buildInfoRowWithIcon(Icons.trending_up, '난이도', oreum.difficulty!, Colors.orange),
          if (oreum.elevation != null)
            _buildInfoRowWithIcon(Icons.height, '해발고도', '${oreum.elevation}m', Colors.teal),
          if (oreum.distance != null)
            _buildInfoRowWithIcon(Icons.straighten, '거리', '${oreum.distance!.toStringAsFixed(2)}km', Colors.blue),
          if (oreum.timeUp != null)
            _buildInfoRowWithIcon(Icons.arrow_upward, '상행시간', '${oreum.timeUp}분', Colors.green),
          if (oreum.timeDown != null)
            _buildInfoRowWithIcon(Icons.arrow_downward, '하행시간', '${oreum.timeDown}분', Colors.green),
          if (oreum.surface != null && oreum.surface!.isNotEmpty)
            _buildInfoRowWithIcon(Icons.terrain, '노면', oreum.surface!, Colors.brown),
          if (oreum.address != null && oreum.address!.isNotEmpty)
            _buildInfoRowWithIcon(Icons.location_on, '주소', oreum.address!, Colors.red),
          if (oreum.parking != null && oreum.parking!.isNotEmpty)
            _buildInfoRowWithIcon(Icons.local_parking, '주차', oreum.parking!, Colors.indigo),
          if (oreum.restroom != null && oreum.restroom!.isNotEmpty)
            _buildInfoRowWithIcon(Icons.wc, '화장실', oreum.restroom!, Colors.purple),
          _buildTrailStatusRow(),
          if (oreum.recommendedSeason != null && oreum.recommendedSeason!.isNotEmpty)
            _buildInfoRowWithIcon(Icons.calendar_month, '추천시기', oreum.recommendedSeason!, Colors.pink),
          if (oreum.visitTip != null && oreum.visitTip!.isNotEmpty)
            _buildInfoRowWithIcon(Icons.lightbulb_outline, '방문팁', oreum.visitTip!, Colors.amber),
          if (oreum.origin != null && oreum.origin!.isNotEmpty)
            _buildInfoRowWithIcon(Icons.history_edu, '이름유래', oreum.origin!, Colors.blueGrey),
          if (oreum.features != null && oreum.features!.isNotEmpty)
            _buildInfoRowWithIcon(Icons.auto_awesome, '특성', oreum.features!, Colors.amber),
          if (oreum.description != null && oreum.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              oreum.description!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStampUsersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, size: 20, color: Colors.amber),
              const SizedBox(width: 8),
              const Text(
                '인증 순위',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              if (!_isLoadingStampUsers)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_stampUsers.length}명',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingStampUsers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_stampUsers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.hiking, size: 40, color: AppColors.textHint),
                    SizedBox(height: 8),
                    Text('아직 인증한 사람이 없습니다', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ...List.generate(
              _stampUsers.length,
              (index) => _buildStampUserRow(index, _stampUsers[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildStampUserRow(int index, Map<String, dynamic> stampUser) {
    final rank = index + 1;
    final user = stampUser['users'] as Map<String, dynamic>?;
    final nickname = user?['nickname'] ?? '익명';
    final profileImage = user?['profile_image'] as String?;
    final completedAt = DateTime.tryParse(stampUser['completed_at'] ?? '');
    final dateStr = completedAt != null
        ? '${completedAt.year}.${completedAt.month.toString().padLeft(2, '0')}.${completedAt.day.toString().padLeft(2, '0')}'
        : '';

    // 순위별 색상
    Color rankColor;
    IconData? rankIcon;
    switch (rank) {
      case 1:
        rankColor = const Color(0xFFFFD700); // 금
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = const Color(0xFFC0C0C0); // 은
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = const Color(0xFFCD7F32); // 동
        rankIcon = Icons.emoji_events;
        break;
      default:
        rankColor = AppColors.textSecondary;
        rankIcon = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rank <= 3 ? rankColor.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: rank <= 3 ? rankColor.withOpacity(0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // 순위
          SizedBox(
            width: 32,
            child: rankIcon != null
                ? Icon(rankIcon, size: 22, color: rankColor)
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: rankColor,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          // 프로필
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surface,
            backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
            child: profileImage == null
                ? const Icon(Icons.person, size: 18, color: AppColors.textSecondary)
                : null,
          ),
          const SizedBox(width: 10),
          // 닉네임
          Expanded(
            child: Text(
              nickname,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 인증 날짜
          Text(
            dateStr,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailStatusRow() {
    final isVerified = (oreum.trailStatus ?? 'checking') == 'verified';
    final color = isVerified ? Colors.green : Colors.orange;
    final statusLabel = isVerified ? '확인됨' : '미확인';

    String dateStr = '';
    if (isVerified && oreum.trailVerifiedAt != null) {
      final d = oreum.trailVerifiedAt!;
      dateStr = ' (${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')})';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user, size: 18, color: color),
          const SizedBox(width: 8),
          const SizedBox(
            width: 60,
            child: Text(
              '인증여부',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$statusLabel$dateStr',
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // 확인 버튼은 숨김 (등반 완료 시 자동 처리)
        ],
      ),
    );
  }

  Future<void> _manualVerifyTrailStatus() async {
    try {
      // 등산로 현황을 '확인됨'으로 변경
      await _oreumService.updateTrailStatus(oreum.id, 'verified');

      // 스탬프(인증) 기록도 저장 → 인증된 오름 + 인증순위 반영
      final stampProvider = context.read<StampProvider>();
      if (!stampProvider.hasStamp(oreum.id)) {
        await stampProvider.verifyAndStampManual(oreum);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등산로 확인 완료')),
        );
        setState(() {});
      }
    } catch (e) {
      debugPrint('에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('변경에 실패했습니다.')),
        );
      }
    }
  }

  Widget _buildInfoRowWithIcon(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailViewButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: () => _navigateToMapWithTrail(),
        icon: const Icon(Icons.map_outlined),
        label: const Text('등산로 보기'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (oreum.trailName != null)
            Text(
              oreum.trailName!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip(
                icon: Icons.trending_up,
                label: oreum.difficulty ?? '미정',
                color: _getDifficultyColor(oreum.difficulty),
              ),
              const SizedBox(width: 12),
              if (oreum.timeUp != null)
                _buildInfoChip(
                  icon: Icons.schedule,
                  label: '${oreum.timeUp}분',
                  color: AppColors.primary,
                ),
              const SizedBox(width: 12),
              if (oreum.distance != null)
                _buildInfoChip(
                  icon: Icons.straighten,
                  label: '${oreum.distance!.toStringAsFixed(2)}km',
                  color: AppColors.secondary,
                ),
              if (oreum.elevation != null) ...[
                const SizedBox(width: 12),
                _buildInfoChip(
                  icon: Icons.height,
                  label: '${oreum.elevation}m',
                  color: Colors.teal,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오름 소개',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            oreum.description ?? '${oreum.name}은(는) 제주의 아름다운 오름 중 하나입니다. 등산로를 따라 올라가면 제주의 멋진 경치를 감상할 수 있습니다.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // 출입 제한 경고 배너
  Widget _buildRestrictionBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '출입 제한: ${oreum.restriction}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                if (oreum.restrictionNote != null && oreum.restrictionNote!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    oreum.restrictionNote!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade700,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 카테고리 태그
  Widget _buildCategoryTags() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: oreum.categories.map((category) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '#$category',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 이름 유래 섹션
  Widget _buildOriginSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_edu, size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '이름 유래',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              oreum.origin!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 오름 특성 섹션
  Widget _buildFeaturesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.landscape, size: 20, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  '오름 특성',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              oreum.features!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 추천 시기 섹션
  Widget _buildRecommendedSeasonSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_month, size: 24, color: Colors.orange.shade700),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '추천 방문 시기',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    oreum.recommendedSeason!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 시설 정보 섹션 (타이틀 포함)
  Widget _buildFacilitySectionWithTitle() {
    final hasParking = oreum.parking != null && oreum.parking!.isNotEmpty;
    final hasRestroom = oreum.restroom != null && oreum.restroom!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '편의시설',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (!hasParking && !hasRestroom)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 40, color: AppColors.textHint),
                    SizedBox(height: 8),
                    Text('등록된 시설 정보가 없습니다', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else ...[
            if (hasParking)
              _buildFacilityRow(
                icon: Icons.local_parking,
                label: '주차',
                value: oreum.parking!,
                color: Colors.blue,
              ),
            if (hasRestroom)
              _buildFacilityRow(
                icon: Icons.wc,
                label: '화장실',
                value: oreum.restroom!,
                color: Colors.teal,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFacilityRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '등산로 정보',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _navigateToMapWithTrail(),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('등산로 보기'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (oreum.timeUp != null)
            _buildTrailInfoRow('상행 시간', '약 ${oreum.timeUp}분'),
          if (oreum.timeDown != null)
            _buildTrailInfoRow('하행 시간', '약 ${oreum.timeDown}분'),
          if (oreum.distance != null)
            _buildTrailInfoRow('총 거리', '${oreum.distance!.toStringAsFixed(2)}km'),
          if (oreum.surface != null && oreum.surface!.isNotEmpty)
            _buildTrailInfoRow('노면', oreum.surface!),
        ],
      ),
    );
  }

  void _navigateToMapWithTrail() {
    // 지도 화면으로 이동하면서 해당 오름 선택
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(initialOreum: oreum),
      ),
    );
  }

  Widget _buildTrailInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElevationGraphSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                '고도 그래프',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.network(
                oreum.elevationUrl!,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 150,
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported, color: AppColors.textHint),
                        SizedBox(height: 8),
                        Text(
                          '고도 그래프를 불러올 수 없습니다',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _navigateToMapWithTrail(),
              icon: const Icon(Icons.map_outlined),
              label: const Text('등산로 보기'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openNavigation(context),
                  icon: const Icon(Icons.navigation),
                  label: const Text('길안내'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToHiking(),
                  icon: const Icon(Icons.hiking),
                  label: const Text('등반 시작'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 등반 시작 시 입구 거리 체크
  Future<void> _startHikingWithDistanceCheck() async {
    final mapService = MapService();
    final position = await mapService.getCurrentPosition();

    if (position == null) {
      // 위치를 가져올 수 없으면 바로 등반 시작
      _navigateToHiking();
      return;
    }

    if (oreum.startLat == null || oreum.startLng == null) {
      _navigateToHiking();
      return;
    }

    // 입구까지 거리 계산
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      oreum.startLat!,
      oreum.startLng!,
    );

    if (distance <= 100) {
      // 100m 이내면 바로 등반 시작
      _navigateToHiking();
    } else {
      // 100m 밖이면 팝업 표시
      final distanceText = distance < 1000
          ? '${distance.toInt()}m'
          : '${(distance / 1000).toStringAsFixed(1)}km';

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('입구에서 멀리 있습니다'),
          content: Text(
            '현재 위치가 ${oreum.name} 입구에서 $distanceText 떨어져 있습니다.\n\n입구로 이동하거나 현재 위치에서 시작할 수 있습니다.',
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToHiking();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('현재 위치에서 시작'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          mapService.openKakaoMapNavigation(
                            destLat: oreum.startLat!,
                            destLng: oreum.startLng!,
                            destName: '${oreum.name} 입구',
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('네비 실행'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('닫기'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  void _navigateToHiking() {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HikingScreen(oreum: oreum, autoStart: true),
      ),
    );
  }

  Widget _buildAppBarBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _getDifficultyColor(String? difficulty) {
    switch (difficulty) {
      case '쉬움':
        return AppColors.difficultyEasy;
      case '보통':
        return AppColors.difficultyMedium;
      case '어려움':
        return AppColors.difficultyHard;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildGallerySection() {
    if (_isLoadingGallery) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final allImages = _allGalleryImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 갤러리 헤더 (사진 추가 버튼 포함)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.photo_library, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    '갤러리 (${allImages.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              _isUploadingImage
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: _uploadGalleryImage,
                      icon: const Icon(Icons.add_photo_alternate),
                      tooltip: '사진 추가',
                    ),
            ],
          ),
        ),
        if (allImages.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.photo_library_outlined, size: 48, color: AppColors.textHint),
                  const SizedBox(height: 8),
                  const Text('아직 등록된 사진이 없습니다', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _uploadGalleryImage,
                    icon: const Icon(Icons.add_photo_alternate, size: 18),
                    label: const Text('첫 번째 사진 올리기'),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: allImages.length,
              itemBuilder: (context, index) {
                final imageUrl = allImages[index];
                final isCommunity = index < _communityImages.length;  // 커뮤니티가 앞에 있음
                return GestureDetector(
                  onTap: () => _openGalleryViewer(index),
                  child: Container(
                    width: 320,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image, color: AppColors.textHint),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          },
                        ),
                        // 커뮤니티 사진 표시
                        if (isCommunity)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    '커뮤니티',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (_gallerySource != null && _officialImages.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                '공식 사진 출처: $_gallerySource',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openGalleryViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GalleryViewerScreen(
          images: _allGalleryImages,
          initialIndex: initialIndex,
          communityCount: _communityImages.length,  // 커뮤니티가 앞에 있음
          onImageDeleted: () {
            _loadGalleryImages(); // 삭제 후 갤러리 새로고침
          },
        ),
      ),
    );
  }

  Widget _buildStampButton() {
    return Consumer<StampProvider>(
      builder: (context, stampProvider, _) {
        final hasStamp = stampProvider.hasStamp(oreum.id);
        final stampDate = stampProvider.getStampDate(oreum.id);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: hasStamp ? null : () => _showStampVerification(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasStamp
                      ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                      : [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasStamp ? Icons.verified : Icons.verified_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasStamp ? '스탬프 획득 완료!' : '스탬프 인증하기',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasStamp
                              ? '${stampDate?.year}.${stampDate?.month}.${stampDate?.day} 방문'
                              : '정상 100m 이내에서 GPS 인증',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!hasStamp)
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showStampVerification() {
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
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '스탬프 인증',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.gps_fixed, color: AppColors.primary),
                  ),
                  title: const Text('GPS로 인증하기'),
                  subtitle: const Text('현재 위치로 인증'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    Navigator.pop(context);
                    await _verifyStamp();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _verifyStamp() async {
    // 중앙화된 위치 권한 플로우 (전체화면 공개 포함)
    final granted = await MapService.ensureLocationPermission(context);
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 필요합니다')),
        );
      }
      return;
    }

    final stampProvider = context.read<StampProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await stampProvider.verifyAndStamp(oreum);
    if (!mounted) return;
    Navigator.pop(context);

    if (result.success) {
      _showStampSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  void _showStampSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '스탬프 획득!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${oreum.name} 완등을 축하합니다!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBlogSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.article_outlined, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    '블로그 후기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (_blogPosts.isNotEmpty)
                TextButton(
                  onPressed: () => _showAllBlogPosts(),
                  child: const Text('더보기'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingBlogs)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_blogPosts.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 40, color: AppColors.textHint),
                    SizedBox(height: 8),
                    Text('관련 블로그 글이 없습니다', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ...(_blogPosts.take(3).map((post) => _buildBlogCard(post))),
        ],
      ),
    );
  }

  Widget _buildBlogCard(BlogPost post) {
    return GestureDetector(
      onTap: () => _openBlogPost(post.link),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              post.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    post.bloggerName,
                    style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _blogService.formatDate(post.postDate),
                  style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBlogPost(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('블로그를 열 수 없습니다')),
        );
      }
    }
  }

  void _showAllBlogPosts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.article_outlined, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            '${oreum.name} 블로그 후기',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _blogPosts.length,
                    itemBuilder: (context, index) {
                      return _buildBlogCard(_blogPosts[index]);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCommunityPostsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    '방문 후기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_oreumPosts.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_reviews.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      _averageRating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
              TextButton.icon(
                onPressed: () => _showWritePostDialog(),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('후기 작성'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingPosts)
            const Center(child: CircularProgressIndicator())
          else if (_oreumPosts.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 40, color: AppColors.textHint),
                    SizedBox(height: 8),
                    Text('첫 번째 후기를 작성해보세요!', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ..._oreumPosts.map((post) => _buildPostCard(post)),
        ],
      ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surface,
                backgroundImage: post.userProfileImage != null ? NetworkImage(post.userProfileImage!) : null,
                child: post.userProfileImage == null
                    ? const Icon(Icons.person, size: 20, color: AppColors.textSecondary)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userNickname ?? '익명',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      post.timeAgo,
                      style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 2),
                  Text('${post.likeCount}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  const SizedBox(width: 8),
                  const Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 2),
                  Text('${post.commentCount}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.content,
            style: const TextStyle(fontSize: 14, height: 1.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: post.images.length > 3 ? 3 : post.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    post.images[i],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80, height: 80,
                      color: AppColors.surface,
                      child: const Icon(Icons.image, color: AppColors.textHint),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showWritePostDialog() {
    if (!LoginGuard.check(context, message: '후기를 작성하려면 로그인이 필요합니다.\n로그인 하시겠습니까?')) return;

    final contentController = TextEditingController();
    bool isSubmitting = false;

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${oreum.name} 후기',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText: '방문 후기를 남겨주세요...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (contentController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(content: Text('내용을 입력해주세요')),
                                );
                                return;
                              }
                              setModalState(() => isSubmitting = true);
                              try {
                                await _communityService.createPost(
                                  content: contentController.text.trim(),
                                  oreumId: oreum.id,
                                  category: '후기',
                                );
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('후기가 등록되었습니다')),
                                  );
                                  _loadOreumPosts();
                                }
                              } catch (e) {
                                debugPrint('에러: $e');
                                setModalState(() => isSubmitting = false);
                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    const SnackBar(content: Text('오류가 발생했습니다.')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('등록하기'),
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

  void _showEditReviewDialog(Map<String, dynamic> review) {
    final contentController = TextEditingController(text: review['content'] ?? '');
    int selectedRating = review['rating'] as int? ?? 5;
    bool isSubmitting = false;

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '리뷰 수정',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('별점', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedRating = index + 1),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            index < selectedRating ? Icons.star : Icons.star_border,
                            size: 32,
                            color: Colors.amber,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      hintText: '방문 후기를 남겨주세요...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              try {
                                await _reviewService.updateReview(
                                  reviewId: review['id'].toString(),
                                  rating: selectedRating,
                                  content: contentController.text.trim().isNotEmpty
                                      ? contentController.text.trim()
                                      : null,
                                );
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('리뷰가 수정되었습니다')),
                                  );
                                  _loadReviews();
                                }
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    SnackBar(content: Text('오류: $e')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('수정하기'),
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

  void _showLoginRequiredDialog() {
    LoginGuard.check(context);
  }

  void _shareOreum() {
    final text = '''
🏔️ ${oreum.name}

${oreum.description ?? '제주의 아름다운 오름을 만나보세요!'}

📍 난이도: ${oreum.difficulty ?? '미정'}
⏱️ 소요시간: ${oreum.timeUp != null ? '약 ${oreum.timeUp}분' : '정보 없음'}
📏 거리: ${oreum.distance != null ? '${oreum.distance!.toStringAsFixed(2)}km' : '정보 없음'}

제주오름 앱에서 더 많은 오름을 탐험해보세요!
''';

    Share.share(text, subject: '${oreum.name} - 제주오름');
  }

  Future<void> _openNavigation(BuildContext context) async {
    if (oreum.startLat == null || oreum.startLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 정보가 없습니다')),
      );
      return;
    }

    final kakaoMapUrl = 'kakaomap://route?ep=${oreum.startLat},${oreum.startLng}&by=FOOT';
    final webUrl = 'https://map.kakao.com/link/to/${oreum.name},${oreum.startLat},${oreum.startLng}';

    try {
      if (await canLaunchUrl(Uri.parse(kakaoMapUrl))) {
        await launchUrl(Uri.parse(kakaoMapUrl));
      } else {
        await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지도를 열 수 없습니다')),
        );
      }
    }
  }
}

// 갤러리 전체화면 뷰어
class GalleryViewerScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final int communityCount; // 커뮤니티 이미지 개수 (앞에 있음)
  final VoidCallback? onImageDeleted;

  const GalleryViewerScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    this.communityCount = 0,
    this.onImageDeleted,
  });

  @override
  State<GalleryViewerScreen> createState() => _GalleryViewerScreenState();
}

class _GalleryViewerScreenState extends State<GalleryViewerScreen> {
  late int _currentIndex;
  late PageController _pageController;
  final OreumService _oreumService = OreumService();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isCurrentCommunityImage => _currentIndex < widget.communityCount;  // 커뮤니티가 앞에 있음

  Future<void> _showOptions() async {
    if (!_isCurrentCommunityImage) return; // 공식 이미지는 옵션 없음

    final imageUrl = widget.images[_currentIndex];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id;

    // 이미지 소유자 정보 확인
    final postInfo = await _oreumService.getImagePostInfo(imageUrl);
    final isOwner = postInfo != null && postInfo['user_id'] == currentUserId;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('내 사진 삭제', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(imageUrl);
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.orange),
              title: const Text('부적절한 사진 신고'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(imageUrl);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String imageUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사진 삭제'),
        content: const Text('이 사진을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _oreumService.deleteGalleryImage(imageUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('사진이 삭제되었습니다')),
          );
          widget.onImageDeleted?.call();
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('에러: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('삭제에 실패했습니다.')),
          );
        }
      }
    }
  }

  Future<void> _showReportDialog(String imageUrl) async {
    final reasons = ['부적절한 콘텐츠', '스팸/광고', '저작권 침해', '기타'];
    String? selectedReason;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('사진 신고'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('신고 사유를 선택해주세요:'),
              const SizedBox(height: 12),
              ...reasons.map((reason) => RadioListTile<String>(
                title: Text(reason),
                value: reason,
                groupValue: selectedReason,
                onChanged: (value) => setState(() => selectedReason = value),
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: selectedReason != null
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('신고'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedReason != null) {
      try {
        await _oreumService.reportGalleryImage(imageUrl, selectedReason!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('신고가 접수되었습니다')),
          );
        }
      } catch (e) {
        debugPrint('에러: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('신고에 실패했습니다. 다시 시도해주세요.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.images.length}'),
        actions: [
          if (_isCurrentCommunityImage)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showOptions,
            ),
        ],
      ),
      body: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: widget.images.length,
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(widget.images[index]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
            ),
          );
        },
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
