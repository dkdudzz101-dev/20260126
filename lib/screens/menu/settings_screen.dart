import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationEnabled = true;
  bool _locationEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoPlayEnabled = true;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          // 알림 설정
          _buildSectionHeader('알림'),
          _buildSwitchTile(
            icon: Icons.notifications_outlined,
            title: '푸시 알림',
            subtitle: '새로운 소식, 이벤트 알림을 받습니다',
            value: _notificationEnabled,
            onChanged: (value) => setState(() => _notificationEnabled = value),
          ),
          const Divider(height: 1),

          // 위치 설정
          _buildSectionHeader('위치'),
          _buildSwitchTile(
            icon: Icons.location_on_outlined,
            title: '위치 서비스',
            subtitle: 'GPS 스탬프 인증에 필요합니다',
            value: _locationEnabled,
            onChanged: (value) {
              setState(() => _locationEnabled = value);
              if (!value) {
                _showLocationWarning();
              }
            },
          ),
          const Divider(height: 1),

          // 화면 설정
          _buildSectionHeader('화면'),
          _buildSwitchTile(
            icon: Icons.dark_mode_outlined,
            title: '다크 모드',
            subtitle: '어두운 테마를 사용합니다',
            value: _darkModeEnabled,
            onChanged: (value) {
              setState(() => _darkModeEnabled = value);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('다크 모드 기능 준비 중입니다')),
              );
            },
          ),
          _buildSwitchTile(
            icon: Icons.play_circle_outline,
            title: '자동 재생',
            subtitle: '영상/애니메이션 자동 재생',
            value: _autoPlayEnabled,
            onChanged: (value) => setState(() => _autoPlayEnabled = value),
          ),
          const Divider(height: 1),

          // 데이터 관리
          _buildSectionHeader('데이터'),
          _buildActionTile(
            icon: Icons.cached,
            title: '캐시 삭제',
            subtitle: '임시 저장된 데이터를 삭제합니다',
            onTap: _clearCache,
          ),
          _buildActionTile(
            icon: Icons.download_outlined,
            title: '오프라인 데이터',
            subtitle: '오름 정보를 기기에 저장합니다',
            onTap: _downloadOfflineData,
          ),
          const Divider(height: 1),

          // 앱 정보
          _buildSectionHeader('앱 정보'),
          _buildActionTile(
            icon: Icons.info_outline,
            title: '버전 정보',
            subtitle: 'v1.0.0',
            onTap: _showVersionInfo,
          ),
          _buildActionTile(
            icon: Icons.update,
            title: '업데이트 확인',
            subtitle: '최신 버전을 확인합니다',
            onTap: _checkUpdate,
          ),
          _buildActionTile(
            icon: Icons.star_outline,
            title: '앱 평가하기',
            subtitle: '스토어에서 앱을 평가해주세요',
            onTap: _rateApp,
          ),
          const Divider(height: 1),

          // 계정 (로그인 시에만)
          if (authProvider.isLoggedIn) ...[
            _buildSectionHeader('계정'),
            _buildActionTile(
              icon: Icons.logout,
              title: '로그아웃',
              subtitle: '현재 계정에서 로그아웃합니다',
              onTap: () => _logout(context),
              isDestructive: false,
            ),
            _buildActionTile(
              icon: Icons.delete_forever_outlined,
              title: '계정 탈퇴',
              subtitle: '계정과 모든 데이터가 삭제됩니다',
              onTap: () => _deleteAccount(context),
              isDestructive: true,
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
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
        style: TextStyle(color: isDestructive ? Colors.red : null),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDestructive ? Colors.red.withOpacity(0.7) : null,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }

  void _showLocationWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 서비스 비활성화'),
        content: const Text('위치 서비스를 끄면 GPS 스탬프 인증 기능을 사용할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐시 삭제'),
        content: const Text('캐시를 삭제하시겠습니까?\n임시 저장된 이미지와 데이터가 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('캐시가 삭제되었습니다')),
              );
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _downloadOfflineData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오프라인 데이터'),
        content: const Text('오름 정보를 기기에 저장하시겠습니까?\n약 50MB의 저장 공간이 필요합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('오프라인 데이터 다운로드 기능 준비 중입니다')),
              );
            },
            child: const Text('다운로드'),
          ),
        ],
      ),
    );
  }

  void _showVersionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('제주오름'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.terrain, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('버전 1.0.0'),
            const SizedBox(height: 8),
            const Text(
              '제주의 아름다운 오름을 탐험하세요!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              '© 2024 제주오름',
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
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

  void _checkUpdate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('현재 최신 버전입니다')),
    );
  }

  void _rateApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('스토어 연결 기능 준비 중입니다')),
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
              Navigator.pop(context); // 설정 화면 닫기
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('로그아웃 되었습니다')),
              );
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('계정 탈퇴'),
        content: const Text(
          '정말 탈퇴하시겠습니까?\n\n모든 데이터(스탬프, 게시글 등)가 삭제되며 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);

              // 로딩 표시
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              // 계정 탈퇴 실행
              final result = await context.read<AuthProvider>().deleteAccount();

              if (!context.mounted) return;
              Navigator.pop(context); // 로딩 닫기

              if (result['success'] == true) {
                Navigator.pop(context); // 설정 화면 닫기
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('계정이 탈퇴되었습니다. 이용해주셔서 감사합니다.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['error'] ?? '탈퇴 처리 중 오류가 발생했습니다.')),
                );
              }
            },
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
  }
}
