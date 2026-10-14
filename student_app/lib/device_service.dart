import 'dart:io';
import 'dart:math';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// بصمة الجهاز الحقيقية (بدل البصمة المزيفة المبنية على user id).
/// أندرويد: ANDROID_ID | آيفون: identifierForVendor | غير ذلك: معرّف عشوائي محفوظ بأمان.
class DeviceService {
  static const _storage = FlutterSecureStorage();
  static String? _cached;

  static Future<String> getFingerprint() async {
    if (_cached != null) return _cached!;

    String? raw;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        raw = await const AndroidId().getId();
      } else if (!kIsWeb && Platform.isIOS) {
        raw = (await DeviceInfoPlugin().iosInfo).identifierForVendor;
      }
    } catch (e) {
      debugPrint('DeviceService: failed to read device id: $e');
    }

    raw = (raw == null || raw.trim().isEmpty) ? await _fallbackInstallId() : raw.trim();
    _cached = 'did-$raw';
    return _cached!;
  }

  static Future<String> _fallbackInstallId() async {
    const keyName = 'install_id';
    var id = await _storage.read(key: keyName);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await _storage.write(key: keyName, value: id);
    }
    return id;
  }
}
