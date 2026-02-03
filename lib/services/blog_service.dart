import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BlogPost {
  final String title;
  final String link;
  final String description;
  final String bloggerName;
  final String bloggerLink;
  final String postDate;

  BlogPost({
    required this.title,
    required this.link,
    required this.description,
    required this.bloggerName,
    required this.bloggerLink,
    required this.postDate,
  });

  factory BlogPost.fromJson(Map<String, dynamic> json) {
    // HTML 태그 제거
    String removeHtmlTags(String text) {
      return text
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&nbsp;', ' ');
    }

    return BlogPost(
      title: removeHtmlTags(json['title'] ?? ''),
      link: json['link'] ?? '',
      description: removeHtmlTags(json['description'] ?? ''),
      bloggerName: removeHtmlTags(json['bloggername'] ?? ''),
      bloggerLink: json['bloggerlink'] ?? '',
      postDate: json['postdate'] ?? '',
    );
  }
}

class BlogService {
  static const String _clientId = 'Ptn_X9wqz9PE6cXMTd1L';
  static const String _clientSecret = 'MyIXEaspaX';
  static const String _baseUrl = 'https://openapi.naver.com/v1/search/blog.json';

  /// 오름 관련 블로그 검색
  Future<List<BlogPost>> searchBlogPosts(String oreumName, {int display = 5}) async {
    try {
      final query = Uri.encodeComponent('"$oreumName" 등산 후기');
      final url = '$_baseUrl?query=$query&display=$display&sort=sim';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Naver-Client-Id': _clientId,
          'X-Naver-Client-Secret': _clientSecret,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];

        return items.map((item) => BlogPost.fromJson(item)).toList();
      } else {
        debugPrint('블로그 검색 에러: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('블로그 검색 예외: $e');
      return [];
    }
  }

  /// 포맷된 날짜 반환 (20240115 -> 2024.01.15)
  String formatDate(String postDate) {
    if (postDate.length == 8) {
      return '${postDate.substring(0, 4)}.${postDate.substring(4, 6)}.${postDate.substring(6, 8)}';
    }
    return postDate;
  }
}
