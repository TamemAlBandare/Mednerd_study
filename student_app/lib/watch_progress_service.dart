import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WatchProgressService {
  static String get _userKey {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    return 'last_watched_lecture_progress_$uid';
  }

  /// حفظ بيانات آخر محاضرة والثانية التي توقف عندها الطالب
  static Future<void> saveProgress({
    required Map<String, dynamic> lecture,
    required List<Map<String, dynamic>> allLectures,
    required String subjectTitle,
    required int positionSeconds,
    required int totalDurationSeconds,
  }) async {
    if (positionSeconds < 3) return;

    final prefs = await SharedPreferences.getInstance();
    final data = {
      'lecture': lecture,
      'allLectures': allLectures,
      'subject_title': subjectTitle,
      'position_seconds': positionSeconds,
      'total_duration_seconds': totalDurationSeconds,
      'saved_at': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_userKey, jsonEncode(data));
  }

  /// استرجاع بيانات آخر محاضرة
  static Future<Map<String, dynamic>?> getLastProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// حذف السجل عند إتمام المحاضرة
  static Future<void> clearProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
