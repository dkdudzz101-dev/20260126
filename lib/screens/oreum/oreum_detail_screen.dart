import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import '../../models/oreum_model.dart';
import '../../providers/stamp_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/oreum_provider.dart';
import '../../services/review_service.dart';
import '../../services/blog_service.dart';
import '../../services/map_service.dart';
import '../hiking/hiking_screen.dart';
import '../map/map_screen.dart';

class OreumDetailScreen extends StatefulWidget {
  final OreumModel oreum;

  const OreumDetailScreen({super.key, required this.oreum});

  @override
  State<OreumDetailScreen> createState() => _OreumDetailScreenState();
}

class _OreumDetailScreenState extends State<OreumDetailScreen> {
  OreumModel get oreum => widget.oreum;
  final ReviewService _reviewService = ReviewService();
  final BlogService _blogService = BlogService();
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = true;
  List<BlogPost> _blogPosts = [];
  bool _isLoadingBlogs = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _loadBlogPosts();
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

  Future<void> _loadReviews() async {
    try {
      final reviews = await _reviewService.getReviewsByOreum(oreum.id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
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
                _buildOreumImage(),
                _buildOreumInfoList(),
                // 등산로 보기 버튼
                _buildTrailViewButton(),
                if (oreum.elevationUrl != null) ...[
                  const SizedBox(height: 16),
                  _buildElevationGraphSection(),
                ],
                const Divider(height: 32),
                // 블로그 섹션
                _buildBlogSection(),
                const Divider(height: 32),
                // 리뷰 섹션
                _buildReviewSection(),
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
      title: Text(
        oreum.name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
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
          if (oreum.recommendedSeason != null && oreum.recommendedSeason!.isNotEmpty)
            _buildInfoRowWithIcon(Icons.calendar_month, '추천시기', oreum.recommendedSeason!, Colors.pink),
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
      child: Row(
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
              onPressed: () => _startHikingWithDistanceCheck(),
              icon: const Icon(Icons.hiking),
              label: const Text('등반 시작'),
            ),
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HikingScreen(oreum: oreum),
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

  Widget _buildOreumImage() {
    // aerialImageUrl 우선, 없으면 imageUrl 사용
    final displayImageUrl = oreum.aerialImageUrl ?? oreum.imageUrl;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AspectRatio(
        aspectRatio: 2 / 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          clipBehavior: Clip.antiAlias,
          child: displayImageUrl != null
              ? Image.network(
                  displayImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.surface,
                    child: const Center(
                      child: Icon(Icons.terrain, size: 48, color: AppColors.textHint),
                    ),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                )
              : Container(
                  color: AppColors.surface,
                  child: const Center(
                    child: Icon(Icons.terrain, size: 48, color: AppColors.textHint),
                  ),
                ),
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

  Widget _buildReviewSection() {
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
                    '방문자 리뷰',
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
                      '${_reviews.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showWriteReviewDialog(),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('리뷰 작성'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingReviews)
            const Center(child: CircularProgressIndicator())
          else if (_reviews.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.rate_review_outlined, size: 40, color: AppColors.textHint),
                    SizedBox(height: 8),
                    Text('첫 번째 리뷰를 작성해보세요!', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ..._reviews.map((review) => _buildReviewCard(review)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final user = review['users'] as Map<String, dynamic>?;
    final nickname = user?['nickname'] ?? '익명';
    final profileImage = user?['profile_image'] as String?;
    final rating = review['rating'] as int? ?? 0;
    final content = review['content'] as String? ?? '';
    final createdAt = DateTime.tryParse(review['created_at'] ?? '');
    final dateStr = createdAt != null
        ? '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}'
        : '';

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
                backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
                child: profileImage == null
                    ? const Icon(Icons.person, size: 20, color: AppColors.textSecondary)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            size: 14,
                            color: Colors.amber,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              content,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  void _showWriteReviewDialog() {
    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리뷰를 작성하려면 로그인이 필요합니다')),
      );
      return;
    }

    final contentController = TextEditingController();
    int selectedRating = 5;
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
                        '리뷰 작성',
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
                                await _reviewService.createReview(
                                  oreumId: oreum.id,
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
                                    const SnackBar(content: Text('리뷰가 등록되었습니다')),
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

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('로그인 필요'),
          content: const Text('찜 기능을 사용하려면 로그인이 필요합니다.\n로그인 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // 로그인 화면으로 이동
                Navigator.pushNamed(context, '/login');
              },
              child: const Text('로그인'),
            ),
          ],
        );
      },
    );
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
