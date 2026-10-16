import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';
import 'hierarchy_label.dart';
import 'course_details_screen.dart';
import 'backend_errors.dart';

class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _courses = [];
  final Map<String, double> _courseProgress = {};

  @override
  void initState() {
    super.initState();
    _fetchEnrolledCourses();
  }

  String _safeStr(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final s = value.toString().trim();
    return (s.isEmpty || s == 'null') ? fallback : s;
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _safeMapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> _fetchEnrolledCourses() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('student_subscriptions')
            .select(
              'subject_id, professor_id, activated_at, subjects(id, name, universities(name), faculties(name)), professors(id, name, bio)',
            )
            .eq('user_id', user.id)
            .eq('status', 'active');

        final coursesList = _safeMapList(data);

        for (final item in coursesList) {
          final subId = _safeStr(item['subject_id']);
          if (subId.isNotEmpty) {
            try {
              final lectures = await Supabase.instance.client
                  .from('lectures')
                  .select('id')
                  .eq('subject_id', subId);
              final totalLecs = _safeMapList(lectures).length;
              _courseProgress[subId] = totalLecs > 0 ? 0.35 : 0.0;
            } catch (_) {
              _courseProgress[subId] = 0.2;
            }
          }
        }

        if (mounted) {
          setState(() {
            _courses = coursesList;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading my courses: $e');
      if (mounted) {
        setState(() => _errorMessage = friendlyError(e));
        showErrorSnack(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? const Color(0xFF0B0F17)
        : const Color(0xFFF3EFE6);
    final cardBg = isDark ? const Color(0xFF151E2E) : const Color(0xFF0E332E);
    final cardSurface = isDark
        ? const Color(0xFF1E2B40)
        : const Color(0xFF15443E);
    const border = Color(0xFFC5A059);
    const goldAccent = Color(0xFFD8B467);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(color: border.withOpacity(0.35), width: 1),
        ),
        title: const Text(
          'مقرراتي المفعلة',
          style: TextStyle(
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
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: border.withOpacity(0.7),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: goldAccent,
                        size: 44,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _fetchEnrolledCourses,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: goldAccent,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'إعادة المحاولة',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : _courses.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: border.withOpacity(0.7),
                      width: 1.2,
                    ),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_off_outlined,
                        color: goldAccent,
                        size: 46,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'لا توجد مقررات مفعلة حالياً',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: _courses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = _courses[index];
                final subject = _safeMap(item['subjects']);
                final prof = _safeMap(item['professors']);
                final profName = _safeStr(prof['name']);
                final subId = _safeStr(item['subject_id']);
                final profId = _safeStr(item['professor_id']);
                final subName = _safeStr(subject['name'], 'مقرر دراسي');
                final pathLabel = hierarchyPath(subject);
                final progressVal = (_courseProgress[subId] ?? 0.0).clamp(
                  0.0,
                  1.0,
                );
                final progressPercent = '${(progressVal * 100).toInt()}%';

                return InkWell(
                  onTap: () {
                    if (subId.isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseDetailsScreen(
                          subjectId: subId,
                          subjectTitle: subName,
                          professorId: profId.isEmpty ? null : profId,
                          professorName: profName.isEmpty ? null : profName,
                        ),
                      ),
                    ).then((_) => _fetchEnrolledCourses());
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: border.withOpacity(0.65),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.16),
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
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: cardSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: border.withOpacity(0.6),
                                ),
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: goldAccent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (pathLabel.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      pathLabel,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  if (profName.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      'د. $profName',
                                      style: TextStyle(
                                        color: goldAccent.withOpacity(0.9),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: goldAccent,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Text(
                              'نسبة الإنجاز',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              progressPercent,
                              style: const TextStyle(
                                color: goldAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressVal,
                            minHeight: 5,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              goldAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
