import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../main_tab_screen.dart';
import '../menu/terms_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();

  final _otpController = TextEditingController();

  DateTime? _birthDate;
  final _birthController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _agreeTerms = false;
  bool _agreePrivacy = false;

  // 이메일 OTP 관련
  bool _otpSent = false;
  bool _emailVerified = false;
  bool _otpSending = false;
  bool _otpVerifying = false;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _birthController.dispose();
    super.dispose();
  }

  void _onBirthDateChanged(String value) {
    // 자동 포맷팅: 숫자만 추출 후 YYYY/MM/DD 형식으로
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    String formatted = '';

    for (int i = 0; i < digits.length && i < 8; i++) {
      if (i == 4 || i == 6) formatted += '/';
      formatted += digits[i];
    }

    if (formatted != value) {
      _birthController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    // 8자리 완성되면 날짜 파싱
    if (digits.length == 8) {
      final year = int.tryParse(digits.substring(0, 4));
      final month = int.tryParse(digits.substring(4, 6));
      final day = int.tryParse(digits.substring(6, 8));

      if (year != null && month != null && day != null &&
          month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        try {
          final date = DateTime(year, month, day);
          if (date.isBefore(DateTime.now()) && date.isAfter(DateTime(1900))) {
            setState(() => _birthDate = date);
            return;
          }
        } catch (_) {}
      }
      setState(() => _birthDate = null);
    } else {
      setState(() => _birthDate = null);
    }
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthController.text = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 이메일을 입력해주세요')),
      );
      return;
    }

    setState(() => _otpSending = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.sendEmailOtp(email);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _otpSent = true;
          _emailVerified = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증번호가 이메일로 발송되었습니다')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? '인증번호 발송 실패')),
        );
      }
    } finally {
      if (mounted) setState(() => _otpSending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6자리 인증번호를 입력해주세요')),
      );
      return;
    }

    setState(() => _otpVerifying = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.verifyEmailOtp(
        _emailController.text.trim(),
        code,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() => _emailVerified = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이메일 인증 완료!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? '인증 실패')),
        );
      }
    } finally {
      if (mounted) setState(() => _otpVerifying = false);
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    // 생년월일 확인
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생년월일을 선택해주세요')),
      );
      return;
    }

    // 약관 동의 확인
    if (!_agreeTerms || !_agreePrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이용약관과 개인정보처리방침에 동의해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.signUpWithId(
        userId: _userIdController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        nickname: _nicknameController.text.trim(),
        email: _emailController.text.trim(),
        birthDate: _birthDate!,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 성공!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainTabScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? '회원가입 실패')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '회원가입',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // 아이디
                _buildLabel('아이디'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _userIdController,
                  decoration: _inputDecoration('아이디를 입력하세요'),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '아이디를 입력하세요';
                    }
                    if (value.trim().length < 4) {
                      return '아이디는 4자 이상이어야 합니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 비밀번호
                _buildLabel('비밀번호'),
                const Text(
                  '8자 이상, 영문+숫자 조합',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration('비밀번호를 입력하세요').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return '비밀번호를 입력하세요';
                    if (value.length < 8) return '비밀번호는 8자 이상이어야 합니다';
                    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) return '영문자를 포함해야 합니다';
                    if (!RegExp(r'[0-9]').hasMatch(value)) return '숫자를 포함해야 합니다';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 비밀번호 확인
                _buildLabel('비밀번호 확인'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordConfirmController,
                  obscureText: _obscurePasswordConfirm,
                  decoration: _inputDecoration('비밀번호를 다시 입력하세요').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePasswordConfirm ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscurePasswordConfirm = !_obscurePasswordConfirm),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return '비밀번호를 다시 입력하세요';
                    if (value != _passwordController.text) return '비밀번호가 일치하지 않습니다';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 이름
                _buildLabel('이름'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('실명을 입력하세요'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return '이름을 입력하세요';
                    if (value.trim().length < 2) return '이름은 2자 이상이어야 합니다';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 생년월일
                _buildLabel('생년월일'),
                const SizedBox(height: 8),
                TextField(
                  controller: _birthController,
                  keyboardType: TextInputType.number,
                  onChanged: _onBirthDateChanged,
                  decoration: InputDecoration(
                    hintText: 'YYYY/MM/DD',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 20),
                      onPressed: _selectBirthDate,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 닉네임
                _buildLabel('닉네임'),
                const Text(
                  '커뮤니티에서 사용될 이름',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nicknameController,
                  decoration: _inputDecoration('닉네임을 입력하세요'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return '닉네임을 입력하세요';
                    if (value.trim().length < 2) return '닉네임은 2자 이상이어야 합니다';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 이메일
                _buildLabel('이메일'),
                const Text(
                  '인증번호가 발송됩니다',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_emailVerified,
                        decoration: _inputDecoration('이메일을 입력하세요').copyWith(
                          suffixIcon: _emailVerified
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                        ),
                        onChanged: (_) {
                          if (_otpSent || _emailVerified) {
                            setState(() {
                              _otpSent = false;
                              _emailVerified = false;
                              _otpController.clear();
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return '이메일을 입력하세요';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return '올바른 이메일 형식이 아닙니다';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _emailVerified || _otpSending ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _emailVerified ? Colors.grey : AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _otpSending
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                              )
                            : Text(
                                _emailVerified ? '인증완료' : (_otpSent ? '재발송' : '인증'),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),

                // OTP 입력 필드 (발송 후 표시)
                if (_otpSent && !_emailVerified) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _inputDecoration('인증번호 6자리').copyWith(
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _otpVerifying ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _otpVerifying
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                )
                              : const Text('확인', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),

                // 약관 동의
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 전체 동의
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreeTerms && _agreePrivacy,
                              activeColor: AppColors.primary,
                              onChanged: (value) {
                                setState(() {
                                  _agreeTerms = value ?? false;
                                  _agreePrivacy = value ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '전체 동의',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      // 이용약관 동의
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreeTerms,
                              activeColor: AppColors.primary,
                              onChanged: (value) {
                                setState(() => _agreeTerms = value ?? false);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '[필수] 서비스 이용약관 동의',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TermsScreen()),
                            ),
                            child: const Text(
                              '보기',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 개인정보처리방침 동의
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreePrivacy,
                              activeColor: AppColors.primary,
                              onChanged: (value) {
                                setState(() => _agreePrivacy = value ?? false);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '[필수] 개인정보처리방침 동의',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TermsScreen()),
                            ),
                            child: const Text(
                              '보기',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 회원가입 버튼
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '회원가입',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
