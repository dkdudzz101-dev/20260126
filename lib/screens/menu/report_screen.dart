import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/report_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final ReportService _reportService = ReportService();
  String _selectedType = '부적절한 게시물';
  bool _isSubmitting = false;

  // 신고 이력
  List<Map<String, dynamic>> _myReports = [];
  bool _isLoadingReports = true;

  final List<Map<String, dynamic>> _reportTypes = [
    {'type': '부적절한 게시물', 'icon': Icons.article_outlined},
    {'type': '스팸/광고', 'icon': Icons.campaign_outlined},
    {'type': '욕설/비방', 'icon': Icons.sentiment_very_dissatisfied_outlined},
    {'type': '잘못된 정보', 'icon': Icons.error_outline},
    {'type': '저작권 침해', 'icon': Icons.copyright_outlined},
    {'type': '기타', 'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _isLoadingReports) {
        _loadMyReports();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadMyReports() async {
    try {
      final reports = await _reportService.getMyReports();
      if (mounted) {
        setState(() {
          _myReports = reports;
          _isLoadingReports = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReports = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('신고하기'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '신고 작성'),
            Tab(text: '신고 이력'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportForm(),
          _buildReportHistory(),
        ],
      ),
    );
  }

  Widget _buildReportForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_outlined, color: Colors.red),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '허위 신고 시 서비스 이용이 제한될 수 있습니다.',
                      style: TextStyle(fontSize: 13, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 신고 유형
            const Text(
              '신고 유형',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...(_reportTypes.map((item) => _buildReportTypeItem(item))),
            const SizedBox(height: 24),

            // 상세 내용
            const Text(
              '상세 내용',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contentController,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: '신고 내용을 자세히 작성해주세요',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '신고 내용을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // 제출 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('신고하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportHistory() {
    if (_isLoadingReports) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myReports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '신고 이력이 없습니다',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isLoadingReports = true);
        await _loadMyReports();
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _myReports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildReportCard(_myReports[index]);
        },
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final status = report['status'] as String? ?? 'pending';
    final createdAt = DateTime.tryParse(report['created_at'] ?? '');
    final dateStr = createdAt != null
        ? '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}'
        : '';
    final answer = report['answer'] as String?;

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
              const Spacer(),
              Text(
                dateStr,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            report['reason'] ?? '',
            style: const TextStyle(fontSize: 13),
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

  Widget _buildReportTypeItem(Map<String, dynamic> item) {
    final isSelected = _selectedType == item['type'];
    return GestureDetector(
      onTap: () => setState(() => _selectedType = item['type']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              item['icon'],
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item['type'],
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        await _reportService.reportGeneral(
          reason: _selectedType,
          details: _contentController.text.trim(),
        );

        if (!mounted) return;

        _contentController.clear();
        setState(() => _isSubmitting = false);

        _isLoadingReports = true;
        _loadMyReports();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('신고 접수 완료'),
            content: const Text('신고가 접수되었습니다.\n검토 후 조치하겠습니다.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
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
