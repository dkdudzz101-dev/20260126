import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('이용약관'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '서비스 이용약관'),
              Tab(text: '개인정보처리방침'),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
          ),
        ),
        body: const TabBarView(
          children: [
            _ServiceTerms(),
            _PrivacyPolicy(),
          ],
        ),
      ),
    );
  }
}

class _ServiceTerms extends StatelessWidget {
  const _ServiceTerms();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '제주오름 서비스 이용약관',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '시행일: 2024년 1월 1일',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const Divider(height: 32),
          _buildSection(
            '제1조 (목적)',
            '본 약관은 제주오름(이하 "서비스")이 제공하는 모든 서비스의 이용조건 및 절차, 회원과 서비스의 권리, 의무, 책임사항 및 기타 필요한 사항을 규정함을 목적으로 합니다.',
          ),
          _buildSection(
            '제2조 (정의)',
            '1. "서비스"란 제주오름 앱을 통해 제공되는 제주 오름 정보, 스탬프 인증, 커뮤니티 등 모든 서비스를 의미합니다.\n\n2. "회원"이란 서비스에 접속하여 본 약관에 따라 서비스와 이용계약을 체결하고 서비스를 이용하는 자를 의미합니다.\n\n3. "스탬프"란 오름 방문을 GPS로 인증하여 획득하는 디지털 배지를 의미합니다.',
          ),
          _buildSection(
            '제3조 (약관의 효력 및 변경)',
            '1. 본 약관은 서비스를 이용하고자 하는 모든 회원에 대하여 그 효력을 발생합니다.\n\n2. 서비스는 약관의 규제에 관한 법률, 정보통신망 이용촉진 및 정보보호에 관한 법률 등 관련법을 위배하지 않는 범위에서 본 약관을 개정할 수 있습니다.\n\n3. 약관이 개정될 경우 서비스는 적용일자 7일 전부터 공지사항을 통해 변경사항을 공지합니다.',
          ),
          _buildSection(
            '제4조 (이용계약의 성립)',
            '1. 이용계약은 회원이 본 약관의 내용에 동의하고 회원가입 신청을 한 후, 서비스가 이를 승낙함으로써 체결됩니다.\n\n2. 서비스는 다음 각 호에 해당하는 경우 이용계약 체결을 거부할 수 있습니다.\n  - 실명이 아니거나 타인의 정보를 이용한 경우\n  - 허위의 정보를 기재한 경우\n  - 기타 서비스가 정한 이용신청 요건이 미비한 경우',
          ),
          _buildSection(
            '제5조 (서비스의 제공)',
            '서비스는 다음과 같은 서비스를 제공합니다.\n\n1. 제주 오름 정보 제공\n2. GPS 기반 스탬프 인증\n3. 등산로 안내\n4. 커뮤니티 서비스\n5. 기타 서비스가 정하는 서비스',
          ),
          _buildSection(
            '제6조 (회원의 의무)',
            '1. 회원은 서비스 이용과 관련하여 다음 행위를 하여서는 안 됩니다.\n  - 타인의 정보를 도용하는 행위\n  - 서비스에서 얻은 정보를 무단으로 복제, 배포하는 행위\n  - 허위 스탬프 인증 시도\n  - 서비스의 운영을 방해하는 행위\n  - 타 회원에 대한 비방, 욕설 등\n\n2. 위반 시 서비스 이용이 제한될 수 있습니다.',
          ),
          _buildSection(
            '제7조 (면책조항)',
            '1. 서비스는 천재지변 또는 이에 준하는 불가항력으로 인하여 서비스를 제공할 수 없는 경우에는 서비스 제공에 관한 책임이 면제됩니다.\n\n2. 등산 중 발생하는 안전사고에 대해서는 서비스가 책임지지 않습니다. 안전한 등산을 위해 충분한 준비를 해주세요.',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _PrivacyPolicy extends StatelessWidget {
  const _PrivacyPolicy();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '개인정보처리방침',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '시행일: 2024년 1월 1일',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const Divider(height: 32),
          _buildSection(
            '1. 수집하는 개인정보 항목',
            '서비스는 회원가입, 서비스 제공을 위해 다음과 같은 개인정보를 수집합니다.\n\n필수항목:\n- 소셜 로그인 시: 이메일, 닉네임, 프로필 이미지\n- GPS 스탬프 인증 시: 위치 정보\n\n자동 수집항목:\n- 서비스 이용 기록, 접속 로그, 기기 정보',
          ),
          _buildSection(
            '2. 개인정보의 수집 및 이용목적',
            '수집한 개인정보는 다음의 목적을 위해 활용됩니다.\n\n- 회원 식별 및 가입의사 확인\n- 서비스 제공 및 운영\n- 스탬프 인증 및 기록 저장\n- 고객 문의 응대\n- 서비스 개선 및 통계 분석',
          ),
          _buildSection(
            '3. 개인정보의 보유 및 이용기간',
            '회원의 개인정보는 원칙적으로 개인정보의 수집 및 이용목적이 달성되면 지체없이 파기합니다.\n\n단, 관계법령의 규정에 의하여 보존할 필요가 있는 경우 일정 기간 동안 회원정보를 보관합니다.\n\n- 계약 또는 청약철회 등에 관한 기록: 5년\n- 소비자의 불만 또는 분쟁처리에 관한 기록: 3년',
          ),
          _buildSection(
            '4. 개인정보의 파기절차 및 방법',
            '파기절차:\n개인정보는 목적 달성 후 별도의 DB에 옮겨져 내부 방침 및 관련 법령에 따라 일정기간 저장된 후 파기됩니다.\n\n파기방법:\n- 전자적 파일 형태: 기록을 재생할 수 없는 기술적 방법 사용\n- 종이에 출력된 정보: 분쇄기로 분쇄하거나 소각',
          ),
          _buildSection(
            '5. 위치정보의 처리',
            '서비스는 스탬프 인증을 위해 회원의 위치정보를 수집합니다.\n\n- 수집목적: GPS 기반 오름 방문 인증\n- 수집방법: 앱 내 GPS 인증 기능 사용 시\n- 보유기간: 스탬프 기록 보관 기간\n\n회원은 언제든지 위치정보 수집을 거부할 수 있으나, 이 경우 스탬프 인증 서비스 이용이 제한됩니다.',
          ),
          _buildSection(
            '6. 개인정보 보호책임자',
            '서비스는 개인정보 처리에 관한 업무를 총괄해서 책임지고, 개인정보 처리와 관련한 회원의 불만처리 및 피해구제 등을 위하여 개인정보 보호책임자를 지정하고 있습니다.\n\n문의: 앱 내 "문의하기" 이용',
          ),
          _buildSection(
            '7. 이용자의 권리',
            '회원은 언제든지 본인의 개인정보를 조회하거나 수정할 수 있으며, 가입해지(회원탈퇴)를 요청할 수 있습니다.\n\n개인정보 열람, 정정, 삭제, 처리정지 요청은 "문의하기"를 통해 가능합니다.',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

Widget _buildSection(String title, String content) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            height: 1.7,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}
