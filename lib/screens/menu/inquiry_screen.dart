import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/inquiry_service.dart';

class InquiryScreen extends StatefulWidget {
  final int initialTabIndex;
  const InquiryScreen({super.key, this.initialTabIndex = 0});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _emailController = TextEditingController();
  final InquiryService _inquiryService = InquiryService();
  String _selectedCategory = '앱 사용 문의';
  bool _isSubmitting = false;
  bool _isSubmittingSuggestion = false;

  // 건의사항 폼
  final _suggestionFormKey = GlobalKey<FormState>();
  final _suggestionTitleController = TextEditingController();
  final _suggestionContentController = TextEditingController();

  // 문의 이력
  List<Map<String, dynamic>> _myInquiries = [];
  bool _isLoadingInquiries = true;

  final List<String> _categories = [
    '앱 사용 문의',
    '오류 신고',
    '기능 제안',
    '계정 문의',
    '기타',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (_tabController.index == 2 && _isLoadingInquiries) {
        _loadMyInquiries();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _emailController.dispose();
    _suggestionTitleController.dispose();
    _suggestionContentController.dispose();
    super.dispose();
  }

  Future<void> _loadMyInquiries() async {
    try {
      final inquiries = await _inquiryService.getMyInquiries();
      if (mounted) {
        setState(() {
          _myInquiries = inquiries;
          _isLoadingInquiries = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInquiries = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('문의하기'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '문의 작성'),
            Tab(text: '건의사항'),
            Tab(text: '문의 이력'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInquiryForm(),
          _buildSuggestionForm(),
          _buildInquiryHistory(),
        ],
      ),
    );
  }

  Widget _buildInquiryForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내 문구
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '문의하신 내용은 영업일 기준 1~2일 내에 답변드립니다.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 문의 유형
            const Text(
              '문의 유형',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 20),

            // 이메일
            const Text(
              '이메일',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: '답변 받으실 이메일을 입력하세요',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '이메일을 입력해주세요';
                }
                if (!value.contains('@')) {
                  return '올바른 이메일 형식을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // 제목
            const Text(
              '제목',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '문의 제목을 입력하세요',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '제목을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // 내용
            const Text(
              '문의 내용',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contentController,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: '문의 내용을 자세히 입력해주세요',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '내용을 입력해주세요';
                }
                if (value.length < 10) {
                  return '10자 이상 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // 제출 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitInquiry,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('문의하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInquiryHistory() {
    if (_isLoadingInquiries) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myInquiries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '문의 이력이 없습니다',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isLoadingInquiries = true);
        await _loadMyInquiries();
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _myInquiries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final inquiry = _myInquiries[index];
          return _buildInquiryCard(inquiry);
        },
      ),
    );
  }

  Widget _buildInquiryCard(Map<String, dynamic> inquiry) {
    final status = inquiry['status'] as String? ?? 'pending';
    final createdAt = DateTime.tryParse(inquiry['created_at'] ?? '');
    final dateStr = createdAt != null
        ? '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}'
        : '';
    final answer = inquiry['answer'] as String?;

    Color statusColor;
    String statusText;
    switch (status) {
      case 'answered':
        statusColor = Colors.green;
        statusText = '답변완료';
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusText = '처리중';
        break;
      default:
        statusColor = Colors.grey;
        statusText = '접수';
    }

    return Container(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                inquiry['category'] ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            inquiry['title'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            inquiry['content'] ?? '',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (answer != null && answer.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.support_agent, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      Text(
                        '답변',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    answer,
                    style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _suggestionFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '서비스 개선을 위한 건의사항을 보내주세요!\n소중한 의견 감사합니다.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '제목',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _suggestionTitleController,
              decoration: const InputDecoration(
                hintText: '건의사항 제목을 입력하세요',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '제목을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            const Text(
              '건의 내용',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _suggestionContentController,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: '개선사항이나 추가했으면 하는 기능을 자세히 작성해주세요',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '내용을 입력해주세요';
                }
                if (value.length < 10) {
                  return '10자 이상 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingSuggestion ? null : _submitSuggestion,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmittingSuggestion
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('건의하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitSuggestion() async {
    if (_suggestionFormKey.currentState!.validate()) {
      setState(() => _isSubmittingSuggestion = true);

      try {
        await _inquiryService.createInquiry(
          category: '건의사항',
          email: '',
          title: _suggestionTitleController.text.trim(),
          content: _suggestionContentController.text.trim(),
        );

        if (!mounted) return;

        _suggestionTitleController.clear();
        _suggestionContentController.clear();
        setState(() => _isSubmittingSuggestion = false);

        _isLoadingInquiries = true;
        _loadMyInquiries();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('건의사항 접수 완료'),
            content: const Text('건의사항이 접수되었습니다.\n소중한 의견 감사합니다.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _tabController.animateTo(2);
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } catch (e) {
        debugPrint('에러: $e');
        setState(() => _isSubmittingSuggestion = false);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    }
  }

  Future<void> _submitInquiry() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        await _inquiryService.createInquiry(
          category: _selectedCategory,
          email: _emailController.text.trim(),
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
        );

        if (!mounted) return;

        // 폼 초기화
        _titleController.clear();
        _contentController.clear();
        setState(() => _isSubmitting = false);

        // 이력 새로고침
        _isLoadingInquiries = true;
        _loadMyInquiries();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('문의 접수 완료'),
            content: const Text('문의가 성공적으로 접수되었습니다.\n입력하신 이메일로 답변드리겠습니다.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // 이력 탭으로 이동
                  _tabController.animateTo(2);
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } catch (e) {
        debugPrint('에러: $e');
        setState(() => _isSubmitting = false);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    }
  }
}
