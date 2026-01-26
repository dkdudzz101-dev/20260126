import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class UserInfo {
  final String id;
  final String? name;
  final String? email;
  final String? photoUrl;

  UserInfo({
    required this.id,
    this.name,
    this.email,
    this.photoUrl,
  });
}

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _odId;
  String? _nickname;
  String? _email;
  String? _profileImage;
  String? _provider;
  double? _weight; // 체중 (칼로리 계산용)

  final _storage = const FlutterSecureStorage();
  final _supabase = SupabaseConfig.client;

  // 비밀번호 생성용 시크릿 (실제 앱에서는 더 안전한 방법 사용)
  static const String _passwordSecret = 'jeju_oreum_app_2024!';

  bool get isLoggedIn => _isLoggedIn;
  String? get socialId => _odId;  // 소셜 로그인 ID (kakao_123, naver_456 등)
  String? get nickname => _nickname;
  String? get email => _email;
  String? get profileImage => _profileImage;
  String? get provider => _provider;
  double? get weight => _weight;

  // Supabase Auth의 UUID 가져오기 (DB에서 사용하는 ID)
  String? get userId => _supabase.auth.currentUser?.id;

  // User getter for compatibility
  UserInfo? get user => _isLoggedIn
      ? UserInfo(
          id: userId ?? _odId ?? '',
          name: _nickname,
          email: _email,
          photoUrl: _profileImage,
        )
      : null;

  // 앱 시작 시 저장된 로그인 정보 확인
  Future<void> checkLoginStatus() async {
    // Supabase 인증 상태 변경 리스너
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      debugPrint('Auth 상태 변경: $event');

      if (event == AuthChangeEvent.signedIn && session != null) {
        _handleOAuthSignIn(session);
      } else if (event == AuthChangeEvent.signedOut) {
        _isLoggedIn = false;
        _odId = null;
        _nickname = null;
        _email = null;
        _profileImage = null;
        _provider = null;
        notifyListeners();
      }
    });

    // Supabase 세션 확인
    final session = _supabase.auth.currentSession;
    if (session != null) {
      _odId = await _storage.read(key: 'odId');
      _nickname = await _storage.read(key: 'nickname');
      _email = await _storage.read(key: 'email');
      _profileImage = await _storage.read(key: 'profileImage');
      _provider = await _storage.read(key: 'provider');
      _isLoggedIn = true;
      notifyListeners();
      return;
    }

    // 로컬 저장소에서 복구 시도
    final savedodId = await _storage.read(key: 'odId');
    final savedProvider = await _storage.read(key: 'provider');
    final savedEmail = await _storage.read(key: 'email');

    if (savedodId != null && savedProvider != null && savedEmail != null) {
      // Supabase 재로그인 시도
      try {
        final password = _generatePassword(savedodId);
        await _supabase.auth.signInWithPassword(
          email: savedEmail,
          password: password,
        );

        _odId = savedodId;
        _nickname = await _storage.read(key: 'nickname');
        _email = savedEmail;
        _profileImage = await _storage.read(key: 'profileImage');
        _provider = savedProvider;
        _isLoggedIn = true;
        notifyListeners();
      } catch (e) {
        debugPrint('자동 로그인 실패: $e');
        await _storage.deleteAll();
      }
    }
  }

  // OAuth 로그인 완료 처리
  Future<void> _handleOAuthSignIn(Session session) async {
    final user = session.user;
    debugPrint('OAuth 로그인 완료: ${user.email}');

    _email = user.email;
    _odId = 'kakao_${user.id}';
    _nickname = user.userMetadata?['name'] ?? user.userMetadata?['full_name'] ?? '제주탐험가';
    _profileImage = user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'];
    _provider = 'kakao';
    _isLoggedIn = true;

    // 로컬 저장소에 저장
    await _storage.write(key: 'odId', value: _odId);
    await _storage.write(key: 'nickname', value: _nickname);
    await _storage.write(key: 'email', value: _email);
    await _storage.write(key: 'profileImage', value: _profileImage);
    await _storage.write(key: 'provider', value: _provider);

    notifyListeners();
  }

  // 비밀번호 생성 (소셜 ID 기반)
  String _generatePassword(String odId) {
    return '${odId}_$_passwordSecret';
  }

  // 카카오 로그인
  Future<bool> signInWithKakao() async {
    try {
      debugPrint('=== 카카오 로그인 시작 ===');

      // 딥링크 수신 준비
      final appLinks = AppLinks();
      Completer<String?> codeCompleter = Completer<String?>();
      StreamSubscription? linkSubscription;

      // 딥링크 리스너 설정
      linkSubscription = appLinks.uriLinkStream.listen((Uri? uri) {
        if (uri != null && uri.scheme.startsWith('kakao')) {
          final code = uri.queryParameters['code'];
          debugPrint('카카오 딥링크 수신: code=${code != null ? "있음" : "없음"}');
          if (!codeCompleter.isCompleted) {
            codeCompleter.complete(code);
          }
        }
      });

      // 카카오톡 설치 여부 확인
      bool loginSuccess = false;
      if (await kakao.isKakaoTalkInstalled()) {
        debugPrint('카카오톡 앱으로 로그인 시도...');
        try {
          await kakao.UserApi.instance.loginWithKakaoTalk();
          loginSuccess = true;
          debugPrint('카카오톡 로그인 성공');
        } catch (e) {
          debugPrint('카카오톡 로그인 실패: $e');
        }
      }

      // 카카오톡 로그인 실패했거나 설치 안됨 -> 웹 로그인
      if (!loginSuccess) {
        debugPrint('카카오 계정으로 로그인 시도...');
        try {
          // 웹 로그인 시작 (비동기로 브라우저 열림)
          kakao.UserApi.instance.loginWithKakaoAccount().catchError((e) {
            debugPrint('카카오 웹 로그인 에러 (예상됨): $e');
            throw e;
          });

          // 딥링크로 code 받기 대기 (최대 120초)
          debugPrint('딥링크 대기 중...');
          final code = await codeCompleter.future.timeout(
            const Duration(seconds: 120),
            onTimeout: () => null,
          );

          if (code != null) {
            debugPrint('Authorization code 수신 성공');
            // code로 토큰 교환
            loginSuccess = await _exchangeKakaoToken(code);
          } else {
            debugPrint('딥링크 타임아웃');
          }
        } catch (e) {
          debugPrint('카카오 웹 로그인 처리 에러: $e');
        }
      }

      // 리스너 정리
      await linkSubscription.cancel();

      if (!loginSuccess) {
        debugPrint('카카오 로그인 실패');
        return false;
      }

      debugPrint('카카오 토큰 획득 성공');

      final user = await kakao.UserApi.instance.me();
      debugPrint('카카오 사용자 정보: id=${user.id}');
      debugPrint('카카오 프로필: nickname=${user.kakaoAccount?.profile?.nickname}');
      debugPrint('카카오 프로필 이미지: ${user.kakaoAccount?.profile?.profileImageUrl}');
      debugPrint('카카오 썸네일 이미지: ${user.kakaoAccount?.profile?.thumbnailImageUrl}');

      final odId = 'kakao_${user.id}';
      final userEmail = user.kakaoAccount?.email ?? '$odId@kakao.local';
      final userNickname = user.kakaoAccount?.profile?.nickname ?? '제주탐험가';
      // 프로필 이미지가 없으면 썸네일 사용
      final userProfileImage = user.kakaoAccount?.profile?.profileImageUrl
          ?? user.kakaoAccount?.profile?.thumbnailImageUrl;

      // Supabase Auth에 등록/로그인
      final success = await _signInToSupabase(
        odId: odId,
        email: userEmail,
        nickname: userNickname,
        profileImage: userProfileImage,
        provider: 'kakao',
      );

      return success;
    } catch (e, stackTrace) {
      debugPrint('=== 카카오 로그인 에러 ===');
      debugPrint('에러: $e');
      debugPrint('스택: $stackTrace');
      return false;
    }
  }

  // 카카오 authorization code로 토큰 교환
  Future<bool> _exchangeKakaoToken(String code) async {
    try {
      const clientId = 'd4b730c14857dce93c9ba94e30f56260';
      const redirectUri = 'kakaod4b730c14857dce93c9ba94e30f56260://oauth';

      final response = await http.post(
        Uri.parse('https://kauth.kakao.com/oauth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'code': code,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];

        debugPrint('토큰 교환 성공');

        // 카카오 SDK 토큰 매니저에 저장
        final expiresAt = DateTime.now().add(Duration(seconds: data['expires_in'] ?? 3600));
        final refreshTokenExpiresAt = DateTime.now().add(Duration(seconds: data['refresh_token_expires_in'] ?? 5184000));
        final token = kakao.OAuthToken(
          accessToken,
          expiresAt,
          refreshToken,
          refreshTokenExpiresAt,
          data['scope']?.toString().split(' ') ?? [],
        );
        await kakao.TokenManagerProvider.instance.manager.setToken(token);

        return true;
      } else {
        debugPrint('토큰 교환 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('토큰 교환 에러: $e');
      return false;
    }
  }

  // 네이버 로그인
  Future<bool> signInWithNaver() async {
    try {
      final result = await FlutterNaverLogin.logIn();
      debugPrint('네이버 로그인 결과: ${result.status}');

      final account = result.account;
      if (account != null && (account.id?.isNotEmpty ?? false)) {
        final odId = 'naver_${account.id}';
        final userEmail = account.email?.isNotEmpty == true
            ? account.email!
            : '$odId@naver.local';
        final userNickname = account.nickname ?? '제주탐험가';
        final userProfileImage = account.profileImage;

        // Supabase Auth에 등록/로그인
        final success = await _signInToSupabase(
          odId: odId,
          email: userEmail,
          nickname: userNickname,
          profileImage: userProfileImage,
          provider: 'naver',
        );

        return success;
      }
      return false;
    } catch (e) {
      debugPrint('네이버 로그인 에러: $e');
      return false;
    }
  }

  // 애플 로그인
  Future<bool> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final odId = 'apple_${credential.userIdentifier}';
      final userEmail = credential.email ?? '$odId@apple.local';
      final fullName = credential.givenName != null
          ? '${credential.givenName} ${credential.familyName ?? ''}'.trim()
          : '제주탐험가';

      // Supabase Auth에 등록/로그인
      final success = await _signInToSupabase(
        odId: odId,
        email: userEmail,
        nickname: fullName,
        profileImage: null,
        provider: 'apple',
      );

      return success;
    } catch (e) {
      debugPrint('애플 로그인 에러: $e');
      return false;
    }
  }

  // Supabase Auth에 등록 또는 로그인
  Future<bool> _signInToSupabase({
    required String odId,
    required String email,
    required String nickname,
    String? profileImage,
    required String provider,
  }) async {
    final password = _generatePassword(odId);

    try {
      // 먼저 로그인 시도
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      debugPrint('Supabase 로그인 성공');
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        // 계정이 없으면 회원가입
        try {
          await _supabase.auth.signUp(
            email: email,
            password: password,
          );
          debugPrint('Supabase 회원가입 성공');
        } catch (signUpError) {
          debugPrint('Supabase 회원가입 에러: $signUpError');
          return false;
        }
      } else {
        debugPrint('Supabase 로그인 에러: ${e.message}');
        return false;
      }
    }

    // users 테이블에 프로필 저장
    await _saveUserProfile(
      odId: odId,
      email: email,
      nickname: nickname,
      profileImage: profileImage,
      provider: provider,
    );

    return true;
  }

  // 사용자 프로필 저장
  Future<void> _saveUserProfile({
    required String odId,
    required String email,
    required String nickname,
    String? profileImage,
    required String provider,
  }) async {
    final supabaseUserId = _supabase.auth.currentUser?.id;
    if (supabaseUserId == null) return;

    // Supabase users 테이블에 저장
    try {
      await _supabase.from('users').upsert({
        'id': supabaseUserId,
        'email': email,
        'nickname': nickname,
        'profile_image': profileImage,
        'provider': provider,
      });
      debugPrint('사용자 프로필 저장 성공');
    } catch (e) {
      debugPrint('사용자 프로필 저장 에러: $e');
    }

    // 로컬 저장
    _odId = odId;
    _nickname = nickname;
    _email = email;
    _profileImage = profileImage;
    _provider = provider;
    _isLoggedIn = true;

    await _storage.write(key: 'odId', value: odId);
    await _storage.write(key: 'nickname', value: nickname);
    await _storage.write(key: 'email', value: email);
    await _storage.write(key: 'profileImage', value: profileImage);
    await _storage.write(key: 'provider', value: provider);

    notifyListeners();
  }

  // 로그아웃
  Future<void> signOut() async => await logout();

  Future<void> logout() async {
    try {
      // 소셜 로그아웃
      if (_provider == 'kakao') {
        await kakao.UserApi.instance.logout();
      } else if (_provider == 'naver') {
        await FlutterNaverLogin.logOut();
      }

      // Supabase 로그아웃
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('로그아웃 에러: $e');
    }

    _isLoggedIn = false;
    _odId = null;
    _nickname = null;
    _email = null;
    _profileImage = null;
    _provider = null;

    await _storage.deleteAll();
    notifyListeners();
  }

  // 아이디/비밀번호 회원가입
  Future<Map<String, dynamic>> signUpWithId({
    required String userId,
    required String password,
    required String nickname,
  }) async {
    try {
      // 아이디를 이메일 형식으로 변환
      final email = '$userId@local.app';

      // 아이디 중복 확인
      try {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        // 로그인 성공 = 이미 존재하는 아이디
        await _supabase.auth.signOut();
        return {'success': false, 'error': '이미 사용 중인 아이디입니다.'};
      } on AuthException catch (e) {
        if (!e.message.contains('Invalid login credentials')) {
          // 이메일 미인증 오류일 수 있음
          if (e.message.contains('Email not confirmed')) {
            // 이미 가입되어 있지만 이메일 미인증 상태 - 재시도 가능
            debugPrint('이메일 미인증 상태, 회원가입 진행');
          } else {
            return {'success': false, 'error': '회원가입 중 오류가 발생했습니다.'};
          }
        }
      }

      // 회원가입
      final signUpResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: null, // 이메일 확인 리다이렉트 비활성화
      );

      // 회원가입 성공 여부 확인
      if (signUpResponse.user == null) {
        return {'success': false, 'error': '회원가입에 실패했습니다.'};
      }

      // 회원가입 후 바로 로그인 시도 (이메일 인증 없이 사용하기 위해)
      try {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } on AuthException catch (e) {
        if (e.message.contains('Email not confirmed')) {
          // Supabase에서 이메일 확인이 필요한 경우
          // Authentication > Providers > Email에서 "Confirm email" 비활성화 필요
          debugPrint('이메일 확인 필요 - Supabase 설정 확인 필요');
          // 그래도 로컬 로그인 처리
          _odId = 'local_$userId';
          _email = email;
          _nickname = nickname;
          _provider = 'local';
          _isLoggedIn = true;

          await _storage.write(key: 'odId', value: _odId);
          await _storage.write(key: 'email', value: _email);
          await _storage.write(key: 'nickname', value: _nickname);
          await _storage.write(key: 'provider', value: _provider);

          notifyListeners();
          return {'success': true, 'warning': '이메일 확인이 필요할 수 있습니다.'};
        }
        rethrow;
      }

      // 프로필 저장
      await _saveUserProfile(
        odId: 'local_$userId',
        email: email,
        nickname: nickname,
        profileImage: null,
        provider: 'local',
      );

      return {'success': true};
    } catch (e) {
      debugPrint('회원가입 에러: $e');
      return {'success': false, 'error': '회원가입 중 오류가 발생했습니다.'};
    }
  }

  // 아이디/비밀번호 로그인
  Future<Map<String, dynamic>> signInWithId({
    required String userId,
    required String password,
  }) async {
    try {
      final email = '$userId@local.app';

      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // 로컬 저장
      _odId = 'local_$userId';
      _email = email;
      _provider = 'local';
      _isLoggedIn = true;

      // users 테이블에서 닉네임 가져오기
      final supabaseUserId = _supabase.auth.currentUser?.id;
      if (supabaseUserId != null) {
        try {
          final userData = await _supabase
              .from('users')
              .select('nickname, profile_image')
              .eq('id', supabaseUserId)
              .single();
          _nickname = userData['nickname'];
          _profileImage = userData['profile_image'];
        } catch (e) {
          _nickname = '제주탐험가';
        }
      }

      await _storage.write(key: 'odId', value: _odId);
      await _storage.write(key: 'email', value: _email);
      await _storage.write(key: 'nickname', value: _nickname);
      await _storage.write(key: 'profileImage', value: _profileImage);
      await _storage.write(key: 'provider', value: _provider);

      notifyListeners();
      return {'success': true};
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        return {'success': false, 'error': '아이디 또는 비밀번호가 일치하지 않습니다.'};
      }
      if (e.message.contains('Email not confirmed')) {
        return {'success': false, 'error': '이메일 인증이 필요합니다. Supabase 대시보드에서 이메일 확인을 비활성화하세요.'};
      }
      return {'success': false, 'error': '로그인 중 오류가 발생했습니다.'};
    } catch (e) {
      debugPrint('로그인 에러: $e');
      return {'success': false, 'error': '로그인 중 오류가 발생했습니다.'};
    }
  }

  // 프로필 업데이트
  Future<void> updateProfile({String? nickname, String? profileImage, double? weight}) async {
    final supabaseUserId = _supabase.auth.currentUser?.id;

    if (nickname != null) {
      _nickname = nickname;
      await _storage.write(key: 'nickname', value: nickname);
    }
    if (profileImage != null) {
      _profileImage = profileImage;
      await _storage.write(key: 'profileImage', value: profileImage);
    }
    if (weight != null) {
      _weight = weight;
      await _storage.write(key: 'weight', value: weight.toString());
    }

    // Supabase에도 업데이트
    if (supabaseUserId != null) {
      try {
        await _supabase.from('users').update({
          if (nickname != null) 'nickname': nickname,
          if (profileImage != null) 'profile_image': profileImage,
          if (weight != null) 'weight': weight,
        }).eq('id', supabaseUserId);
      } catch (e) {
        debugPrint('프로필 업데이트 에러: $e');
      }
    }

    notifyListeners();
  }

  // 계정 삭제 (탈퇴)
  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final supabaseUserId = _supabase.auth.currentUser?.id;

      if (supabaseUserId == null) {
        return {'success': false, 'error': '로그인 상태가 아닙니다.'};
      }

      // 1. 관련 데이터 삭제 (stamps, hiking_logs, bookmarks 등)
      try {
        // 스탬프 삭제
        await _supabase.from('stamps').delete().eq('user_id', supabaseUserId);
        debugPrint('스탬프 삭제 완료');
      } catch (e) {
        debugPrint('스탬프 삭제 에러 (무시): $e');
      }

      try {
        // 등산 기록 삭제
        await _supabase.from('hiking_logs').delete().eq('user_id', supabaseUserId);
        debugPrint('등산 기록 삭제 완료');
      } catch (e) {
        debugPrint('등산 기록 삭제 에러 (무시): $e');
      }

      try {
        // 북마크 삭제
        await _supabase.from('bookmarks').delete().eq('user_id', supabaseUserId);
        debugPrint('북마크 삭제 완료');
      } catch (e) {
        debugPrint('북마크 삭제 에러 (무시): $e');
      }

      try {
        // 게시글 삭제
        await _supabase.from('posts').delete().eq('user_id', supabaseUserId);
        debugPrint('게시글 삭제 완료');
      } catch (e) {
        debugPrint('게시글 삭제 에러 (무시): $e');
      }

      try {
        // 댓글 삭제
        await _supabase.from('comments').delete().eq('user_id', supabaseUserId);
        debugPrint('댓글 삭제 완료');
      } catch (e) {
        debugPrint('댓글 삭제 에러 (무시): $e');
      }

      try {
        // 등산 경로 삭제
        await _supabase.from('hiking_routes').delete().eq('user_id', supabaseUserId);
        debugPrint('등산 경로 삭제 완료');
      } catch (e) {
        debugPrint('등산 경로 삭제 에러 (무시): $e');
      }

      // 2. users 테이블에서 삭제
      try {
        await _supabase.from('users').delete().eq('id', supabaseUserId);
        debugPrint('사용자 정보 삭제 완료');
      } catch (e) {
        debugPrint('사용자 정보 삭제 에러 (무시): $e');
      }

      // 3. 소셜 로그아웃
      if (_provider == 'kakao') {
        try {
          await kakao.UserApi.instance.unlink(); // 카카오 연결 해제
        } catch (e) {
          debugPrint('카카오 연결 해제 에러: $e');
        }
      } else if (_provider == 'naver') {
        try {
          await FlutterNaverLogin.logOutAndDeleteToken(); // 네이버 토큰 삭제
        } catch (e) {
          debugPrint('네이버 토큰 삭제 에러: $e');
        }
      }

      // 4. Supabase Auth 로그아웃
      await _supabase.auth.signOut();

      // 5. 로컬 상태 초기화
      _isLoggedIn = false;
      _odId = null;
      _nickname = null;
      _email = null;
      _profileImage = null;
      _provider = null;
      _weight = null;

      await _storage.deleteAll();
      notifyListeners();

      debugPrint('계정 탈퇴 완료');
      return {'success': true};
    } catch (e) {
      debugPrint('계정 탈퇴 에러: $e');
      return {'success': false, 'error': '계정 탈퇴 중 오류가 발생했습니다.'};
    }
  }

  // 체중 로드 (DB에서)
  Future<void> loadWeight() async {
    // 로컬 스토리지에서 먼저 로드
    final savedWeight = await _storage.read(key: 'weight');
    if (savedWeight != null) {
      _weight = double.tryParse(savedWeight);
    }

    // DB에서 로드
    final supabaseUserId = _supabase.auth.currentUser?.id;
    if (supabaseUserId != null) {
      try {
        final userData = await _supabase
            .from('users')
            .select('weight')
            .eq('id', supabaseUserId)
            .maybeSingle();
        if (userData != null && userData['weight'] != null) {
          _weight = (userData['weight'] as num).toDouble();
          await _storage.write(key: 'weight', value: _weight.toString());
        }
      } catch (e) {
        debugPrint('체중 로드 에러: $e');
      }
    }
    notifyListeners();
  }
}
