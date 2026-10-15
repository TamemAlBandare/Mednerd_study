import 'dart:io';
import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// بصمة الجهاز الحقيقية وفحص سلامة بيئة التشغيل (منع المحاكيات والروت).
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

    raw = (raw == null || raw.trim().isEmpty)
        ? await _fallbackInstallId()
        : raw.trim();
    _cached = 'did-$raw';
    return _cached!;
  }

  /// التحقق مما إذا كان الجهاز محاكياً (Emulator) أو مكسور الحماية (Rooted)
  static Future<bool> isCompromisedEnvironment() async {
    if (kIsWeb) return false;
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        if (!android.isPhysicalDevice) return true;

        final model = android.model.toLowerCase();
        final product = android.product.toLowerCase();
        final hardware = android.hardware.toLowerCase();
        if (model.contains('sdk') ||
            model.contains('emulator') ||
            product.contains('sdk') ||
            hardware.contains('goldfish') ||
            hardware.contains('ranchu')) {
          return true;
        }

        const rootPaths = [
          '/system/app/Superuser.apk',
          '/sbin/su',
          '/system/bin/su',
          '/system/xbin/su',
          '/data/local/xbin/su',
          '/data/local/bin/su',
          '/system/sd/xbin/su',
          '/system/bin/failsafe/su',
          '/data/local/su',
          '/su/bin/su',
          '/sbin/magisk',
        ];
        for (final path in rootPaths) {
          if (File(path).existsSync()) return true;
        }
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        if (!ios.isPhysicalDevice) return true;
      }
    } catch (e) {
      debugPrint('Security check error: $e');
    }
    return false;
  }

  static Future<String> _fallbackInstallId() async {
    const keyName = 'install_id';
    var id = await _storage.read(key: keyName);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List.generate(
        16,
        (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await _storage.write(key: keyName, value: id);
    }
    return id;
  }
}
