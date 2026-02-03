class PostModel {
  final String id;
  final String userId;
  final String content;
  final String? oreumId;
  final String? oreumName;
  final String? category;
  final List<String> images;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? userNickname;
  final String? userProfileImage;
  final int? userStampCount;

  PostModel({
    required this.id,
    required this.userId,
    required this.content,
    this.oreumId,
    this.oreumName,
    this.category,
    this.images = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.userNickname,
    this.userProfileImage,
    this.userStampCount,
  });

  int get userLevel => ((userStampCount ?? 0) ~/ 10) + 1;

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // stamp_count 계산: stamps 배열의 길이 또는 직접 제공된 값
    int? stampCount;
    if (json['users']?['stamps'] != null) {
      final stamps = json['users']['stamps'];
      if (stamps is List) {
        stampCount = stamps.length;
      } else if (stamps is int) {
        stampCount = stamps;
      }
    } else if (json['users']?['stamp_count'] != null) {
      stampCount = json['users']['stamp_count'];
    }

    return PostModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      content: json['content'] ?? '',
      oreumId: json['oreum_id']?.toString(),
      oreumName: json['oreums']?['name'],
      category: json['category'],
      images: json['images'] != null
          ? List<String>.from(json['images'])
          : [],
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      userNickname: json['users']?['nickname'],
      userProfileImage: json['users']?['profile_image'],
      userStampCount: stampCount,
    );
  }

  factory PostModel.fromSupabase(Map<String, dynamic> json) {
    return PostModel.fromJson(json);
  }

  PostModel copyWith({
    String? id,
    String? userId,
    String? content,
    String? oreumId,
    String? oreumName,
    String? category,
    List<String>? images,
    int? likeCount,
    int? commentCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userNickname,
    String? userProfileImage,
    int? userStampCount,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      oreumId: oreumId ?? this.oreumId,
      oreumName: oreumName ?? this.oreumName,
      category: category ?? this.category,
      images: images ?? this.images,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userNickname: userNickname ?? this.userNickname,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      userStampCount: userStampCount ?? this.userStampCount,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inDays > 7) {
      return '${createdAt.month}/${createdAt.day}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}일 전';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}시간 전';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }
}

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? userNickname;
  final String? userProfileImage;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.userNickname,
    this.userProfileImage,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      userNickname: json['users']?['nickname'],
      userProfileImage: json['users']?['profile_image'],
    );
  }

  factory CommentModel.fromSupabase(Map<String, dynamic> json) {
    return CommentModel.fromJson(json);
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inDays > 7) {
      return '${createdAt.month}/${createdAt.day}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}일 전';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}시간 전';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }
}
