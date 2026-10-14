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
  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _fetchEnrolledCourses();
  }

  Future<void> _fetchEnrolledCourses() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('student_subscriptions')
            .select('subject_id, professor_id, activated_at, subjects(id, name, code_prefix, universities(name), faculties(name)), professors(id, name, bio)')
            .eq('user_id', user.id)
            .eq('status', 'active');

        setState(() {
          _courses = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading my courses: $e');
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // قراءة الثيم مباشرة من نظام فلاتر المركزي
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0B0F17) : const Color(0xFFF3EFE6);
    final cardBg = isDark ? const Color(0xFF151E2E) : const Color(0xFF0E332E);
    final cardSurface = isDark ? const Color(0xFF1E2B40) : const Color(0xFF15443E);
    final border = const Color(0xFFC5A059);
    final goldAccent = const Color(0xFFD8B467);
    final textColor = isDark ? Colors.white : const Color(0xFF0E332E);

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
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: goldAccent, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'التحويل للوضع المضيء' : 'التحويل للوضع الليلي',
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
          ? Center(child: CircularProgressIndicator(color: goldAccent))
          : _courses.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_off_outlined, color: goldAccent, size: 48),
                        const SizedBox(height: 14),
                        Text(
                          'لا توجد مقررات مفعلة حالياً',
                          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'قم بتفعيل كود الاشتراك من القائمة الجانبية لتظهر مقرراتك هنا.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: _courses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _courses[index];
                    final subject = item['subjects'] ?? {};
                    final prof = item['professors'] ?? {};

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourseDetailsScreen(
                              subjectId: item['subject_id'],
                              subjectTitle: subject['name'] ?? 'مقرر دراسي',
                              professorId: item['professor_id'],
                              professorName: prof['name'],
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
                          border: Border.all(color: border.withOpacity(0.4), width: 1.2),
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
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: cardSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border.withOpacity(0.6)),
                              ),
                              child: Icon(Icons.school_rounded, color: goldAccent, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject['name'] ?? 'المقرر الأكاديمي',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (hierarchyPath(subject).isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      hierarchyPath(subject),
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    prof['name'] != null ? 'د. ${prof['name']}' : 'أستاذ المادة',
                                    style: TextStyle(
                                      color: goldAccent.withOpacity(0.9),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, color: goldAccent, size: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}