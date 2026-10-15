import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'youtube_lecture_screen.dart';
import 'device_service.dart';
import 'backend_errors.dart';
import 'auth_screen.dart';
import 'course_details_screen.dart';
import 'downloads_screen.dart';
import 'my_courses_screen.dart';
import 'profile_screen.dart';
import 'favorites_screen.dart';
import 'quiz_screen.dart';
import 'vault_security_service.dart';
import 'watch_progress_service.dart';
import 'university_faculties_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedDrawerIndex = 0;
  bool _isLoading = true;

  String _studentName = '';
  Map<String, dynamic>? _lastWatchedLecture;
  List<Map<String, dynamic>> _enrolledCourses = [];
  List<Map<String, dynamic>> _universities = [];

  // منظومة الإشعارات الذكية
  List<Map<String, dynamic>> _notifications = [];
  Set<String> _readNotificationIds = {};
  Set<String> _dismissedNotificationIds = {};

  static const Color lightScaffoldBg = Color(0xFFF3EFE6);
  static const Color lightEmeraldDark = Color(0xFF0E332E);
  static const Color lightEmeraldLight = Color(0xFF15443E);
  static const Color lightGoldBorder = Color(0xFFC5A059);

  static const Color darkScaffoldBg = Color(0xFF0B0F17);
  static const Color darkCardBg = Color(0xFF151E2E);
  static const Color darkCardSurface = Color(0xFF1E2B40);
  static const Color darkInputBg = Color(0xFF101724);
  static const Color darkGoldBorder = Color(0xFFC5A059);

  static const Color goldAccent = Color(0xFFD8B467);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  String get _readPrefsKey {
    final uid = supabase.auth.currentUser?.id ?? 'guest';
    return 'read_notifications_$uid';
  }

  String get _dismissedPrefsKey {
    final uid = supabase.auth.currentUser?.id ?? 'guest';
    return 'dismissed_notifications_$uid';
  }

  int get _unreadNotificationsCount {
    return _notifications
        .where((n) => !_readNotificationIds.contains(n['id'].toString()))
        .length;
  }

  Future<void> _loadNotificationStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readList = prefs.getStringList(_readPrefsKey) ?? [];
      final dismissedList = prefs.getStringList(_dismissedPrefsKey) ?? [];
      _readNotificationIds = readList.toSet();
      _dismissedNotificationIds = dismissedList.toSet();
    } catch (_) {}
  }

  Future<void> _markNotificationAsRead(String id) async {
    if (_readNotificationIds.contains(id)) return;
    setState(() {
      _readNotificationIds.add(id);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_readPrefsKey, _readNotificationIds.toList());
    } catch (_) {}
  }

  Future<void> _markAllNotificationsAsRead() async {
    setState(() {
      for (final n in _notifications) {
        _readNotificationIds.add(n['id'].toString());
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_readPrefsKey, _readNotificationIds.toList());
    } catch (_) {}
  }

  Future<void> _dismissNotification(String id) async {
    setState(() {
      _dismissedNotificationIds.add(id);
      _notifications.removeWhere((n) => n['id'].toString() == id);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _dismissedPrefsKey,
        _dismissedNotificationIds.toList(),
      );
    } catch (_) {}
  }

  Future<void> _buildSmartNotifications() async {
    await _loadNotificationStates();
    final List<Map<String, dynamic>> items = [];
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final remoteNotifs = await supabase
          .from('notifications')
          .select()
          .or('user_id.is.null,user_id.eq.${user.id}')
          .order('created_at', ascending: false)
          .limit(15);

      for (final raw in (remoteNotifs as List)) {
        final map = Map<String, dynamic>.from(raw as Map);
        final id = 'remote_${map['id']}';
        if (_dismissedNotificationIds.contains(id)) continue;
        items.add({
          'id': id,
          'category': map['category']?.toString() ?? 'admin',
          'title': map['title']?.toString() ?? 'إشعار إداري',
          'body': map['body']?.toString() ?? '',
          'time_label': _formatRelativeTime(map['created_at']?.toString()),
          'action_type': 'none',
        });
      }
    } catch (_) {}

    if (_lastWatchedLecture != null && _lastLectureMap != null) {
      final lecId = _lastLectureMap!['id']?.toString() ?? 'last';
      final notifId = 'resume_$lecId';
      if (!_dismissedNotificationIds.contains(notifId)) {
        items.add({
          'id': notifId,
          'category': 'lecture',
          'title': 'متابعة: $_lastLectureTitle',
          'body':
              'مقرر $_lastLectureSubjectTitle • وصلت إلى $_lastWatchProgressLabel',
          'time_label': 'نشط الآن',
          'action_type': 'resume_last',
        });
      }
    }

    if (_enrolledCourses.isNotEmpty) {
      try {
        final subjectIds = _enrolledCourses
            .map((c) => c['id'].toString())
            .toList();
        final recentLectures = await supabase
            .from('lectures')
            .select(
              'id, title, subject_id, professor_id, video_url, pdf_url, telegram_pdf_id, duration_minutes, order_index',
            )
            .inFilter('subject_id', subjectIds)
            .order('order_index', ascending: false)
            .limit(8);

        for (final rawLec in (recentLectures as List)) {
          final lec = Map<String, dynamic>.from(rawLec as Map);
          final lecId = lec['id'].toString();
          final notifId = 'lec_new_$lecId';
          if (_dismissedNotificationIds.contains(notifId)) continue;

          final courseMatch = _enrolledCourses.firstWhere(
            (c) => c['id'].toString() == lec['subject_id'].toString(),
            orElse: () => {'name': 'مقرر دراسي', 'professor_name': ''},
          );
          final subjectName = courseMatch['name']?.toString() ?? 'مقرر دراسي';
          final hasPdf =
              (lec['pdf_url']?.toString().trim().isNotEmpty ?? false) ||
              (lec['telegram_pdf_id']?.toString().trim().isNotEmpty ?? false);

          items.add({
            'id': notifId,
            'category': 'lecture',
            'title': lec['title']?.toString() ?? 'محاضرة متاحة',
            'body': hasPdf
                ? '$subjectName • الفيديو وملخص الـ PDF متاحان للمشاهدة'
                : '$subjectName • المحاضرة متاحة للمشاهدة والاختبار',
            'time_label': 'مقرر مفعّل',
            'action_type': 'open_lecture',
            'lecture_data': lec,
            'subject_title': subjectName,
          });
        }
      } catch (_) {}
    }

    const secId = 'security_device_verified';
    if (!_dismissedNotificationIds.contains(secId)) {
      items.add({
        'id': secId,
        'category': 'security',
        'title': 'حماية الحساب والخزنة المفعّلة',
        'body': _enrolledCourses.isNotEmpty
            ? 'حسابك موثق ببصمة الجهاز ومرتبط بـ ${_enrolledCourses.length} مقررات نشطة.'
            : 'حسابك جاهز ومؤمّن ببصمة الجهاز الفردية.',
        'time_label': 'نظام الأمان',
        'action_type': 'open_profile',
      });
    }

    if (mounted) {
      setState(() {
        _notifications = items;
      });
    }
  }

  String _formatRelativeTime(String? iso) {
    if (iso == null || iso.isEmpty) return 'حديثاً';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'حديثاً';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes.clamp(1, 59)} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return 'منذ ${diff.inDays} يوم';
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      try {
        final uniData = await supabase
            .from('universities')
            .select('id, name, logo_url')
            .order('name');
        _universities = List<Map<String, dynamic>>.from(uniData as List);
      } catch (e) {
        debugPrint('Error loading universities from DB: $e');
        if (mounted) showErrorSnack(context, e);
        _universities = [];
      }

      final user = supabase.auth.currentUser;
      if (user != null) {
        String foundName = '';

        if (user.userMetadata != null) {
          final meta = user.userMetadata!;
          final rawName = meta['full_name'] ?? meta['name'];
          if (rawName != null && rawName.toString().trim().isNotEmpty) {
            foundName = rawName.toString().trim();
          }
        }

        if (foundName.isEmpty || double.tryParse(foundName) != null) {
          try {
            final profile = await supabase
                .from('profiles')
                .select()
                .eq('id', user.id)
                .maybeSingle();

            if (profile != null) {
              final pName = profile['full_name'] ?? profile['name'];
              if (pName != null && pName.toString().trim().isNotEmpty) {
                foundName = pName.toString().trim();
              }
            }
          } catch (_) {}
        }

        if (foundName.isEmpty || double.tryParse(foundName) != null) {
          if (user.email != null) {
            foundName = user.email!.split('@').first;
          }
        }

        if (foundName.isEmpty || double.tryParse(foundName) != null) {
          foundName = 'طالب الأكاديمية';
        }

        _studentName = foundName;

        final subscriptions = await supabase
            .from('student_subscriptions')
            .select(
              'subject_id, professor_id, subjects(id, name), professors(id, name)',
            )
            .eq('user_id', user.id)
            .eq('status', 'active');

        _enrolledCourses = (subscriptions as List).map((sub) {
          final subjectData = sub['subjects'];
          final profData = sub['professors'];
          return {
            'id': sub['subject_id'],
            'professor_id': sub['professor_id'],
            'name': subjectData != null
                ? (subjectData['name'] ?? 'مقرر دراسي')
                : 'مقرر دراسي',
            'professor_name': profData != null ? (profData['name'] ?? '') : '',
          };
        }).toList();

        final progress = await WatchProgressService.getLastProgress();
        _lastWatchedLecture = progress;

        await _buildSmartNotifications();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? get _lastLectureMap {
    final raw = _lastWatchedLecture?['lecture'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String get _lastLectureTitle {
    return (_lastLectureMap?['title'] ?? 'محاضرة').toString();
  }

  String get _lastLectureSubjectTitle {
    return (_lastWatchedLecture?['subject_title'] ?? 'مقرر دراسي').toString();
  }

  int get _lastWatchPositionSeconds {
    final raw = _lastWatchedLecture?['position_seconds'];
    if (raw is num) return raw.toInt().clamp(0, 1 << 30);
    return int.tryParse('$raw') ?? 0;
  }

  int get _lastWatchDurationSeconds {
    final raw = _lastWatchedLecture?['total_duration_seconds'];
    int total = 0;
    if (raw is num) {
      total = raw.toInt().clamp(0, 1 << 30);
    } else {
      total = int.tryParse('$raw') ?? 0;
    }

    if (total <= 0) {
      final minsRaw = _lastLectureMap?['duration_minutes'];
      final mins = minsRaw is num
          ? minsRaw.toInt()
          : (int.tryParse('$minsRaw') ?? 0);
      if (mins > 0) {
        total = mins * 60;
      }
    }
    return total;
  }

  double get _lastWatchProgressFraction {
    final total = _lastWatchDurationSeconds;
    if (total <= 0) return 0;
    return (_lastWatchPositionSeconds / total).clamp(0.0, 1.0);
  }

  String _formatWatchClock(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    final seconds = safe % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (hours > 0) return '${two(hours)}:${two(minutes)}:${two(seconds)}';
    return '${two(minutes)}:${two(seconds)}';
  }

  String get _lastWatchProgressLabel {
    final pos = _lastWatchPositionSeconds;
    final total = _lastWatchDurationSeconds;
    if (pos <= 0 && total <= 0) return 'متابعة التشغيل';
    if (total > 0) {
      return '${_formatWatchClock(pos)} / ${_formatWatchClock(total)}';
    }
    return _formatWatchClock(pos);
  }

  Future<void> _openLastWatched() async {
    final progress = _lastWatchedLecture;
    final lecture = _lastLectureMap;
    if (progress == null || lecture == null) return;

    final allRaw = progress['allLectures'];
    final allLectures = allRaw is List
        ? allRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[lecture];
    final startAt = _lastWatchPositionSeconds;

    final subjectId = lecture['subject_id']?.toString();
    if (subjectId != null && subjectId.isNotEmpty) {
      final key = await VaultSecurityService.getOrRenewVaultKey(
        subjectId: subjectId,
        professorId: lecture['professor_id']?.toString(),
      );
      if (key == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              content: Text(
                'انتهت صلاحية الاشتراك في هذا المقرر أو تم إيقافه.',
              ),
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LecturePlayerRouter(
          currentLecture: lecture,
          allLectures: allLectures.isEmpty ? [lecture] : allLectures,
          subjectTitle: _lastLectureSubjectTitle,
          startAtSeconds: startAt,
        ),
      ),
    );
    if (mounted) _loadUserData();
  }

  Future<void> _handleLogout() async {
    setState(() {
      _studentName = '';
      _lastWatchedLecture = null;
      _enrolledCourses.clear();
      _notifications.clear();
      _readNotificationIds.clear();
    });
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  void _showNotificationsSheet(bool isDark) {
    final sheetBg = isDark ? darkCardBg : lightEmeraldDark;
    final surfaceBg = isDark ? darkCardSurface : lightEmeraldLight;
    final borderColor = isDark ? darkGoldBorder : lightGoldBorder;
    String activeFilter = 'all';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final filteredList = _notifications.where((n) {
              final id = n['id'].toString();
              if (activeFilter == 'unread') {
                return !_readNotificationIds.contains(id);
              }
              if (activeFilter == 'lecture') {
                return n['category'] == 'lecture';
              }
              return true;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.76,
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(top: BorderSide(color: borderColor, width: 1.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 25,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: goldAccent.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: surfaceBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: borderColor.withOpacity(0.7),
                            ),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: goldAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'مركز الإشعارات والتنبيهات',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _unreadNotificationsCount > 0
                                    ? 'لديك $_unreadNotificationsCount تنبيهات غير مقروءة'
                                    : 'جميع التنبيهات مقروءة',
                                style: TextStyle(
                                  color: goldAccent.withOpacity(0.85),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_unreadNotificationsCount > 0)
                          TextButton.icon(
                            onPressed: () async {
                              await _markAllNotificationsAsRead();
                              setSheetState(() {});
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: goldAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                            icon: const Icon(Icons.done_all_rounded, size: 16),
                            label: const Text(
                              'قراءة الكل',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'الكل (${_notifications.length})',
                          selected: activeFilter == 'all',
                          surfaceBg: surfaceBg,
                          borderColor: borderColor,
                          onTap: () =>
                              setSheetState(() => activeFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'غير مقروءة ($_unreadNotificationsCount)',
                          selected: activeFilter == 'unread',
                          surfaceBg: surfaceBg,
                          borderColor: borderColor,
                          onTap: () =>
                              setSheetState(() => activeFilter = 'unread'),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'المحاضرات',
                          selected: activeFilter == 'lecture',
                          surfaceBg: surfaceBg,
                          borderColor: borderColor,
                          onTap: () =>
                              setSheetState(() => activeFilter = 'lecture'),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: borderColor.withOpacity(0.25), height: 18),
                  Expanded(
                    child: filteredList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: surfaceBg,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: borderColor.withOpacity(0.5),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_off_outlined,
                                      color: goldAccent,
                                      size: 36,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'لا توجد إشعارات في هذا القسم',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = filteredList[index];
                              final id = item['id'].toString();
                              final isRead = _readNotificationIds.contains(id);
                              final category =
                                  item['category']?.toString() ?? 'admin';

                              IconData itemIcon = Icons.campaign_rounded;
                              if (category == 'lecture') {
                                itemIcon = Icons.play_lesson_rounded;
                              } else if (category == 'security') {
                                itemIcon = Icons.verified_user_rounded;
                              }

                              return Dismissible(
                                key: ValueKey(id),
                                direction: DismissDirection.horizontal,
                                onDismissed: (_) async {
                                  await _dismissNotification(id);
                                  setSheetState(() {});
                                },
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444)
                                        .withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    await _markNotificationAsRead(id);
                                    setSheetState(() {});
                                    final action = item['action_type']
                                        ?.toString();
                                    if (action == 'resume_last') {
                                      if (mounted) Navigator.pop(ctx);
                                      _openLastWatched();
                                    } else if (action == 'open_lecture' &&
                                        item['lecture_data'] != null) {
                                      final lec = Map<String, dynamic>.from(
                                        item['lecture_data'] as Map,
                                      );
                                      final subTitle =
                                          item['subject_title']?.toString() ??
                                          'مقرر دراسي';
                                      if (mounted) {
                                        Navigator.pop(ctx);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => LecturePlayerRouter(
                                              currentLecture: lec,
                                              allLectures: [lec],
                                              subjectTitle: subTitle,
                                            ),
                                          ),
                                        ).then((_) => _loadUserData());
                                      }
                                    } else if (action == 'open_profile') {
                                      if (mounted) {
                                        Navigator.pop(ctx);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ProfileScreen(),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isRead
                                          ? surfaceBg.withOpacity(0.55)
                                          : surfaceBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isRead
                                            ? borderColor.withOpacity(0.25)
                                            : goldAccent,
                                        width: isRead ? 1 : 1.3,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: sheetBg,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: borderColor.withOpacity(
                                                0.5,
                                              ),
                                            ),
                                          ),
                                          child: Icon(
                                            itemIcon,
                                            color: goldAccent,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item['title']
                                                              ?.toString() ??
                                                          '',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13.5,
                                                        fontWeight: isRead
                                                            ? FontWeight.w600
                                                            : FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  if (!isRead)
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: goldAccent,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item['body']?.toString() ?? '',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.75),
                                                  fontSize: 12,
                                                  height: 1.35,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                item['time_label']
                                                        ?.toString() ??
                                                    '',
                                                style: TextStyle(
                                                  color: goldAccent.withOpacity(
                                                    0.85,
                                                  ),
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Color surfaceBg,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? goldAccent : surfaceBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? goldAccent : borderColor.withOpacity(0.45),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showSupportDialog(bool isDark) {
    final dialogBg = isDark ? darkCardBg : lightEmeraldDark;
    final dialogBorder = isDark ? darkGoldBorder : lightGoldBorder;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: dialogBorder.withOpacity(0.6), width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded, color: goldAccent, size: 24),
            SizedBox(width: 10),
            Text(
              'الدعم الفني',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'للاستفسارات أو فك ارتباط الأجهزة، يرجى التواصل مع إدارة المنصة عبر الرقم التالي:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await Clipboard.setData(
                  const ClipboardData(text: '0938409860'),
                );
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                      content: Text('تم نسخ رقم التواصل إلى الحافظة'),
                    ),
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? darkCardSurface : lightEmeraldLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dialogBorder.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.phone_rounded,
                      color: goldAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const SelectableText(
                      '0938409860',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: goldAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.copy_rounded,
                      color: goldAccent.withOpacity(0.7),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'إغلاق',
              style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showCourseActivationDialog(bool isDark) {
    final TextEditingController codeController = TextEditingController();
    String? errorMessage;
    bool isVerifying = false;

    final dialogBg = isDark ? darkCardBg : lightEmeraldDark;
    final dialogBorder = isDark ? darkGoldBorder : lightGoldBorder;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ActivationDialog',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curvedValue = Curves.easeOutBack.transform(anim1.value);
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Transform.scale(
              scale: curvedValue,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 420,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: dialogBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: errorMessage != null
                            ? const Color(0xFFEF4444)
                            : dialogBorder.withOpacity(0.9),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: errorMessage != null
                              ? const Color(0xFFEF4444).withOpacity(0.2)
                              : dialogBorder.withOpacity(0.22),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: errorMessage != null
                                    ? [
                                        const Color(0xFFEF4444),
                                        const Color(0xFF991B1B),
                                      ]
                                    : [
                                        isDark
                                            ? darkCardSurface
                                            : lightEmeraldLight,
                                        dialogBorder,
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: dialogBorder,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              errorMessage != null
                                  ? Icons.error_outline_rounded
                                  : Icons.vpn_key_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'تفعيل مقرر جديد',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? darkInputBg
                                  : const Color(0xFF08221E),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: errorMessage != null
                                    ? const Color(0xFFEF4444)
                                    : dialogBorder,
                                width: 1.2,
                              ),
                            ),
                            child: TextField(
                              controller: codeController,
                              textAlign: TextAlign.center,
                              onChanged: (_) {
                                if (errorMessage != null) {
                                  setDialogState(() => errorMessage = null);
                                }
                              },
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                              ),
                              decoration: InputDecoration(
                                hintText: 'XXX-XXX-XX-XXXX',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 14,
                                  letterSpacing: 1.5,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 15,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_open_rounded,
                                  color: errorMessage != null
                                      ? const Color(0xFFEF4444)
                                      : goldAccent,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          if (errorMessage != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isVerifying
                                      ? null
                                      : () => Navigator.pop(dialogContext),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: dialogBorder.withOpacity(0.5),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: const Text(
                                    'إلغاء',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: const LinearGradient(
                                      colors: [goldAccent, Color(0xFFD6B56F)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: dialogBorder.withOpacity(0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: isVerifying
                                        ? null
                                        : () async {
                                            final enteredCode = codeController
                                                .text
                                                .trim();

                                            if (enteredCode.isEmpty) {
                                              setDialogState(
                                                () => errorMessage =
                                                    'يرجى إدخال كود التفعيل',
                                              );
                                              return;
                                            }

                                            setDialogState(() {
                                              isVerifying = true;
                                              errorMessage = null;
                                            });

                                            try {
                                              final currentUser =
                                                  supabase.auth.currentUser;
                                              if (currentUser == null) {
                                                setDialogState(() {
                                                  isVerifying = false;
                                                  errorMessage =
                                                      'يجب تسجيل الدخول أولاً';
                                                });
                                                return;
                                              }

                                              final fingerprint =
                                                  await DeviceService.getFingerprint();
                                              final result =
                                                  Map<String, dynamic>.from(
                                                    await supabase.rpc(
                                                      'activate_code',
                                                      params: {
                                                        'p_code': enteredCode,
                                                        'p_fingerprint':
                                                            fingerprint,
                                                      },
                                                    ) as Map,
                                                  );
                                              if (result['ok'] != true) {
                                                setDialogState(() {
                                                  isVerifying = false;
                                                  errorMessage =
                                                      activationErrorMessage(
                                                        result['error']
                                                            ?.toString(),
                                                      );
                                                });
                                                return;
                                              }
                                              final String subjectTitle =
                                                  (result['subject_name'] ??
                                                          'المقرر')
                                                      .toString();

                                              setDialogState(
                                                () => isVerifying = false,
                                              );
                                              if (mounted) {
                                                Navigator.pop(dialogContext);
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'تم تفعيل $subjectTitle بنجاح',
                                                    ),
                                                    backgroundColor:
                                                        const Color(0xFF10B981),
                                                  ),
                                                );
                                                _loadUserData();
                                              }
                                            } catch (e) {
                                              setDialogState(() {
                                                isVerifying = false;
                                                errorMessage = friendlyError(e);
                                              });
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    child: isVerifying
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'تفعيل',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkScaffoldBg : lightScaffoldBg;
    final appBarColor = isDark ? darkCardBg : lightEmeraldDark;
    final unreadCount = _unreadNotificationsCount;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: scaffoldBg,
      drawer: _buildDrawer(isDark),
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'أكاديمية MEDNERD',
          style: TextStyle(
            color: goldAccent,
            fontWeight: FontWeight.bold,
            fontSize: 19,
            letterSpacing: 0.8,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: goldAccent),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: goldAccent,
              size: 22,
            ),
            onPressed: toggleTheme,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'الإشعارات',
                icon: Icon(
                  unreadCount > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: goldAccent,
                  size: 23,
                ),
                onPressed: () => _showNotificationsSheet(isDark),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: appBarColor, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        color: goldAccent,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: goldAccent))
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(isDark)),
                  if (_lastWatchedLecture != null)
                    SliverToBoxAdapter(child: _buildContinueWatching(isDark)),
                  SliverToBoxAdapter(
                    child: _buildEnrolledCoursesSection(isDark),
                  ),
                  SliverToBoxAdapter(child: _buildUniversitySection(isDark)),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCourseActivationDialog(isDark),
        backgroundColor: goldAccent,
        icon: const Icon(
          Icons.vpn_key_rounded,
          color: Colors.black87,
          size: 20,
        ),
        label: const Text(
          'تفعيل مقرر',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 26),
      decoration: BoxDecoration(
        color: isDark ? darkCardBg : lightEmeraldDark,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أهلاً بك،',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _studentName.isNotEmpty ? _studentName : 'طالب الأكاديمية',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueWatching(bool isDark) {
    if (_lastWatchedLecture == null) return const SizedBox.shrink();

    final posSec = _lastWatchPositionSeconds;
    final totalSec = _lastWatchDurationSeconds;
    final fraction = _lastWatchProgressFraction;
    final percentText = totalSec > 0 ? '${(fraction * 100).round()}%' : '';
    final cardBgColor = isDark ? darkCardBg : lightEmeraldDark;
    final cardBorderColor = isDark ? darkGoldBorder : lightGoldBorder;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 4, bottom: 10),
            child: Text(
              'تابع المشاهدة',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: _openLastWatched,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: cardBorderColor.withOpacity(0.7),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: isDark ? darkCardSurface : lightEmeraldLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: cardBorderColor.withOpacity(0.6),
                          ),
                        ),
                        child: const Center(
                          child: CircleAvatar(
                            radius: 17,
                            backgroundColor: lightEmeraldDark,
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: goldAccent,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lastLectureTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _lastLectureSubjectTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 13.5,
                                  color: goldAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _lastWatchProgressLabel,
                                  style: const TextStyle(
                                    color: goldAccent,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: goldAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: totalSec > 0 ? fraction : 0.15,
                            minHeight: 5,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              goldAccent,
                            ),
                          ),
                        ),
                      ),
                      if (percentText.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(
                          percentText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: goldAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrolledCoursesSection(bool isDark) {
    final cardBgColor = isDark ? darkCardBg : lightEmeraldDark;
    final cardBorderColor = isDark ? darkGoldBorder : lightGoldBorder;

    if (_enrolledCourses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: cardBorderColor.withOpacity(0.7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.school_outlined,
                size: 44,
                color: goldAccent.withOpacity(0.8),
              ),
              const SizedBox(height: 12),
              const Text(
                'لا توجد مقررات مفعلة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _showCourseActivationDialog(isDark),
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldAccent,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'تفعيل مقرر',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Text(
              'مقرراتي المفعلة',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
            ),
          ),
          ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _enrolledCourses.length,
            itemBuilder: (ctx, idx) {
              final course = _enrolledCourses[idx];
              final profName = (course['professor_name'] ?? '')
                  .toString()
                  .trim();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseDetailsScreen(
                          subjectId: course['id'].toString(),
                          subjectTitle:
                              course['name']?.toString() ?? 'مقرر دراسي',
                          professorId: course['professor_id']?.toString(),
                          professorName: course['professor_name']?.toString(),
                        ),
                      ),
                    ).then((_) => _loadUserData());
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cardBorderColor.withOpacity(0.7),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? darkCardSurface
                                  : lightEmeraldLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: cardBorderColor.withOpacity(0.6),
                              ),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: goldAccent,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course['name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                                if (profName.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'د. $profName',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 15,
                            color: goldAccent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUniversitySection(bool isDark) {
    if (_universities.isEmpty) return const SizedBox.shrink();
    final cardBgColor = isDark ? darkCardBg : lightEmeraldDark;
    final cardBorderColor = isDark ? darkGoldBorder : lightGoldBorder;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Text(
              'الجامعات',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 135,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _universities.length,
              itemBuilder: (ctx, idx) {
                final uni = _universities[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UniversityFacultiesScreen(
                            universityId: uni['id'].toString(),
                            universityName: uni['name']?.toString() ?? '',
                          ),
                        ),
                      ).then((_) => _loadUserData());
                    },
                    child: Container(
                      width: 120,
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: cardBorderColor.withOpacity(0.7),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: uni['logo_url'] != null
                                  ? Image.network(
                                      uni['logo_url'],
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.account_balance_rounded,
                                        size: 38,
                                        color: goldAccent,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.account_balance_rounded,
                                      size: 38,
                                      color: goldAccent,
                                    ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? darkCardSurface
                                  : lightEmeraldLight,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                              border: Border(
                                top: BorderSide(
                                  color: cardBorderColor.withOpacity(0.5),
                                ),
                              ),
                            ),
                            child: Text(
                              uni['name'] ?? '',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? darkScaffoldBg : lightScaffoldBg,
      child: Column(
        children: [
          _buildDrawerHeader(isDark),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _buildDrawerItem(
                  isDark: isDark,
                  icon: Icons.home_rounded,
                  title: 'الرئيسية',
                  index: 0,
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  isDark: isDark,
                  icon: Icons.school_rounded,
                  title: 'مقرراتي',
                  index: 1,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyCoursesScreen(),
                      ),
                    ).then((_) {
                      if (mounted) {
                        setState(() => _selectedDrawerIndex = 0);
                        _loadUserData();
                      }
                    });
                  },
                ),
                _buildDrawerItem(
                  isDark: isDark,
                  icon: Icons.quiz_rounded,
                  title: 'بنك الأسئلة',
                  index: 2,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuizScreen()),
                    ).then((_) {
                      if (mounted) {
                        setState(() => _selectedDrawerIndex = 0);
                        _loadUserData();
                      }
                    });
                  },
                ),
                _buildDrawerItem(
                  isDark: isDark,
                  icon: Icons.favorite_rounded,
                  title: 'المفضلة',
                  index: 3,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FavoritesScreen(),
                      ),
                    ).then((_) {
                      if (mounted) {
                        setState(() => _selectedDrawerIndex = 0);
                        _loadUserData();
                      }
                    });
                  },
                ),
                _buildDrawerItem(
                  isDark: isDark,
                  icon: Icons.download_rounded,
                  title: 'المحملات',
                  index: 4,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DownloadsScreen(),
                      ),
                    ).then((_) {
                      if (mounted) {
                        setState(() => _selectedDrawerIndex = 0);
                        _loadUserData();
                      }
                    });
                  },
                ),
                const Divider(height: 28, indent: 20, endIndent: 20),
                _buildDrawerItem(
                  isDark: isDark,
                  icon: Icons.person_rounded,
                  title: 'الملف الشخصي',
                  index: 5,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ).then((_) {
                      if (mounted) {
                        setState(() => _selectedDrawerIndex = 0);
                        _loadUserData();
                      }
                    });
                  },
                ),
                _buildDrawerItem(
                  isDark: isDark,
                  icon: Icons.support_agent_rounded,
                  title: 'الدعم الفني',
                  index: 6,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedDrawerIndex = 0);
                    _showSupportDialog(isDark);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ListTile(
              onTap: _handleLogout,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              tileColor: Colors.red.withOpacity(0.08),
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 26),
      decoration: BoxDecoration(color: isDark ? darkCardBg : lightEmeraldDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: goldAccent.withOpacity(0.2),
            child: const Icon(
              Icons.person_rounded,
              color: goldAccent,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _studentName.isNotEmpty ? _studentName : 'طالب الأكاديمية',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            supabase.auth.currentUser?.email ?? '',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required bool isDark,
    required IconData icon,
    required String title,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedDrawerIndex == index;
    const activeTextColor = goldAccent;
    final inactiveTextColor = isDark ? Colors.white70 : lightEmeraldDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: isSelected
            ? goldAccent.withOpacity(isDark ? 0.18 : 0.22)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: goldAccent.withOpacity(0.3),
          highlightColor: goldAccent.withOpacity(0.18),
          onTap: () {
            setState(() => _selectedDrawerIndex = index);
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: isSelected
                  ? Border.all(color: goldAccent.withOpacity(0.6), width: 1.2)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? goldAccent
                      : inactiveTextColor.withOpacity(0.8),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? activeTextColor : inactiveTextColor,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: goldAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
