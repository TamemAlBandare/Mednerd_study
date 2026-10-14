import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _networkMsg = 'تعذر الاتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى.';

/// يحوّل أي خطأ تقني إلى رسالة عربية مفهومة للطالب (بدون نصوص تقنية).
String friendlyError(Object e) {
  if (e is SocketException || e is TimeoutException || e is HttpException) return _networkMsg;
  if (e is AuthException) return _authMessage(e.message);
  if (e is PostgrestException) {
    if (e.code == '42501') return 'ليست لديك صلاحية لهذه العملية.';
    return _looksLikeNetwork(e.message) ? _networkMsg : 'تعذر إكمال الطلب. حاول مرة أخرى بعد قليل.';
  }
  return _looksLikeNetwork(e.toString()) ? _networkMsg : 'حدث خطأ غير متوقع. حاول مرة أخرى.';
}

bool _looksLikeNetwork(String t) {
  final m = t.toLowerCase();
  return m.contains('socketexception') ||
      m.contains('failed host lookup') ||
      m.contains('clientexception') ||
      m.contains('timeout') ||
      m.contains('connection');
}

String _authMessage(String raw) {
  final m = raw.toLowerCase();
  if (m.contains('invalid login credentials')) return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
  if (m.contains('already registered') || m.contains('already been registered')) {
    return 'هذا البريد الإلكتروني مسجل مسبقاً.';
  }
  if (m.contains('email not confirmed')) return 'يرجى تأكيد بريدك الإلكتروني أولاً.';
  if (m.contains('rate limit') || m.contains('too many')) {
    return 'محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة.';
  }
  if (m.contains('expired') || m.contains('invalid') && m.contains('token')) {
    return 'الرمز غير صحيح أو منتهي الصلاحية.';
  }
  if (m.contains('password')) return 'كلمة المرور غير مقبولة. اختر كلمة أقوى.';
  if (_looksLikeNetwork(m)) return _networkMsg;
  return 'تعذر إكمال العملية. تحقق من البيانات وحاول مرة أخرى.';
}

/// يعرض الخطأ للطالب في شريط سفلي بدل ابتلاعه بصمت.
void showErrorSnack(BuildContext context, Object e) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      content: Text(friendlyError(e)),
    ),
  );
}

/// ترجمة رسائل أخطاء دوال Supabase إلى رسائل مفهومة للطالب.
String activationErrorMessage(String? code) {
  switch (code) {
    case 'invalid_code':
      return 'رمز التفعيل غير صالح';
    case 'code_unavailable':
      return 'تم استخدام أو تعطيل هذا الرمز مسبقاً';
    case 'already_subscribed':
      return 'أنت مشترك بالفعل في هذا المقرر مع هذا الدكتور';
    case 'too_many_attempts':
      return 'محاولات خاطئة كثيرة. حاول مرة أخرى بعد 15 دقيقة.';
    case 'not_authenticated':
      return 'يجب تسجيل الدخول أولاً';
    default:
      return 'تعذر التفعيل، تحقق من الاتصال وحاول مرة أخرى';
  }
}

String accessDeniedMessage(String? reason) {
  switch (reason) {
    case 'other_device':
      return 'هذا المقرر مسجل على جهاز آخر. يرجى التواصل مع الإدارة لفك الارتباط.';
    case 'no_fingerprint':
      return 'تعذر التعرف على جهازك. أعد المحاولة.';
    default:
      return 'تم تعطيل أو حظر اشتراكك في هذا المقرر من قبل الإدارة.';
  }
}
