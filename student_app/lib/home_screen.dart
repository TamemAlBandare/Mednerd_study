import 'package:flutter/material.dart';

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
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
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
        content: Text(
          'للاستفسارات أو فك ارتباط الأجهزة، يرجى التواصل مع إدارة المنصة.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
            height: 1.45,
          ),
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
          IconButton(
            tooltip: 'الإشعارات',
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: goldAccent,
              size: 22,
            ),
            onPressed: () {},
          ),
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
                  SliverToBoxAdapter(child: _buildUniversitySection(isDark)),
                  SliverToBoxAdapter(
                    child: _buildEnrolledCoursesSection(isDark),
                  ),
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
                color: isDark ? darkCardBg : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: (isDark ? darkGoldBorder : lightGoldBorder)
                      .withOpacity(0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
                          color: isDark
                              ? darkCardSurface
                              : lightEmeraldDark.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: isDark ? Colors.white : lightEmeraldDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _lastLectureSubjectTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade600,
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
                                  style: TextStyle(
                                    color: isDark
                                        ? goldAccent
                                        : lightEmeraldDark,
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
                        color: Colors.grey,
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
                            backgroundColor: Colors.grey.withOpacity(0.2),
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
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? goldAccent : lightEmeraldDark,
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

  Widget _buildUniversitySection(bool isDark) {
    if (_universities.isEmpty) return const SizedBox.shrink();

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
                        color: isDark ? darkCardBg : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isDark ? darkGoldBorder : lightGoldBorder)
                              .withOpacity(0.2),
                        ),
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
                                  : lightEmeraldLight.withOpacity(0.05),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                            ),
                            child: Text(
                              uni['name'] ?? '',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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

  Widget _buildEnrolledCoursesSection(bool isDark) {
    if (_enrolledCourses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? darkCardBg : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: (isDark ? darkGoldBorder : lightGoldBorder).withOpacity(
                0.2,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.school_outlined,
                size: 44,
                color: goldAccent.withOpacity(0.6),
              ),
              const SizedBox(height: 12),
              const Text(
                'لا توجد مقررات مفعلة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
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
                      color: isDark ? darkCardBg : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: (isDark ? darkGoldBorder : lightGoldBorder)
                            .withOpacity(0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
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
                              color: isDark ? darkCardSurface : lightScaffoldBg,
                              borderRadius: BorderRadius.circular(14),
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
                                  ),
                                ),
                                if (profName.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'د. $profName',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
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
                            color: Colors.grey,
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
    final activeTextColor = isDark ? goldAccent : lightEmeraldDark;
    final inactiveTextColor = isDark ? Colors.white70 : Colors.black87;

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
                  color: isSelected ? goldAccent : Colors.grey.shade500,
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
                          : FontWeight.w500,
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
