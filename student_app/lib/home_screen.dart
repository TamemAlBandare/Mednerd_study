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
          if (meta['full_name'] != null &&
              meta['full_name'].toString().trim().isNotEmpty) {
            foundName = meta['full_name'].toString().trim();
          } else if (meta['name'] != null &&
              meta['name'].toString().trim().isNotEmpty) {
            foundName = meta['name'].toString().trim();
          }
        }

        if (foundName.isEmpty) {
          final profile = await supabase
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

          if (profile != null) {
            if (profile['full_name'] != null &&
                profile['full_name'].toString().trim().isNotEmpty) {
              foundName = profile['full_name'].toString().trim();
            } else if (profile['name'] != null &&
                profile['name'].toString().trim().isNotEmpty) {
              foundName = profile['name'].toString().trim();
            }
          }
        }

        if (foundName.isEmpty && user.email != null) {
          foundName = user.email!.split('@').first;
        }

        if (foundName.isNotEmpty) {
          _studentName = foundName;
        }

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
    if (raw is num) return raw.toInt().clamp(0, 1 << 30);
    return int.tryParse('$raw') ?? 0;
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
    if (pos <= 0 && total <= 0) return 'متابعة من حيث توقفت';
    if (total > 0) {
      return 'توقفت عند ${_formatWatchClock(pos)} من ${_formatWatchClock(total)}';
    }
    return 'توقفت عند ${_formatWatchClock(pos)}';
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
    final startAt = (progress['position_seconds'] as num?)?.toInt();

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
              'الدعم الفني ومجتمع الطلاب',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'للاستفسارات الأكاديمية، فك ارتباط الأجهزة، أو الانضمام لمجتمع الدفعة على تيليجرام وواتساب، يرجى التواصل مع الإدارة المركزية.',
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
                            width: 60,
                            height: 60,
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
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'تفعيل اشتراك مقرر',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'أدخل الرمز لفتح المحاضرات وبنك الأسئلة فوراً.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
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
                          const SizedBox(height: 24),
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
                                                      'تم تفعيل $subjectTitle بنجاح!',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                                _loadUserData();
                                              }
                                            } catch (e) {
                                              setDialogState(() {
                                                isVerifying = false;
                                                errorMessage = e.toString();
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
                                            'تفعيل الآن',
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
        title: Image.asset(
          'assets/logo_horizontal.png',
          height: 32,
          errorBuilder: (_, __, ___) => const Text(
            'أكاديمية فVault',
            style: TextStyle(
              color: goldAccent,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: goldAccent),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: goldAccent,
            ),
            onPressed: () {
              // Notifications logic
            },
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
        icon: const Icon(Icons.add_moderator_rounded, color: Colors.black87),
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      decoration: BoxDecoration(
        color: isDark ? darkCardBg : lightEmeraldDark,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أهلاً بك،',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _studentName.isNotEmpty ? _studentName : 'أيها الطالب المتميز',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? darkCardSurface : lightEmeraldLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isDark ? darkGoldBorder : lightGoldBorder).withOpacity(
                  0.3,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: goldAccent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'اختر جامعتك للوصول إلى المحاضرات والملخصات الخاصة بك.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueWatching(bool isDark) {
    if (_lastWatchedLecture == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 4, bottom: 12),
            child: Text(
              'تابع المشاهدة',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: _openLastWatched,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? darkCardBg : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: const DecorationImage(
                            image: AssetImage('assets/lecture_placeholder.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.black45,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 15),
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
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _lastLectureSubjectTitle,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUniversitySection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 25, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              'الجامعات المتاحة',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 140,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _universities.length,
              itemBuilder: (ctx, idx) {
                final uni = _universities[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UniversityFacultiesScreen(
                            universityId: uni['id'].toString(),
                            universityName: uni['name']?.toString() ?? '',
                          ),
                        ),
                      );
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
                              padding: const EdgeInsets.all(15),
                              child: uni['logo_url'] != null
                                  ? Image.network(
                                      uni['logo_url'],
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.account_balance_rounded,
                                        size: 40,
                                        color: goldAccent,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.account_balance_rounded,
                                      size: 40,
                                      color: goldAccent,
                                    ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
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
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: isDark ? darkCardBg : Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: (isDark ? darkGoldBorder : lightGoldBorder).withOpacity(
                0.15,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.school_outlined,
                size: 50,
                color: goldAccent.withOpacity(0.5),
              ),
              const SizedBox(height: 15),
              const Text(
                'لا توجد مقررات مفعلة حالياً',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'قم بتفعيل مقرراتك باستخدام الرموز التي حصلت عليها.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _showCourseActivationDialog(isDark),
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldAccent,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('تفعيل أول مقرر'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 30, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'مقرراتي المفعلة',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _enrolledCourses.length,
            itemBuilder: (ctx, idx) {
              final course = _enrolledCourses[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: InkWell(
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
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? darkCardBg : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: (isDark
                                  ? darkCardSurface
                                  : lightScaffoldBg),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: goldAccent,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 15),
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
                                const SizedBox(height: 4),
                                Text(
                                  'د. ${course['professor_name'] ?? ''}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
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
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.home_rounded,
                  title: 'الرئيسية',
                  index: 0,
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
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
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.favorite_rounded,
                  title: 'المفضلة',
                  index: 2,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FavoritesScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.download_rounded,
                  title: 'المحملات',
                  index: 3,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DownloadsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 40, indent: 20, endIndent: 20),
                _buildDrawerItem(
                  icon: Icons.person_rounded,
                  title: 'الملف الشخصي',
                  index: 4,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.support_agent_rounded,
                  title: 'الدعم الفني',
                  index: 5,
                  onTap: () {
                    Navigator.pop(context);
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
              tileColor: Colors.red.withOpacity(0.05),
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
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: BoxDecoration(color: isDark ? darkCardBg : lightEmeraldDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: goldAccent.withOpacity(0.2),
            child: const Icon(
              Icons.person_rounded,
              color: goldAccent,
              size: 40,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            _studentName.isNotEmpty ? _studentName : 'أهلاً بك',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            supabase.auth.currentUser?.email ?? '',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedDrawerIndex == index;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: isSelected ? goldAccent : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? goldAccent : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      selected: isSelected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
