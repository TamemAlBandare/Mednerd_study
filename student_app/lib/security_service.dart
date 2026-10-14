import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';

class SecurityService {
  static int _refs = 0; // عدد الشاشات التي تطلب الحماية حالياً
  /// تفعيل حظر السكرين شوت وتسجيل الشاشة
  static Future<void> enableSecureScreen() async {
    if (kIsWeb) return;
    _refs++;
    if (_refs > 1) return;
    try {
      if (Platform.isAndroid) {
        await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
      }
    } catch (e) {
      debugPrint('Error enabling secure screen: $e');
    }
  }

  /// إلغاء حظر السكرين شوت (عند الخروج من شاشات الفيديو والـ PDF)
  static Future<void> disableSecureScreen() async {
    if (kIsWeb) return;
    if (_refs > 0) _refs--;
    if (_refs > 0) return;
    try {
      if (Platform.isAndroid) {
        await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
      }
    } catch (e) {
      debugPrint('Error disabling secure screen: $e');
    }
  }
}