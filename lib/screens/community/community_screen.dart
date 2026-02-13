import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../providers/community_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/oreum_provider.dart';
import '../../models/post_model.dart';
import '../../services/community_service.dart';
import '../../services/block_service.dart';
import '../../services/report_service.dart';
import '../../utils/content_filter.dart';
import '../auth/login_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _selectedFilter = '최신';
  String _selectedCategory = '전체';
  String? _selectedOreumId; // ignore: unused_field
  String? _selectedOreumName;
  final List<String> _filters = ['인기', '최신', '내 글'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityProvider>().loadBlockedUsers();
      context.read<CommunityProvider>().loadPosts(filter: _selectedFilter);
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });

    final communityProvider = context.read<CommunityProvider>();
    if (filter == '내 글') {
      final userId = context.read<AuthProvider>().user?.id ?? '';
      communityProvider.loadMyPosts(userId);
    } else {
      communityProvider.loadPosts(filter: filter);
    }
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
    });
    context.read<CommunityProvider>().setCategory(category);
  }

  void _onOreumSelected(String? oreumId, String? oreumName) {
    setState(() {
      _selectedOreumId = oreumId;
      _selectedOreumName = oreumName;
    });
    context.read<CommunityProvider>().setOreumFilter(oreumId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티'),
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: Consumer<CommunityProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.posts.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () => provider.loadPosts(filter: _selectedFilter),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.posts.length,
                    itemBuilder: (context, index) {
                      return _buildPostCard(provider.posts[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'community_write_post_btn',
        onPressed: () => _showWritePostDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Column(
      children: [
        // 오름 드롭다운 + 정렬 필터
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 오름 드롭다운
              Expanded(
                child: GestureDetector(
                  onTap: _showOreumPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.terrain, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedOreumName ?? '오름 전체',
                            style: TextStyle(
                              fontSize: 13,
                              color: _selectedOreumName != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_selectedOreumName != null)
                          GestureDetector(
                            onTap: () => _onOreumSelected(null, null),
                            child: const Icon(Icons.close, size: 16),
                          )
                        else
                          const Icon(Icons.keyboard_arrow_down, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 정렬 필터
              ..._filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: GestureDetector(
                    onTap: () => _onFilterChanged(filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        // 카테고리 탭
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: CommunityProvider.categories.map((category) {
              final isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _onCategoryChanged(category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _showOreumPicker() {
    final oreums = context.read<OreumProvider>().allOreums;

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
                '오름 선택',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: oreums.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surface,
                          child: const Icon(Icons.all_inclusive, color: AppColors.primary),
                        ),
                        title: const Text('전체 오름'),
                        onTap: () {
                          _onOreumSelected(null, null);
                          Navigator.pop(context);
                        },
                      );
                    }
                    final oreum = oreums[index - 1];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surface,
                        child: const Icon(Icons.terrain, color: AppColors.primary),
                      ),
                      title: Text(oreum.name),
                      subtitle: oreum.difficulty != null
                          ? Text(oreum.difficulty!)
                          : null,
                      onTap: () {
                        _onOreumSelected(oreum.id, oreum.name);
                        Navigator.pop(context);
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            '아직 게시글이 없습니다',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            '첫 번째 글을 작성해보세요!',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    return GestureDetector(
      onTap: () => _showPostDetail(post),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 헤더
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                    ),
                    child: post.userProfileImage != null
                        ? ClipOval(
                            child: Image.network(
                              post.userProfileImage!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.person, color: AppColors.textSecondary),
                                );
                              },
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.person, color: AppColors.textSecondary),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              post.userNickname ?? '익명',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Lv.${post.userLevel}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          post.timeAgo,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (post.oreumName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.terrain, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            post.oreumName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // 내용
              Text(
                post.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              // 이미지 (있을 경우)
              if (post.images.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    post.images.first,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: AppColors.surface,
                      child: const Center(
                        child: Icon(Icons.image, size: 48, color: AppColors.textHint),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // 좋아요, 댓글, 공유
              Consumer<CommunityProvider>(
                builder: (context, provider, _) {
                  final isLiked = provider.isLiked(post.id);
                  return Row(
                    children: [
                      _buildActionButton(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        '${post.likeCount}',
                        isLiked ? Colors.red : AppColors.textSecondary,
                        () => provider.toggleLike(post.id),
                      ),
                      const SizedBox(width: 16),
                      _buildActionButton(
                        Icons.chat_bubble_outline,
                        '${post.commentCount}',
                        AppColors.textSecondary,
                        () => _showPostDetail(post),
                      ),
                      const SizedBox(width: 16),
                      _buildActionButton(
                        Icons.share_outlined,
                        '',
                        AppColors.textSecondary,
                        () => _sharePost(post),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String count,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }

  void _showPostDetail(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: post),
      ),
    );
  }

  void _sharePost(PostModel post) {
    String shareText = '';
    if (post.oreumName != null) {
      shareText = '[제주오름] ${post.oreumName}\n\n';
    }
    shareText += post.content;
    shareText += '\n\n#제주오름 #오름탐험';

    Share.share(shareText);
  }

  void _showWritePostDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isLoggedIn) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('로그인 필요'),
          content: const Text('글을 작성하려면 로그인이 필요합니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
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
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => WritePostSheet(
        onSubmit: (content, oreumId, oreumName, category, imageUrls) async {
          final provider = context.read<CommunityProvider>();
          final success = await provider.createPost(
            content: content,
            oreumId: oreumId,
            oreumName: oreumName,
            category: category,
            images: imageUrls,
            userNickname: authProvider.nickname ?? '익명',
          );

          if (success && mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('글이 작성되었습니다')),
            );
          }
        },
      ),
    );
  }
}

// 글쓰기 시트
class WritePostSheet extends StatefulWidget {
  final Function(String content, String? oreumId, String? oreumName, String? category, List<String> imageUrls) onSubmit;

  const WritePostSheet({super.key, required this.onSubmit});

  @override
  State<WritePostSheet> createState() => _WritePostSheetState();
}

class _WritePostSheetState extends State<WritePostSheet> {
  final _contentController = TextEditingController();
  final _timeController = TextEditingController();
  final _communityService = CommunityService();
  final _imagePicker = ImagePicker();

  String? _selectedOreumId;
  String? _selectedOreumName;
  String _selectedCategory = '후기';
  String? _selectedDifficulty;
  final List<File> _selectedImages = [];
  bool _isUploading = false;

  // 카테고리 목록 (전체 제외)
  static const List<String> _categories = ['등반완료', '후기', '질문', '동행모집'];

  // 난이도 목록
  static const List<String> _difficulties = ['쉬움', '보통', '어려움'];

  @override
  void dispose() {
    _contentController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지는 최대 5개까지 첨부할 수 있습니다')),
      );
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        _selectedImages.add(File(picked.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitPost() async {
    if (_contentController.text.trim().isEmpty) return;

    // 콘텐츠 필터 체크
    final filterResult = ContentFilter.check(_contentController.text.trim());
    if (!filterResult.isClean) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(filterResult.message ?? '부적절한 표현이 포함되어 있습니다.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // 이미지 업로드
      final List<String> imageUrls = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final file = _selectedImages[i];
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        try {
          final url = await _communityService.uploadImage(file.path, fileName);
          imageUrls.add(url);
        } catch (e) {
          debugPrint('이미지 업로드 실패: $e');
        }
      }

      // 내용 구성 (난이도, 시간 정보 포함)
      String content = _contentController.text.trim();

      // 등반완료/후기 카테고리일 때 난이도, 시간 정보 추가
      if (_selectedCategory == '등반완료' || _selectedCategory == '후기') {
        final List<String> tags = [];
        if (_selectedDifficulty != null) {
          tags.add('난이도: $_selectedDifficulty');
        }
        if (_timeController.text.isNotEmpty) {
          tags.add('소요시간: ${_timeController.text}분');
        }
        if (tags.isNotEmpty) {
          content = '[${tags.join(' | ')}]\n\n$content';
        }
      }

      widget.onSubmit(
        content,
        _selectedOreumId,
        _selectedOreumName,
        _selectedCategory,
        imageUrls,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '새 글 작성',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 카테고리 선택
              const Text(
                '카테고리',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 오름 선택
              GestureDetector(
                onTap: () => _showOreumPicker(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.terrain, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedOreumName ?? '오름 태그 (선택)',
                          style: TextStyle(
                            color: _selectedOreumName != null
                                ? AppColors.textPrimary
                                : AppColors.textHint,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedOreumName != null)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedOreumId = null;
                              _selectedOreumName = null;
                            });
                          },
                          child: const Icon(Icons.close, size: 18),
                        )
                      else
                        const Icon(Icons.chevron_right, color: AppColors.textHint),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 난이도 & 소요시간 (등반완료, 후기 카테고리일 때만)
              if (_selectedCategory == '등반완료' || _selectedCategory == '후기') ...[
                Row(
                  children: [
                    // 난이도 선택
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '난이도',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedDifficulty,
                                hint: const Text('선택'),
                                isExpanded: true,
                                items: _difficulties.map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d),
                                )).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedDifficulty = value;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 소요시간 입력
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '소요시간',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _timeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '분 단위',
                              suffixText: '분',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 내용 입력
              TextField(
                controller: _contentController,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: '오름 탐방 경험을 공유해보세요...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // 이미지 첨부 영역
              Row(
                children: [
                  const Text(
                    '사진 첨부',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${_selectedImages.length}/5)',
                    style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // 이미지 추가 버튼
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border, width: 2),
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.surface,
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, color: AppColors.textHint, size: 28),
                            SizedBox(height: 4),
                            Text('추가', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                          ],
                        ),
                      ),
                    ),
                    // 선택된 이미지들
                    ..._selectedImages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      return Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(file),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 작성 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _contentController.text.trim().isNotEmpty && !_isUploading
                      ? _submitPost
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('작성하기'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showOreumPicker() {
    final oreums = context.read<OreumProvider>().oreums;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _OreumSearchSheet(
          oreums: oreums,
          onSelect: (oreum) {
            setState(() {
              _selectedOreumId = oreum.id;
              _selectedOreumName = oreum.name;
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

// 오름 검색 시트
class _OreumSearchSheet extends StatefulWidget {
  final List<dynamic> oreums;
  final Function(dynamic oreum) onSelect;

  const _OreumSearchSheet({
    required this.oreums,
    required this.onSelect,
  });

  @override
  State<_OreumSearchSheet> createState() => _OreumSearchSheetState();
}

class _OreumSearchSheetState extends State<_OreumSearchSheet> {
  final _searchController = TextEditingController();
  List<dynamic> _filteredOreums = [];

  @override
  void initState() {
    super.initState();
    _filteredOreums = widget.oreums;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredOreums = widget.oreums;
      } else {
        _filteredOreums = widget.oreums
            .where((oreum) => oreum.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
            '오름 선택',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // 검색창
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '오름 이름 검색...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          // 검색 결과 수
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_filteredOreums.length}개의 오름',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          // 오름 목록
          Expanded(
            child: _filteredOreums.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: AppColors.textHint),
                        const SizedBox(height: 8),
                        const Text(
                          '검색 결과가 없습니다',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredOreums.length,
                    itemBuilder: (context, index) {
                      final oreum = _filteredOreums[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surface,
                          child: const Icon(Icons.terrain, color: AppColors.primary),
                        ),
                        title: Text(oreum.name),
                        subtitle: oreum.difficulty != null
                            ? Text(oreum.difficulty!)
                            : null,
                        onTap: () => widget.onSelect(oreum),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// 게시글 상세 화면
class PostDetailScreen extends StatefulWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityProvider>().loadComments(widget.post.id);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isMyPost = authProvider.user?.id == widget.post.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글'),
        actions: [
          // 공유 버튼
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _sharePost,
          ),
          // 더보기 메뉴
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteConfirmDialog();
              } else if (value == 'report') {
                _showReportDialog(context, 'post', widget.post.id);
              } else if (value == 'block') {
                _showBlockConfirmDialog(
                  context,
                  widget.post.userId,
                  widget.post.userNickname ?? '익명',
                );
              }
            },
            itemBuilder: (context) => [
              if (isMyPost)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('삭제하기', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              if (!isMyPost) ...[
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Text('신고하기'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.red),
                      SizedBox(width: 8),
                      Text('차단하기', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 작성자 정보
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                        ),
                        child: widget.post.userProfileImage != null
                            ? ClipOval(
                                child: Image.network(
                                  widget.post.userProfileImage!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(Icons.person, color: AppColors.textSecondary),
                                    );
                                  },
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.person, color: AppColors.textSecondary),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.post.userNickname ?? '익명',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Lv.${widget.post.userLevel}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            widget.post.timeAgo,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 오름 태그
                  if (widget.post.oreumName != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.terrain, size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            widget.post.oreumName!,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 내용
                  Text(
                    widget.post.content,
                    style: const TextStyle(fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  // 좋아요, 댓글 수, 공유
                  Consumer<CommunityProvider>(
                    builder: (context, provider, _) {
                      final isLiked = provider.isLiked(widget.post.id);
                      return Row(
                        children: [
                          GestureDetector(
                            onTap: () => provider.toggleLike(widget.post.id),
                            child: Row(
                              children: [
                                Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: isLiked ? Colors.red : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.post.likeCount}',
                                  style: TextStyle(
                                    color: isLiked ? Colors.red : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Icon(Icons.chat_bubble_outline, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.post.commentCount}',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _sharePost(),
                            child: const Icon(
                              Icons.share_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 32),
                  // 댓글 섹션
                  const Text(
                    '댓글',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Consumer<CommunityProvider>(
                    builder: (context, provider, _) {
                      if (provider.comments.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              '아직 댓글이 없습니다',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: provider.comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final comment = provider.comments[index];
                          return _buildCommentItem(comment);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // 댓글 입력
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommentModel comment) {
    final authProvider = context.read<AuthProvider>();
    final isMyComment = authProvider.user?.id == comment.userId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.surface,
          child: const Icon(Icons.person, size: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment.userNickname ?? '익명',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    comment.timeAgo,
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                comment.content,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, size: 16, color: AppColors.textHint),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onSelected: (value) {
            if (value == 'delete') {
              _deleteComment(comment);
            } else if (value == 'report') {
              _showReportDialog(context, 'comment', comment.id);
            } else if (value == 'block') {
              _showBlockConfirmDialog(
                context,
                comment.userId,
                comment.userNickname ?? '익명',
              );
            }
          },
          itemBuilder: (context) => [
            if (isMyComment)
              const PopupMenuItem(
                value: 'delete',
                child: Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            if (!isMyComment) ...[
              const PopupMenuItem(
                value: 'report',
                child: Text('신고하기'),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Text('차단하기', style: TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _deleteComment(CommentModel comment) async {
    final provider = context.read<CommunityProvider>();
    try {
      await CommunityService().deleteComment(comment.id, widget.post.id);
      await provider.loadComments(widget.post.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글 삭제에 실패했습니다')),
        );
      }
    }
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: '댓글을 입력하세요...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _commentController.text.trim().isNotEmpty
                  ? () => _submitComment()
                  : null,
              icon: Icon(
                Icons.send,
                color: _commentController.text.trim().isNotEmpty
                    ? AppColors.primary
                    : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitComment() async {
    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글을 작성하려면 로그인이 필요합니다')),
      );
      return;
    }

    // 콘텐츠 필터 체크
    final filterResult = ContentFilter.check(_commentController.text.trim());
    if (!filterResult.isClean) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(filterResult.message ?? '부적절한 표현이 포함되어 있습니다.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final provider = context.read<CommunityProvider>();
    final success = await provider.addComment(
      postId: widget.post.id,
      content: _commentController.text.trim(),
      userNickname: authProvider.nickname ?? '익명',
    );

    if (success) {
      _commentController.clear();
      setState(() {});
    }
  }

  void _sharePost() {
    String shareText = '';
    if (widget.post.oreumName != null) {
      shareText = '[제주오름] ${widget.post.oreumName}\n\n';
    }
    shareText += widget.post.content;
    shareText += '\n\n#제주오름 #오름탐험';

    Share.share(shareText);
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('게시글 삭제'),
        content: const Text('이 게시글을 삭제하시겠습니까?\n삭제된 글은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // 다이얼로그 닫기
              final provider = context.read<CommunityProvider>();
              final success = await provider.deletePost(widget.post.id);
              if (success && mounted) {
                Navigator.pop(context); // 상세 화면 닫기
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('게시글이 삭제되었습니다')),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('삭제에 실패했습니다')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext ctx, String targetType, String targetId) {
    String? selectedReason;
    final reasons = ReportService.reportReasons;

    showDialog(
      context: ctx,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('신고하기'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '신고 사유를 선택해주세요.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ...reasons.entries.map((entry) => RadioListTile<String>(
                  title: Text(entry.value, style: const TextStyle(fontSize: 14)),
                  value: entry.key,
                  groupValue: selectedReason,
                  activeColor: AppColors.primary,
                  onChanged: (value) => setDialogState(() => selectedReason = value),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      try {
                        final reportService = ReportService();
                        if (targetType == 'post') {
                          await reportService.reportPost(
                            postId: targetId,
                            reason: selectedReason!,
                          );
                        } else if (targetType == 'comment') {
                          await reportService.reportComment(
                            commentId: targetId,
                            reason: selectedReason!,
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('신고가 접수되었습니다. 검토 후 조치하겠습니다.')),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('신고 실패: $e')),
                          );
                        }
                      }
                    },
              child: const Text('신고'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmDialog(BuildContext ctx, String userId, String nickname) {
    showDialog(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('사용자 차단'),
        content: Text(
          '$nickname 님을 차단하시겠습니까?\n\n'
          '차단하면 해당 사용자의 게시글과 댓글이 보이지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final blockService = BlockService();
                final reportService = ReportService();

                // 차단 처리
                await blockService.blockUser(
                  blockedUserId: userId,
                  reason: '사용자가 직접 차단',
                );

                // 자동 신고 (Apple 요구사항: 차단 시 개발자에게 알림)
                await reportService.reportUser(
                  targetUserId: userId,
                  reason: 'user_blocked',
                  details: '$nickname 사용자를 차단함 (자동 신고)',
                );

                // Provider 업데이트 (즉시 피드에서 제거)
                if (ctx.mounted) {
                  ctx.read<CommunityProvider>().blockUser(userId);
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx); // 상세 화면 닫기
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('$nickname 님을 차단했습니다')),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('차단 실패: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('차단'),
          ),
        ],
      ),
    );
  }
}
