import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'category': '스탬프',
        'items': [
          {
            'question': '스탬프는 어떻게 받나요?',
            'answer': '오름 정상에서 100m 이내에서 GPS 인증을 하시면 스탬프를 획득할 수 있습니다.\n\n스탬프북 > GPS 스탬프 인증 버튼을 눌러 인증하세요.',
          },
          {
            'question': '레벨은 어떻게 올라가나요?',
            'answer': '스탬프 1개당 1레벨이 올라갑니다.\n\n예: 스탬프 5개 = 레벨 5',
          },
          {
            'question': 'GPS 인증이 안 돼요',
            'answer': '다음 사항을 확인해주세요:\n\n1. 위치 권한이 허용되어 있는지 확인\n2. GPS가 켜져 있는지 확인\n3. 야외에서 GPS 신호가 잡히는지 확인\n4. 정상에서 100m 이내인지 확인\n\n그래도 안 되면 앱을 재시작해보세요.',
          },
          {
            'question': '스탬프를 잘못 받았어요',
            'answer': '스탬프 관련 문의는 "문의하기"를 통해 접수해주세요. 확인 후 조치해드리겠습니다.',
          },
        ],
      },
      {
        'category': '계정',
        'items': [
          {
            'question': '회원가입은 어떻게 하나요?',
            'answer': '카카오, 네이버, 애플 소셜 로그인으로 간편하게 가입할 수 있습니다.\n\n내정보 > 로그인하기 버튼을 눌러 원하는 방법으로 가입하세요.',
          },
          {
            'question': '계정을 탈퇴하고 싶어요',
            'answer': '설정 > 계정 탈퇴에서 탈퇴할 수 있습니다.\n\n주의: 탈퇴 시 모든 데이터(스탬프, 게시글 등)가 삭제되며 복구할 수 없습니다.',
          },
          {
            'question': '다른 기기에서 로그인하면 데이터가 유지되나요?',
            'answer': '네, 같은 계정으로 로그인하시면 스탬프, 게시글 등 모든 데이터가 유지됩니다.',
          },
        ],
      },
      {
        'category': '오름 정보',
        'items': [
          {
            'question': '오름 정보가 잘못되었어요',
            'answer': '"문의하기"를 통해 수정이 필요한 내용을 알려주시면 확인 후 수정하겠습니다.',
          },
          {
            'question': '새로운 오름을 추가해주세요',
            'answer': '추가를 원하시는 오름 정보를 "문의하기"를 통해 알려주시면 검토 후 추가하겠습니다.',
          },
        ],
      },
      {
        'category': '커뮤니티',
        'items': [
          {
            'question': '게시글을 삭제하고 싶어요',
            'answer': '본인이 작성한 게시글은 게시글 상세 화면에서 우측 상단 메뉴를 통해 삭제할 수 있습니다.',
          },
          {
            'question': '부적절한 게시글을 신고하고 싶어요',
            'answer': '해당 게시글의 신고 버튼을 누르거나, 햄버거 메뉴 > 신고하기를 통해 신고할 수 있습니다.',
          },
        ],
      },
      {
        'category': '기타',
        'items': [
          {
            'question': '앱이 자꾸 종료돼요',
            'answer': '다음 방법을 시도해보세요:\n\n1. 앱 재시작\n2. 기기 재시작\n3. 앱 삭제 후 재설치\n4. 앱 업데이트 확인\n\n그래도 문제가 지속되면 "문의하기"로 알려주세요.',
          },
          {
            'question': '오프라인에서도 사용할 수 있나요?',
            'answer': '기본적인 오름 정보는 오프라인에서도 볼 수 있습니다.\n\n단, 스탬프 인증, 커뮤니티 등 일부 기능은 인터넷 연결이 필요합니다.',
          },
        ],
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('자주 묻는 질문'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          final category = faqs[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index > 0) const SizedBox(height: 24),
              Text(
                category['category'] as String,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              ...(category['items'] as List).map((item) => _FaqItem(
                    question: item['question'] as String,
                    answer: item['answer'] as String,
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      'Q',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        'A',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.answer,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
