import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../theme/app_colors.dart';

class LoginGuard {
  /// 로그인 필요한 기능 실행 전 체크. 로그인 안 되어 있으면 다이얼로그 표시.
  /// 로그인 되어 있으면 true 반환.
  static bool check(BuildContext context, {String? message}) {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isLoggedIn) return true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text('로그인 필요'),
          ],
        ),
        content: Text(message ?? '이 기능을 사용하려면 로그인이 필요합니다.\n로그인 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
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
    return false;
  }
}
