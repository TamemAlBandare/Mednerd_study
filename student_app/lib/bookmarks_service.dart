import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookmarksService {
  static String get _userKey {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    return 'favorite_lectures_list_$uid';
  }

  /// جلب كافة المحاضرات المفضلة
  static Future<List<Map<String, dynamic>>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_userKey);
    if (data == null) return [];
    try {
      final List decoded = jsonDecode(data);
      return List<Map<String, dynamic>>.from(decoded);
    } catch (_) {
      return [];
    }
  }

  /// التحقق إن كانت المحاضرة مفضلة
  static Future<bool> isFavorite(String lectureId) async {
    final favorites = await getFavorites();
    return favorites.any((item) => item['id']?.toString() == lectureId.toString());
  }

  /// تبديل حالة المفضلة (إضافة / حذف)
  static Future<bool> toggleFavorite({
    required Map<String, dynamic> lecture,
    required String subjectTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    final lectureId = lecture['id']?.toString();

    final index = favorites.indexWhere((item) => item['id']?.toString() == lectureId);
    bool added;

    if (index != -1) {
      favorites.removeAt(index);
      added = false;
    } else {
      final itemToSave = Map<String, dynamic>.from(lecture);
      itemToSave['subject_title'] = subjectTitle;
      favorites.insert(0, itemToSave);
      added = true;
    }

    await prefs.setString(_userKey, jsonEncode(favorites));
    return added;
  }
}
