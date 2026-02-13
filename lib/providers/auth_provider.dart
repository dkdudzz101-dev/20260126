import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
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
    _provider = 'kakao';
    _isLoggedIn = true;

    // 기본값 (소셜 로그인에서 받아온 값)
    String defaultNickname = user.userMetadata?['name'] ?? user.userMetadata?['full_name'] ?? '제주탐험가';
    String? defaultProfileImage = user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'];

    // DB에서 기존 사용자 정보 확인 (닉네임이 덮어씌워지는 것 방지)
    try {
      final existingUser = await _supabase
          .from('users')
          .select('nickname, profile_image')
          .eq('id', user.id)
          .maybeSingle();

      if (existingUser != null) {
        // 기존 사용자면 DB에 저장된 닉네임/프로필 유지
        _nickname = existingUser['nickname'] ?? defaultNickname;
        _profileImage = existingUser['profile_image'] ?? defaultProfileImage;
        debugPrint('기존 OAuth 사용자 - 닉네임 유지: $_nickname');
      } else {
        // 신규 사용자면 소셜 로그인 정보 사용
        _nickname = defaultNickname;
        _profileImage = defaultProfileImage;
        debugPrint('신규 OAuth 사용자 - 닉네임: $_nickname');
      }
    } catch (e) {
      debugPrint('OAuth 사용자 정보 조회 에러: $e');
      _nickname = defaultNickname;
      _profileImage = defaultProfileImage;
    }

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

  // 랜덤 문자열 생성 (nonce용)
  String _generateRandomString(int length) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  // SHA256 해시
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // 애플 로그인
  Future<bool> signInWithApple() async {
    try {
      debugPrint('=== 애플 로그인 시작 ===');

      // nonce 생성 (Supabase 인증에 필요)
      final rawNonce = _generateRandomString(32);
      final hashedNonce = _sha256ofString(rawNonce);

      // Apple 인증 요청 (타임아웃 추가)
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Apple 로그인 시간 초과');
        },
      );

      debugPrint('Apple credential 획득 성공');
      debugPrint('identityToken: ${credential.identityToken != null ? "있음" : "없음"}');
      debugPrint('authorizationCode: ${credential.authorizationCode.isNotEmpty ? "있음" : "없음"}');

      // identityToken 확인
      final idToken = credential.identityToken;
      if (idToken == null) {
        debugPrint('Apple identityToken이 null입니다');
        throw Exception('Apple identityToken을 받지 못했습니다');
      }

      // Supabase에 Apple ID Token으로 로그인
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      debugPrint('Supabase Apple 로그인 성공: ${response.user?.id}');

      if (response.user == null) {
        throw Exception('Supabase 사용자 정보를 받지 못했습니다');
      }

      // 사용자 정보 설정
      final user = response.user!;
      final odId = 'apple_${user.id}';
      final userEmail = user.email ?? credential.email ?? '$odId@apple.local';

      // Apple은 첫 로그인 시에만 이름 제공
      String fullName = '제주탐험가';
      if (credential.givenName != null) {
        fullName = '${credential.givenName} ${credential.familyName ?? ''}'.trim();
      }

      // 프로필 저장
      await _saveUserProfile(
        odId: odId,
        email: userEmail,
        nickname: fullName,
        profileImage: null,
        provider: 'apple',
      );

      debugPrint('=== 애플 로그인 완료 ===');
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('Apple 인증 예외: ${e.code} - ${e.message}');
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint('사용자가 Apple 로그인을 취소했습니다');
      }
      return false;
    } on TimeoutException catch (e) {
      debugPrint('Apple 로그인 타임아웃: $e');
      return false;
    } on AuthException catch (e) {
      debugPrint('Supabase Auth 에러: ${e.message}');
      return false;
    } catch (e, stackTrace) {
      debugPrint('=== 애플 로그인 에러 ===');
      debugPrint('에러: $e');
      debugPrint('스택: $stackTrace');
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

    // 기존 사용자인지 확인
    String finalNickname = nickname;
    String? finalProfileImage = profileImage;

    try {
      final existingUser = await _supabase
          .from('users')
          .select('nickname, profile_image')
          .eq('id', supabaseUserId)
          .maybeSingle();

      if (existingUser != null) {
        // 기존 사용자면 DB에 저장된 닉네임/프로필 유지
        finalNickname = existingUser['nickname'] ?? nickname;
        finalProfileImage = existingUser['profile_image'] ?? profileImage;
        debugPrint('기존 사용자 - 닉네임 유지: $finalNickname');
      } else {
        // 신규 사용자면 새로 저장
        await _supabase.from('users').insert({
          'id': supabaseUserId,
          'email': email,
          'nickname': nickname,
          'profile_image': profileImage,
          'provider': provider,
        });
        debugPrint('신규 사용자 프로필 저장 성공');
      }
    } catch (e) {
      debugPrint('사용자 프로필 처리 에러: $e');
    }

    // 로컬 저장
    _odId = odId;
    _nickname = finalNickname;
    _email = email;
    _profileImage = finalProfileImage;
    _provider = provider;
    _isLoggedIn = true;

    await _storage.write(key: 'odId', value: odId);
    await _storage.write(key: 'nickname', value: finalNickname);
    await _storage.write(key: 'email', value: email);
    await _storage.write(key: 'profileImage', value: finalProfileImage);
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

  // 닉네임 중복 확인
  Future<bool> checkNicknameExists(String nickname) async {
    try {
      final result = await _supabase
          .from('users')
          .select('id')
          .eq('nickname', nickname)
          .maybeSingle();
      return result != null;
    } catch (e) {
      debugPrint('닉네임 중복 확인 에러: $e');
      return false; // 에러 시 일단 통과 (가입 시도 허용)
    }
  }

  // 이메일 중복 확인
  Future<bool> checkEmailExists(String email) async {
    try {
      final result = await _supabase
          .from('users')
          .select('id')
          .eq('real_email', email)
          .maybeSingle();
      return result != null;
    } catch (e) {
      debugPrint('이메일 중복 확인 에러: $e');
      return false;
    }
  }

  // 아이디/비밀번호 회원가입
  Future<Map<String, dynamic>> signUpWithId({
    required String userId,
    required String password,
    required String name,
    required String nickname,
    required String email,  // 실제 이메일 (비밀번호 찾기용)
    required DateTime birthDate,
  }) async {
    try {
      // 아이디를 이메일 형식으로 변환 (Supabase Auth용)
      final authEmail = '$userId@local.app';

      // 1. 닉네임 중복 확인
      final nicknameCheck = await checkNicknameExists(nickname);
      if (nicknameCheck) {
        return {'success': false, 'error': '이미 사용 중인 닉네임입니다.'};
      }

      // 2. 이메일 중복 확인
      final emailCheck = await checkEmailExists(email);
      if (emailCheck) {
        return {'success': false, 'error': '이미 사용 중인 이메일입니다.'};
      }

      // 3. 아이디 중복 확인
      try {
        await _supabase.auth.signInWithPassword(
          email: authEmail,
          password: password,
        );
        // 로그인 성공 = 이미 존재하는 아이디
        await _supabase.auth.signOut();
        return {'success': false, 'error': '이미 사용 중인 아이디입니다.'};
      } on AuthException catch (e) {
        if (!e.message.contains('Invalid login credentials')) {
          if (e.message.contains('Email not confirmed')) {
            debugPrint('이메일 미인증 상태, 회원가입 진행');
          } else {
            return {'success': false, 'error': '회원가입 중 오류가 발생했습니다.'};
          }
        }
      }

      // 회원가입
      final signUpResponse = await _supabase.auth.signUp(
        email: authEmail,
        password: password,
        emailRedirectTo: null,
      );

      if (signUpResponse.user == null) {
        return {'success': false, 'error': '회원가입에 실패했습니다.'};
      }

      // 회원가입 후 바로 로그인 시도
      try {
        await _supabase.auth.signInWithPassword(
          email: authEmail,
          password: password,
        );
      } on AuthException catch (e) {
        if (e.message.contains('Email not confirmed')) {
          debugPrint('이메일 확인 필요 - Supabase 설정 확인 필요');
          _odId = 'local_$userId';
          _email = authEmail;
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

      // 프로필 저장 (추가 정보 포함)
      await _saveUserProfileWithDetails(
        odId: 'local_$userId',
        authEmail: authEmail,
        realEmail: email,
        name: name,
        nickname: nickname,
        birthDate: birthDate,
        profileImage: null,
        provider: 'local',
      );

      return {'success': true};
    } catch (e) {
      debugPrint('회원가입 에러: $e');
      return {'success': false, 'error': '회원가입 중 오류가 발생했습니다.'};
    }
  }

  // 사용자 프로필 저장 (상세 정보 포함)
  Future<void> _saveUserProfileWithDetails({
    required String odId,
    required String authEmail,
    required String realEmail,
    required String name,
    required String nickname,
    required DateTime birthDate,
    String? profileImage,
    required String provider,
  }) async {
    final supabaseUserId = _supabase.auth.currentUser?.id;
    if (supabaseUserId == null) return;

    try {
      await _supabase.from('users').insert({
        'id': supabaseUserId,
        'email': authEmail,
        'real_email': realEmail,
        'name': name,
        'nickname': nickname,
        'birth_date': birthDate.toIso8601String().split('T')[0],
        'profile_image': profileImage,
        'provider': provider,
      });
      debugPrint('신규 사용자 프로필 저장 성공');
    } catch (e) {
      debugPrint('사용자 프로필 저장 에러: $e');
    }

    // 로컬 저장
    _odId = odId;
    _nickname = nickname;
    _email = authEmail;
    _profileImage = profileImage;
    _provider = provider;
    _isLoggedIn = true;

    await _storage.write(key: 'odId', value: odId);
    await _storage.write(key: 'nickname', value: nickname);
    await _storage.write(key: 'email', value: authEmail);
    await _storage.write(key: 'profileImage', value: profileImage);
    await _storage.write(key: 'provider', value: provider);

    notifyListeners();
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
  Future<Map<String, dynamic>> updateProfile({String? nickname, String? profileImage, double? weight}) async {
    final supabaseUserId = _supabase.auth.currentUser?.id;

    // 닉네임 변경 시 중복 확인
    if (nickname != null && nickname != _nickname) {
      final exists = await checkNicknameExists(nickname);
      if (exists) {
        return {'success': false, 'error': '이미 사용 중인 닉네임입니다.'};
      }
    }

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
        return {'success': false, 'error': '프로필 업데이트 중 오류가 발생했습니다.'};
      }
    }

    notifyListeners();
    return {'success': true};
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
        // 차단 목록 삭제
        await _supabase.from('blocked_users').delete().eq('blocker_id', supabaseUserId);
        debugPrint('차단 목록 삭제 완료');
      } catch (e) {
        debugPrint('차단 목록 삭제 에러 (무시): $e');
      }

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
