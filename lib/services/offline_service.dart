import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class OfflineService {
  final SupabaseClient _client = SupabaseConfig.client;
  static Database? _db;
  static const int dailyDownloadLimit = 3;

  // 로그인 여부 확인
  bool get isLoggedIn => _client.auth.currentUser != null;

  // 오늘 다운로드 횟수 확인 (로컬 DB 기반)
  Future<int> getTodayDownloadCount() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM download_logs WHERE date = ?",
      [today],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // 남은 다운로드 횟수
  Future<int> getRemainingDownloads() async {
    final count = await getTodayDownloadCount();
    return dailyDownloadLimit - count;
  }

  // 다운로드 기록 저장
  Future<void> _recordDownload() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    await db.insert('download_logs', {'date': today});
  }

  // 로컬 DB 초기화
  static Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      '$dbPath/offline_oreums.db',
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS offline_oreums (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            geojson TEXT,
            downloaded_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS download_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS download_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL
            )
          ''');
        }
      },
    );
    return _db!;
  }

  // 오름 데이터를 로컬에 저장
  Future<bool> saveOreumOffline(Map<String, dynamic> oreumData) async {
    try {
      final db = await database;
      final oreumId = oreumData['id'].toString();

      // GeoJSON 다운로드 시도
      String? geojson;
      try {
        final response = await _client.storage
            .from('oreum-data')
            .download('$oreumId/trail.geojson');
        geojson = String.fromCharCodes(response);
      } catch (_) {
        // GeoJSON 없는 오름도 있음
      }

      await db.insert(
        'offline_oreums',
        {
          'id': oreumId,
          'data': json.encode(oreumData),
          'geojson': geojson,
          'downloaded_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return true;
    } catch (e) {
      debugPrint('오프라인 저장 실패: $e');
      return false;
    }
  }

  // 전체 오름 데이터 일괄 저장
  Future<int> saveAllOreumsOffline() async {
    if (!isLoggedIn) {
      throw Exception('로그인이 필요합니다');
    }

    final remaining = await getRemainingDownloads();
    if (remaining <= 0) {
      throw Exception('오늘 다운로드 한도를 초과했습니다 (최대 $dailyDownloadLimit회/일)');
    }

    try {
      final response = await _client
          .from('oreums')
          .select()
          .eq('is_active', true);

      final oreums = List<Map<String, dynamic>>.from(response);
      final db = await database;
      int savedCount = 0;

      final batch = db.batch();
      for (final oreum in oreums) {
        batch.insert(
          'offline_oreums',
          {
            'id': oreum['id'].toString(),
            'data': json.encode(oreum),
            'geojson': null,
            'downloaded_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        savedCount++;
      }
      await batch.commit(noResult: true);

      // 다운로드 기록 저장
      await _recordDownload();

      return savedCount;
    } catch (e) {
      debugPrint('일괄 오프라인 저장 실패: $e');
      rethrow;
    }
  }

  // 로컬에 저장된 오름 목록 가져오기
  Future<List<Map<String, dynamic>>> getOfflineOreums() async {
    try {
      final db = await database;
      final results = await db.query('offline_oreums', orderBy: 'downloaded_at DESC');

      return results.map((row) {
        final data = json.decode(row['data'] as String) as Map<String, dynamic>;
        data['has_geojson'] = row['geojson'] != null;
        data['downloaded_at'] = row['downloaded_at'];
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // 특정 오름 오프라인 데이터 가져오기
  Future<Map<String, dynamic>?> getOfflineOreum(String oreumId) async {
    try {
      final db = await database;
      final results = await db.query(
        'offline_oreums',
        where: 'id = ?',
        whereArgs: [oreumId],
      );

      if (results.isEmpty) return null;

      final row = results.first;
      final data = json.decode(row['data'] as String) as Map<String, dynamic>;
      if (row['geojson'] != null) {
        data['geojson'] = row['geojson'];
      }
      return data;
    } catch (e) {
      return null;
    }
  }

  // 오프라인 저장 여부 확인
  Future<bool> isDownloaded(String oreumId) async {
    try {
      final db = await database;
      final results = await db.query(
        'offline_oreums',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [oreumId],
      );
      return results.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // 특정 오름 오프라인 데이터 삭제
  Future<void> deleteOfflineOreum(String oreumId) async {
    final db = await database;
    await db.delete('offline_oreums', where: 'id = ?', whereArgs: [oreumId]);
  }

  // 전체 오프라인 데이터 삭제
  Future<void> deleteAllOfflineData() async {
    final db = await database;
    await db.delete('offline_oreums');
  }

  // 오프라인 데이터 크기 (건수)
  Future<int> getOfflineCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM offline_oreums');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
