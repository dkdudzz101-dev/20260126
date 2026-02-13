class ContentFilter {
  // 한국어 비속어/욕설 목록
  static const List<String> _profanity = [
    // 대표적인 욕설
    '시발', '씨발', '시바', '씨바', '씨빨', '시빨',
    '개새끼', '개세끼', '개세키', '개새키',
    '병신', '븅신', '빙신',
    '지랄', '찐따', '찐다',
    '꺼져', '닥쳐', '뒤져', '뒤져라', '죽어',
    '미친놈', '미친년', '미친새끼',
    '씹', '좆', '보지',
    '년', '놈',
    '새끼',
    // 자음 축약형
    'ㅅㅂ', 'ㅆㅂ', 'ㅂㅅ', 'ㅈㄹ', 'ㄱㅅㄲ', 'ㅅㄲ', 'ㅁㅊ',
    'ㄲㅈ', 'ㄷㅊ',
    // 영어 욕설
    'fuck', 'shit', 'damn', 'bitch', 'asshole',
    'bastard', 'dick', 'pussy',
  ];

  // 혐오/차별 표현
  static const List<String> _hateSpeech = [
    '한남', '한녀', '김치녀', '김치남',
    '틀딱', '꼰대',
    '장애인놈', '정신병자',
  ];

  /// 콘텐츠 필터링 검사
  static FilterResult check(String content) {
    if (content.trim().isEmpty) {
      return FilterResult(isClean: true);
    }

    final normalized = content.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final List<String> found = [];

    for (final word in _profanity) {
      if (normalized.contains(word.toLowerCase())) {
        found.add(word);
      }
    }

    for (final word in _hateSpeech) {
      if (normalized.contains(word.toLowerCase())) {
        found.add(word);
      }
    }

    if (found.isNotEmpty) {
      return FilterResult(
        isClean: false,
        message: '부적절한 표현이 포함되어 있습니다. 수정 후 다시 시도해주세요.',
      );
    }

    return FilterResult(isClean: true);
  }
}

class FilterResult {
  final bool isClean;
  final String? message;

  FilterResult({
    required this.isClean,
    this.message,
  });
}
