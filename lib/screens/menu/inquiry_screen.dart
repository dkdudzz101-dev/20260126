import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/inquiry_service.dart';

class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _isLoadingInquiries) {
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
            Tab(text: '문의 이력'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInquiryForm(),
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
                  _tabController.animateTo(1);
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
