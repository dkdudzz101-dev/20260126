import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import '../../providers/stamp_provider.dart';
import '../../providers/oreum_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/map_service.dart';
import '../auth/login_screen.dart';
import '../oreum/oreum_detail_screen.dart';
import '../../models/oreum_model.dart';

class StampScreen extends StatefulWidget {
  const StampScreen({super.key});

  @override
  State<StampScreen> createState() => _StampScreenState();
}

class _StampScreenState extends State<StampScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StampProvider>().loadStamps();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('스탬프북'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'BETA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _showStampOptions(context),
          ),
        ],
      ),
      body: _buildStampContent(),
    );
  }

  Widget _buildStampContent() {
    final authProvider = context.watch<AuthProvider>();
    final oreumProvider = context.watch<OreumProvider>();

    return Consumer<StampProvider>(
      builder: (context, stampProvider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 로그인 안내 배너 (로그인 안했을 때)
              if (!authProvider.isLoggedIn) _buildLoginBanner(),
              if (!authProvider.isLoggedIn) const SizedBox(height: 16),
              _buildQuickStampButton(context),
              const SizedBox(height: 16),
              // 가까운 미인증 오름 추천
              _buildNearbyUnstampedSection(oreumProvider, stampProvider),
              const SizedBox(height: 16),
              // 스탬프 도감
              _buildStampCollection(oreumProvider, stampProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoginBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.textHint.withOpacity(0.2),
            child: const Icon(Icons.person_outline, color: AppColors.textHint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '로그인 후 이용하세요',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '스탬프 기록이 저장됩니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('로그인'),
          ),
        ],
      ),
    );
  }

  static const int totalOreumCount = 368;

  Widget _buildQuickStampButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showStampOptions(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.gps_fixed,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GPS 스탬프 인증',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '정상 100m 이내에서 인증',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  // 가까운 미인증 오름 섹션
  Widget _buildNearbyUnstampedSection(OreumProvider oreumProvider, StampProvider stampProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.near_me, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              '가까운 미인증 오름',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<OreumModel>>(
          future: _getNearbyUnstampedOreums(oreumProvider, stampProvider),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final nearbyOreums = snapshot.data ?? [];

            if (nearbyOreums.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('주변 오름을 모두 인증했습니다!'),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: nearbyOreums.length,
                itemBuilder: (context, index) {
                  final oreum = nearbyOreums[index];
                  return _buildNearbyOreumCard(oreum);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Future<List<OreumModel>> _getNearbyUnstampedOreums(
    OreumProvider oreumProvider,
    StampProvider stampProvider,
  ) async {
    try {
      final mapService = MapService();
      final position = await mapService.getCurrentPosition();

      if (position == null) return [];

      // 활성 오름 중 미인증 오름만 필터링
      final unstampedOreums = oreumProvider.oreums.where((oreum) {
        return !stampProvider.hasStamp(oreum.id) &&
            oreum.summitLat != null &&
            oreum.summitLng != null;
      }).toList();

      // 거리순 정렬
      unstampedOreums.sort((a, b) {
        final distA = Geolocator.distanceBetween(
          position.latitude, position.longitude,
          a.summitLat!, a.summitLng!,
        );
        final distB = Geolocator.distanceBetween(
          position.latitude, position.longitude,
          b.summitLat!, b.summitLng!,
        );
        return distA.compareTo(distB);
      });

      // 상위 5개만 반환
      return unstampedOreums.take(5).toList();
    } catch (e) {
      return [];
    }
  }

  Widget _buildNearbyOreumCard(OreumModel oreum) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OreumDetailScreen(oreum: oreum)),
        );
      },
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 스탬프 이미지
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: oreum.stampUrl != null
                    ? Image.network(
                        oreum.stampUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        color: Colors.grey,
                        colorBlendMode: BlendMode.saturation,
                        errorBuilder: (_, __, ___) => _buildStampPlaceholder(),
                      )
                    : _buildStampPlaceholder(),
              ),
            ),
            // 오름 이름
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                oreum.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 스탬프 도감 (탭으로 베타/전체 구분)
  Widget _buildStampCollection(OreumProvider oreumProvider, StampProvider stampProvider) {
    final allOreums = oreumProvider.allOreumsForStamp; // 전체 368개 오름
    final betaOreums = oreumProvider.betaOreums; // DB에서 is_beta=true인 오름

    // 베타 오름 스탬프 수
    final betaStampCount = betaOreums.where((o) => stampProvider.hasStamp(o.id)).length;
    final totalStampCount = stampProvider.stampCount;

    // 현재 선택된 탭의 오름 목록
    final currentOreums = _tabController.index == 0 ? betaOreums : allOreums;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.collections_bookmark, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              '스탬프 도감',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 탭 버튼 (커스텀)
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _tabController.animateTo(0);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _tabController.index == 0 ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '베타',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _tabController.index == 0 ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$betaStampCount/${betaOreums.length}',
                            style: TextStyle(
                              fontSize: 10,
                              color: _tabController.index == 0 ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _tabController.animateTo(1);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _tabController.index == 1 ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '전체',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _tabController.index == 1 ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$totalStampCount/${allOreums.length}',
                            style: TextStyle(
                              fontSize: 10,
                              color: _tabController.index == 1 ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 그리드 (TabBarView 대신 직접 표시)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.75,
          ),
          itemCount: currentOreums.length,
          itemBuilder: (context, index) {
            final oreum = currentOreums[index];
            final hasStamp = stampProvider.hasStamp(oreum.id);
            return _buildCollectionItem(oreum, hasStamp);
          },
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildCollectionItem(OreumModel oreum, bool hasStamp) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OreumDetailScreen(oreum: oreum)),
        );
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasStamp ? AppColors.primary : AppColors.border,
                  width: hasStamp ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 스탬프 이미지
                    oreum.stampUrl != null
                        ? ColorFiltered(
                            colorFilter: hasStamp
                                ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                                : const ColorFilter.matrix(<double>[
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0, 0, 0, 0.5, 0,
                                  ]),
                            child: Image.network(
                              oreum.stampUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildStampPlaceholder(),
                            ),
                          )
                        : _buildStampPlaceholder(),
                    // 미획득 잠금 아이콘
                    if (!hasStamp)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    // 획득 체크
                    if (hasStamp)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            oreum.name,
            style: TextStyle(
              fontSize: 10,
              color: hasStamp ? AppColors.textPrimary : AppColors.textHint,
              fontWeight: hasStamp ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStampGrid(StampProvider provider) {
    if (provider.stamps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: const Column(
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: AppColors.textHint),
            SizedBox(height: 16),
            Text(
              '아직 획득한 스탬프가 없습니다',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 8),
            Text(
              '오름 정상에서 GPS 인증을 해보세요!',
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: provider.stamps.length,
      itemBuilder: (context, index) {
        final stamp = provider.stamps[index];
        return _buildStampCard(stamp);
      },
    );
  }

  Widget _buildStampCard(StampModel stamp) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 오름 이미지
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                width: double.infinity,
                color: AppColors.surface,
                child: stamp.imageUrl != null
                    ? Image.network(
                        stamp.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildStampPlaceholder(),
                      )
                    : _buildStampPlaceholder(),
              ),
            ),
          ),
          // 오름 정보
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: AppColors.primary,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stamp.oreumName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${stamp.stampedAt.year}.${stamp.stampedAt.month.toString().padLeft(2, '0')}.${stamp.stampedAt.day.toString().padLeft(2, '0')} 방문',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStampPlaceholder() {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Icon(
          Icons.terrain,
          size: 48,
          color: AppColors.textHint,
        ),
      ),
    );
  }

  void _showStampOptions(BuildContext context) {
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildOptionTile(
                  icon: Icons.gps_fixed,
                  title: 'GPS로 인증하기',
                  subtitle: '현재 위치로 가까운 오름 찾기',
                  onTap: () {
                    Navigator.pop(context);
                    _startGpsVerification();
                  },
                ),
                const SizedBox(height: 12),
                _buildOptionTile(
                  icon: Icons.list,
                  title: '오름 선택하기',
                  subtitle: '목록에서 오름을 선택해서 인증',
                  onTap: () {
                    Navigator.pop(context);
                    _showOreumSelector();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
    );
  }

  Future<void> _startGpsVerification() async {
    final stampProvider = context.read<StampProvider>();
    final oreumProvider = context.read<OreumProvider>();

    // 로딩 다이얼로그
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // 현재 위치 가져오기
    final position = await stampProvider.getCurrentPosition();
    if (!mounted) return;
    Navigator.pop(context);

    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(stampProvider.error ?? '위치를 가져올 수 없습니다')),
      );
      return;
    }

    // 가장 가까운 오름 찾기 (정상인증용 전체 오름 사용)
    final oreums = oreumProvider.allOreumsForStamp;
    if (oreums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오름 정보가 없습니다')),
      );
      return;
    }

    // 100m 이내의 오름 찾기 (정상 좌표 기준)
    const double maxDistance = 100.0; // 100m 이내

    // 정상 좌표가 있는 오름만 필터링하고 거리 계산
    final nearbyOreums = <Map<String, dynamic>>[];

    for (final oreum in oreums) {
      if (oreum.summitLat != null && oreum.summitLng != null) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          oreum.summitLat!,
          oreum.summitLng!,
        );

        if (distance <= maxDistance) {
          // 이미 스탬프가 있는지 확인
          final hasStamp = stampProvider.stamps.any((s) => s.oreumId == oreum.id);
          if (!hasStamp) {
            nearbyOreums.add({
              'oreum': oreum,
              'distance': distance,
            });
          }
        }
      }
    }

    if (nearbyOreums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('100m 이내에 인증 가능한 오름이 없습니다. 오름 정상에서 다시 시도해주세요.')),
      );
      return;
    }

    // 가장 가까운 오름 정렬
    nearbyOreums.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    if (nearbyOreums.length == 1) {
      // 1개만 있으면 바로 인증
      final nearestOreum = nearbyOreums.first['oreum'] as OreumModel;
      final distance = nearbyOreums.first['distance'] as double;
      _confirmAndVerify(nearestOreum, distance);
    } else {
      // 여러개면 선택하게
      _showNearbyOreumsList(nearbyOreums);
    }
  }

  void _confirmAndVerify(OreumModel oreum, double distance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('스탬프 인증'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${oreum.name}에서 ${distance.toInt()}m 떨어져 있습니다.'),
            const SizedBox(height: 8),
            const Text('스탬프를 획득하시겠습니까?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _doVerify(oreum);
            },
            child: const Text('인증하기'),
          ),
        ],
      ),
    );
  }

  void _showNearbyOreumsList(List<Map<String, dynamic>> nearbyOreums) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
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
              const SizedBox(height: 16),
              const Text(
                '주변 오름 선택',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${nearbyOreums.length}개의 오름이 100m 이내에 있습니다',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ...nearbyOreums.take(5).map((item) {
                final oreum = item['oreum'] as OreumModel;
                final distance = item['distance'] as double;
                return ListTile(
                  leading: const Icon(Icons.terrain, color: AppColors.primary),
                  title: Text(oreum.name),
                  subtitle: Text('${distance.toInt()}m'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmAndVerify(oreum, distance);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doVerify(OreumModel oreum) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${oreum.name} 스탬프 획득!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '스탬프 인증에 실패했습니다')),
      );
    }
  }

  void _showOreumSelector() {
    // 오름 선택은 활성 오름만 표시
    final oreums = context.read<OreumProvider>().oreums;

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
                      const Text(
                        '인증할 오름 선택',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: oreums.length,
                    itemBuilder: (context, index) {
                      final oreum = oreums[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surface,
                          child: const Icon(Icons.terrain, color: AppColors.primary),
                        ),
                        title: Text(oreum.name),
                        subtitle: Text(oreum.difficulty ?? ''),
                        onTap: () async {
                          Navigator.pop(context);
                          await _verifyOreum(oreum);
                        },
                      );
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

  Future<void> _verifyOreum(oreum) async {
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
      _showSuccessDialog(oreum.name);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  void _showSuccessDialog(String oreumName) {
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$oreumName 완등을 축하합니다!',
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
}
