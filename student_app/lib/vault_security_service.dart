import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart'
    show AesGcm, SecretBox, SecretKey;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_service.dart';
import 'backend_errors.dart';

class VaultSecurityService {
  static const int leaseValidityDays = 7;
  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  static const String _metaPrefix = 'vault_file_meta_';
  static const String _lastSeenTimeKey = 'vault_last_seen_utc_ms';

  /// توليد اسم موحّد للملف المشفر يتضمن معرف المقرر ومعرف المحاضرة
  static String buildVaultFileName({
    required String subjectId,
    required String lectureId,
  }) {
    final sId = subjectId.replaceAll('-', '');
    final lId = lectureId.replaceAll('-', '');
    return 'sub_${sId}_lec_$lId.med_vault';
  }

  /// حفظ البيانات الوصفية للملف المشفر (العنوان، معرف المحاضرة الأصلي، معرف المقرر الأصلي)
  static Future<void> saveFileMeta({
    required String fileName,
    required String lectureId,
    required String subjectId,
    required String title,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_metaPrefix$fileName',
      jsonEncode({
        'lecture_id': lectureId,
        'subject_id': subjectId,
        'title': title,
      }),
    );
  }

  /// قراءة البيانات الوصفية للملف المشفر
  static Future<Map<String, String>?> getFileMeta(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_metaPrefix$fileName');
    if (raw != null) {
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        return {
          'lecture_id': decoded['lecture_id']?.toString() ?? '',
          'subject_id': decoded['subject_id']?.toString() ?? '',
          'title': decoded['title']?.toString() ?? 'ملخص المحاضرة المحفوظ',
        };
      } catch (_) {}
    }
    return null;
  }

  /// حذف البيانات الوصفية للملف
  static Future<void> removeFileMeta(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_metaPrefix$fileName');
  }

  /// التحقق من عدم التلاعب بوقت الجهاز (منع إرجاع التاريخ للوراء لتمديد الأوفلاين)
  static Future<bool> _checkAndRecordTimestamp() async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final rawLast = await _secure.read(key: _lastSeenTimeKey);
    if (rawLast != null) {
      final lastMs = int.tryParse(rawLast) ?? 0;
      // السماح بهامش 5 دقائق فقط لأي فروق توقيت طبيعية؛ إذا كان الوقت أقدم فهذا تلاعب بالتاريخ
      if (nowMs + const Duration(minutes: 5).inMilliseconds < lastMs) {
        return false;
      }
    }
    await _secure.write(key: _lastSeenTimeKey, value: nowMs.toString());
    return true;
  }

  /// التحقق المباشر عبر الإنترنت قبل تشغيل المحاضرات المرئية
  static Future<Map<String, dynamic>> verifyOnlineAccess({
    required String subjectId,
    String? professorId,
  }) async {
    if (await DeviceService.isCompromisedEnvironment()) {
      return {
        'ok': false,
        'message': 'لا يمكن تشغيل المحتوى المحمي على محاكي أو جهاز مكسور الحماية (Root).',
      };
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return {'ok': false, 'message': 'يجب تسجيل الدخول أولاً.'};
    }

    final keyName = 'vault_key_${user.id}_$subjectId';
    final leaseName = 'vault_lease_${user.id}_$subjectId';

    try {
      final fingerprint = await DeviceService.getFingerprint();
      final pid = professorId?.trim();
      final res = await client.rpc(
        'get_vault_key',
        params: {
          'p_subject_id': subjectId,
          'p_professor_id': (pid == null || pid.isEmpty) ? null : pid,
          'p_fingerprint': fingerprint,
        },
      );
      final result = Map<String, dynamic>.from(res as Map);

      if (result['ok'] == true) {
        final rawKey = result['key'] as String;
        await _secure.write(key: keyName, value: rawKey);
        await _secure.write(
          key: leaseName,
          value: DateTime.now()
              .toUtc()
              .add(const Duration(days: leaseValidityDays))
              .toIso8601String(),
        );
        await _checkAndRecordTimestamp();
        return {'ok': true};
      }

      await revokeAndWipeSubject(subjectId);
      return {
        'ok': false,
        'message': accessDeniedMessage(result['reason']?.toString()),
      };
    } catch (e) {
      return {'ok': false, 'message': friendlyError(e)};
    }
  }

  /// جلب مفتاح فك التشفير الخاص بالمقرر. السيرفر هو من يتحقق من الاشتراك والجهاز.
  static Future<Uint8List?> getOrRenewVaultKey({
    required String subjectId,
    String? professorId,
  }) async {
    if (await DeviceService.isCompromisedEnvironment()) {
      return null;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return null;

    final keyName = 'vault_key_${user.id}_$subjectId';
    final leaseName = 'vault_lease_${user.id}_$subjectId';

    try {
      final fingerprint = await DeviceService.getFingerprint();
      final pid = professorId?.trim();
      final res = await client.rpc(
        'get_vault_key',
        params: {
          'p_subject_id': subjectId,
          'p_professor_id': (pid == null || pid.isEmpty) ? null : pid,
          'p_fingerprint': fingerprint,
        },
      );
      final result = Map<String, dynamic>.from(res as Map);

      if (result['ok'] == true) {
        final rawKey = result['key'] as String;
        await _secure.write(key: keyName, value: rawKey);
        await _secure.write(
          key: leaseName,
          value: DateTime.now()
              .toUtc()
              .add(const Duration(days: leaseValidityDays))
              .toIso8601String(),
        );
        await _checkAndRecordTimestamp();
        return base64Url.decode(rawKey);
      }

      await revokeAndWipeSubject(subjectId);
      return null;
    } catch (_) {
      // وضع الأوفلاين عند انقطاع الاتصال بالسيرفر
    }

    // التحقق الصارم من عدم إرجاع ساعة الجهاز للوراء أثناء وضع الأوفلاين
    final isClockValid = await _checkAndRecordTimestamp();
    if (!isClockValid) {
      return null;
    }

    final cachedKey = await _secure.read(key: keyName);
    final cachedLease = await _secure.read(key: leaseName);

    if (cachedKey != null && cachedLease != null) {
      final leaseDate = DateTime.tryParse(cachedLease)?.toUtc();
      if (leaseDate != null && DateTime.now().toUtc().isBefore(leaseDate)) {
        try {
          return base64Url.decode(cachedKey);
        } catch (_) {
          return null;
        }
      }
    }

    return null;
  }

  /// إتلاف المفتاح ومسح ملفات المقرر تلقائياً عند إلغاء الاشتراك
  static Future<void> revokeAndWipeSubject(String subjectId) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      await _secure.delete(key: 'vault_key_${user.id}_$subjectId');
      await _secure.delete(key: 'vault_lease_${user.id}_$subjectId');
    }

    try {
      final cleanSubId = subjectId.replaceAll('-', '');
      final dir = await getApplicationSupportDirectory();
      final vaultDir = Directory('${dir.path}/.offline_vault');
      if (await vaultDir.exists()) {
        final files = vaultDir.listSync();
        for (var file in files) {
          final fileName = file.path.split(Platform.pathSeparator).last;
          final meta = await getFileMeta(fileName);
          final matchesName =
              fileName.contains('sub_${cleanSubId}_') ||
              fileName.contains(cleanSubId);
          final matchesMeta =
              meta != null &&
              (meta['subject_id'] == subjectId ||
                  meta['subject_id']?.replaceAll('-', '') == cleanSubId);

          if (matchesName || matchesMeta) {
            file.deleteSync();
            await removeFileMeta(fileName);
          }
        }
      }
    } catch (_) {}
  }

  static final AesGcm _aes = AesGcm.with256bits();
  static const List<int> _magic = [0x4D, 0x4E, 0x32]; // 'MN2'

  static bool isLegacyFormat(Uint8List data) =>
      !(data.length > 3 &&
          data[0] == _magic[0] &&
          data[1] == _magic[1] &&
          data[2] == _magic[2]);

  static Future<Uint8List> encryptBytes(Uint8List data, Uint8List key) async {
    final box = await _aes.encrypt(data, secretKey: SecretKey(key));
    return Uint8List.fromList([..._magic, ...box.concatenation()]);
  }

  static Future<Uint8List> decryptBytes(Uint8List data, Uint8List key) async {
    if (isLegacyFormat(data)) return _legacyXor(data, key);
    final box = SecretBox.fromConcatenation(
      data.sublist(3),
      nonceLength: 12,
      macLength: 16,
    );
    return Uint8List.fromList(
      await _aes.decrypt(box, secretKey: SecretKey(key)),
    );
  }

  static Uint8List _legacyXor(Uint8List data, Uint8List key) {
    final out = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      out[i] = data[i] ^ key[i % key.length];
    }
    return out;
  }
}
