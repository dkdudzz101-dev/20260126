import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'home/home_screen.dart';
import 'community/community_screen.dart';
import 'map/map_screen.dart';
import 'stamp/stamp_screen.dart';
import 'profile/profile_screen.dart';
import 'menu/inquiry_screen.dart';
import 'menu/report_screen.dart';
import 'menu/notice_screen.dart';
import 'menu/faq_screen.dart';
import 'menu/terms_screen.dart';
import 'menu/settings_screen.dart';
import '../theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/stamp_provider.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // 앱 시작 시 자동 로그인 체크 및 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final authProvider = context.read<AuthProvider>();
    final stampProvider = context.read<StampProvider>();

    // 자동 로그인 체크
    await authProvider.checkLoginStatus();

    // 로그인 상태면 스탬프 로드
    if (authProvider.isLoggedIn) {
      await stampProvider.loadStamps();
    }
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const CommunityScreen(),
    const MapScreen(),
    const StampScreen(),
    const ProfileScreen(),
  ];

  void openDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<bool> _showExitDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('앱 종료'),
        content: const Text('앱을 종료하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('종료'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitDialog();
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        body: IndexedStack(
        index: _currentIndex,
        children: _screens.map((screen) {
          if (screen is HomeScreen) {
            return HomeScreen(onMenuTap: openDrawer);
          }
          return screen;
        }).toList(),
      ),
      endDrawer: _buildDrawer(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: '커뮤니티',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined),
              activeIcon: Icon(Icons.location_on),
              label: '지도',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_stories_outlined),
              activeIcon: Icon(Icons.auto_stories),
              label: '스탬프북',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '내정보',
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '메뉴',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 메뉴 항목들
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    title: '문의하기',
                    onTap: () => _showPage(context, '문의하기'),
                  ),
                  _buildDrawerItem(
                    title: '신고하기',
                    onTap: () => _showPage(context, '신고하기'),
                  ),
                  _buildDrawerItem(
                    title: '공지사항',
                    onTap: () => _showPage(context, '공지사항'),
                  ),
                  _buildDrawerItem(
                    title: '자주 묻는 질문',
                    onTap: () => _showPage(context, '자주 묻는 질문'),
                  ),
                  _buildDrawerItem(
                    title: '이용약관',
                    onTap: () => _showPage(context, '이용약관'),
                  ),
                  _buildDrawerItem(
                    title: '설정',
                    onTap: () => _showPage(context, '설정'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 16),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showPage(BuildContext context, String title) {
    Widget page;
    switch (title) {
      case '문의하기':
        page = const InquiryScreen();
        break;
      case '신고하기':
        page = const ReportScreen();
        break;
      case '공지사항':
        page = const NoticeScreen();
        break;
      case '자주 묻는 질문':
        page = const FaqScreen();
        break;
      case '이용약관':
        page = const TermsScreen();
        break;
      case '설정':
        page = const SettingsScreen();
        break;
      default:
        page = const Scaffold(body: Center(child: Text('페이지를 찾을 수 없습니다')));
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }
}
