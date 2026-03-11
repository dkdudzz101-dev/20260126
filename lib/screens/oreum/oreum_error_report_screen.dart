import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import '../../models/oreum_model.dart';
import '../../services/report_service.dart';
import '../../services/map_service.dart';

class OreumErrorReportScreen extends StatefulWidget {
  final OreumModel oreum;
  final double? initialLatitude;
  final double? initialLongitude;

  const OreumErrorReportScreen({
    super.key,
    required this.oreum,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<OreumErrorReportScreen> createState() => _OreumErrorReportScreenState();
}

class _OreumErrorReportScreenState extends State<OreumErrorReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final ReportService _reportService = ReportService();

  String _selectedErrorType = '입구 좌표 오류';
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _errorTypes = [
    {'type': '입구 좌표 오류', 'icon': Icons.location_on_outlined},
    {'type': '정상 좌표 오류', 'icon': Icons.flag_outlined},
    {'type': '화장실 정보 오류', 'icon': Icons.wc_outlined},
    {'type': '주차장 정보 오류', 'icon': Icons.local_parking_outlined},
    {'type': '등산로 오류', 'icon': Icons.hiking_outlined},
    {'type': '기타', 'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
    // 위치는 사용자가 '현재 위치 가져오기' 버튼을 눌렀을 때만 요청
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
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

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } catch (e) {
      debugPrint('에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치를 가져올 수 없습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('정보 제보'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 오름 정보
              _buildOreumInfoCard(),
              const SizedBox(height: 24),

              // 오류 유형 선택
              const Text(
                '오류 유형',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ...(_errorTypes.map((item) => _buildErrorTypeItem(item))),
              const SizedBox(height: 24),

              // 현재 GPS 위치
              _buildLocationSection(),
              const SizedBox(height: 24),

              // 상세 설명
              const Text(
                '상세 설명',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _detailsController,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: '오류 내용을 자세히 작성해주세요',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '오류 내용을 입력해주세요';
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
                    backgroundColor: AppColors.primary,
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
                      : const Text('제보하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOreumInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.oreum.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.oreum.startLat != null && widget.oreum.startLng != null)
            Text(
              '입구 좌표: ${widget.oreum.startLat!.toStringAsFixed(6)}, ${widget.oreum.startLng!.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          if (widget.oreum.summitLat != null && widget.oreum.summitLng != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '정상 좌표: ${widget.oreum.summitLat!.toStringAsFixed(6)}, ${widget.oreum.summitLng!.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          if (widget.oreum.parking != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '주차장: ${widget.oreum.parking}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          if (widget.oreum.restroom != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '화장실: ${widget.oreum.restroom}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorTypeItem(Map<String, dynamic> item) {
    final isSelected = _selectedErrorType == item['type'];
    return GestureDetector(
      onTap: () => setState(() => _selectedErrorType = item['type']),
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

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '현재 GPS 위치',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              icon: _isLoadingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(_isLoadingLocation ? '가져오는 중...' : '현재 위치 가져오기'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: _latitude != null && _longitude != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '위도: ${_latitude!.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '경도: ${_longitude!.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                )
              : const Text(
                  '위치 정보를 가져올 수 없습니다',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
        ),
      ],
    );
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        await _reportService.reportOreumInfo(
          oreumId: widget.oreum.id,
          oreumName: widget.oreum.name,
          errorType: _selectedErrorType,
          details: _detailsController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
        );

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('제보 접수 완료'),
            content: const Text('제보가 접수되었습니다.\n확인 후 수정하겠습니다. 감사합니다.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
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
