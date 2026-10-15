import 'package:flutter/material.dart';

import 'main.dart';
import 'youtube_lecture_screen.dart';
import 'device_service.dart';
import 'backend_errors.dart';
import 'quiz_screen.dart';

class CourseDetailsScreen extends StatefulWidget {
  final String subjectId;
  final String subjectTitle;
  final String? professorId;
  final String? professorName;

  const CourseDetailsScreen({
    super.key,
    required this.subjectId,
    required this.subjectTitle,
    this.professorId,
    this.professorName,
  });

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _lectures = [];
  Map<String, dynamic>? _professor;

  static const Color lightScaffoldBg = Color(0xFFF3EFE6);
  static const Color lightEmeraldDark = Color(0xFF0E332E);
  static const Color lightEmeraldLight = Color(0xFF15443E);
  static const Color lightEmeraldInner = Color(0xFF08221E);
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
    _fetchCourseContent();
  }

  Future<void> _fetchCourseContent() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final fingerprint = await DeviceService.getFingerprint();
      final pid = widget.professorId?.trim();
      final gate = Map<String, dynamic>.from(
        await supabase.rpc(
          'get_vault_key',
          params: {
            'p_subject_id': widget.subjectId,
            'p_professor_id': (pid == null || pid.isEmpty) ? null : pid,
            'p_fingerprint': fingerprint,
          },
        ) as Map,
      );

      if (gate['ok'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              content: Text(accessDeniedMessage(gate['reason']?.toString())),
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      var query = supabase
          .from('lectures')
          .select('*, professors(id, name, bio, avatar_url)')
          .eq('subject_id', widget.subjectId);

      if (widget.professorId != null && widget.professorId!.trim().isNotEmpty) {
        query = query.eq('professor_id', widget.professorId!.trim());
      }

      final response = await query.order('order_index', ascending: true);
      final lecturesList = List<Map<String, dynamic>>.from(response);

      Map<String, dynamic>? profInfo;

      if (lecturesList.isNotEmpty && lecturesList.first['professors'] != null) {
        profInfo = Map<String, dynamic>.from(lecturesList.first['professors']);
      } else if (widget.professorId != null &&
          widget.professorId!.trim().isNotEmpty) {
        final profData = await supabase
            .from('professors')
            .select('id, name, bio, avatar_url')
            .eq('id', widget.professorId!)
            .maybeSingle();
        if (profData != null) {
          profInfo = Map<String, dynamic>.from(profData);
        }
      }

      if (mounted) {
        setState(() {
          _lectures = lecturesList;
          _professor = profInfo;
        });
      }
    } catch (e) {
      debugPrint('Error fetching lectures: $e');
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkScaffoldBg : lightScaffoldBg;
    final appBarBg = isDark ? darkCardBg : lightEmeraldDark;
    final border = isDark ? darkGoldBorder : lightGoldBorder;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: false,
        shape: Border(
          bottom: BorderSide(color: border.withOpacity(0.3), width: 1),
        ),
        title: Text(
          widget.subjectTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: goldAccent,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: goldAccent,
              size: 20,
            ),
            onPressed: toggleTheme,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: goldAccent))
          : RefreshIndicator(
              color: goldAccent,
              onRefresh: _fetchCourseContent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCourseHeaderCard(isDark),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      'المحاضرات (${_lectures.length})',
                      isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildLecturesList(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCourseHeaderCard(bool isDark) {
    final border = isDark ? darkGoldBorder : lightGoldBorder;
    final gradientColors = isDark
        ? const [darkCardBg, darkCardSurface]
        : const [lightEmeraldDark, lightEmeraldLight];
    final iconCircleBg = isDark ? darkInputBg : lightEmeraldInner;

    String profDisplayText = '';
    if (_professor != null) {
      final name = (_professor!['name'] ?? '').toString().trim();
      final bio = (_professor!['bio'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        profDisplayText = bio.isNotEmpty ? '$bio - د. $name' : 'د. $name';
      }
    } else if (widget.professorName != null &&
        widget.professorName!.trim().isNotEmpty) {
      profDisplayText = 'د. ${widget.professorName!.trim()}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: border, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconCircleBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: border.withOpacity(0.8),
                    width: 1.2,
                  ),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: goldAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subjectTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (profDisplayText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        profDisplayText,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: border.withOpacity(0.3), height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCourseStatItem(
                Icons.play_lesson_outlined,
                '${_lectures.length} محاضرة',
              ),
              Container(width: 1, height: 20, color: border.withOpacity(0.3)),
              _buildCourseStatItem(Icons.verified_rounded, 'مفعّل'),
              Container(width: 1, height: 20, color: border.withOpacity(0.3)),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(
                        title: widget.subjectTitle,
                        subjectId: widget.subjectId,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: _buildCourseStatItem(
                    Icons.quiz_outlined,
                    'بنك الأسئلة',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourseStatItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: goldAccent, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    final titleColor = isDark ? Colors.white : lightEmeraldDark;

    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: goldAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLecturesList(bool isDark) {
    final cardBg = isDark ? darkCardBg : lightEmeraldDark;
    final border = isDark ? darkGoldBorder : lightGoldBorder;
    final indexBg = isDark ? darkInputBg : lightEmeraldInner;

    if (_lectures.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border.withOpacity(0.6), width: 1.2),
        ),
        child: const Column(
          children: [
            Icon(Icons.video_library_outlined, color: goldAccent, size: 38),
            SizedBox(height: 10),
            Text(
              'لا توجد محاضرات مضافة حالياً',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _lectures.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final lecture = _lectures[index];
        final hasDuration =
            lecture['duration_minutes'] != null &&
            lecture['duration_minutes'].toString() != '0';
        final hasPdf =
            (lecture['telegram_pdf_id'] != null &&
                lecture['telegram_pdf_id'].toString().trim().isNotEmpty) ||
            (lecture['pdf_url'] != null &&
                lecture['pdf_url'].toString().trim().isNotEmpty);

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LecturePlayerRouter(
                  currentLecture: lecture,
                  allLectures: _lectures,
                  subjectTitle: widget.subjectTitle,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: indexBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: border.withOpacity(0.6),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${lecture['order_index'] ?? index + 1}',
                      style: const TextStyle(
                        color: goldAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
                        lecture['title'] ?? 'محاضرة ${index + 1}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      if (hasDuration || hasPdf) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (hasDuration) ...[
                              Icon(
                                Icons.access_time_rounded,
                                color: Colors.white.withOpacity(0.6),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${lecture['duration_minutes']} دقيقة',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (hasDuration && hasPdf)
                              const SizedBox(width: 12),
                            if (hasPdf) ...[
                              const Icon(
                                Icons.picture_as_pdf_outlined,
                                color: goldAccent,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'PDF',
                                style: TextStyle(
                                  color: goldAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'اختبار المحاضرة',
                  icon: const Icon(
                    Icons.quiz_outlined,
                    color: goldAccent,
                    size: 22,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizScreen(
                          title: lecture['title']?.toString() ?? 'المحاضرة',
                          lectureId: lecture['id']?.toString(),
                          subjectId: widget.subjectId,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.play_circle_fill_rounded,
                  color: goldAccent,
                  size: 30,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
