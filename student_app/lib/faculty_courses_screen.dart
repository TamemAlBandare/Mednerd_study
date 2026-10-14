import 'package:flutter/material.dart';

import 'main.dart';
import 'subject_professors_screen.dart';
import 'backend_errors.dart';

class FacultyCoursesScreen extends StatefulWidget {
  final String facultyId;
  final String facultyTitle;
  final IconData facultyIcon;

  const FacultyCoursesScreen({
    super.key,
    required this.facultyId,
    required this.facultyTitle,
    required this.facultyIcon,
  });

  @override
  State<FacultyCoursesScreen> createState() => _FacultyCoursesScreenState();
}

class _FacultyCoursesScreenState extends State<FacultyCoursesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _courses = [];

  static const Color darkScaffoldBg = Color(0xFF0B0F17);
  static const Color darkCardBg = Color(0xFF151E2E);
  static const Color darkCardSurface = Color(0xFF1E2B40);

  static const Color lightScaffoldBg = Color(0xFFF3EFE6);
  static const Color lightEmeraldDark = Color(0xFF0E332E);
  static const Color lightEmeraldLight = Color(0xFF15443E);

  static const Color goldAccent = Color(0xFFD8B467);
  static const Color goldBorder = Color(0xFFC5A059);

  @override
  void initState() {
    super.initState();
    _fetchFacultyCourses();
  }

  Future<void> _fetchFacultyCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await supabase
          .from('subjects')
          .select('id, name, code_prefix')
          .eq('faculty_id', widget.facultyId)
          .order('name');

      if (mounted) {
        setState(() {
          _courses = List<Map<String, dynamic>>.from(data as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر تحميل المقررات. ${friendlyError(e)}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkScaffoldBg : lightScaffoldBg;
    final cardBg = isDark ? darkCardBg : lightEmeraldDark;
    final cardSurface = isDark ? darkCardSurface : lightEmeraldLight;
    final textColor = isDark ? Colors.white : lightEmeraldDark;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(color: goldBorder.withOpacity(0.35), width: 1),
        ),
        title: Row(
          children: [
            Icon(widget.facultyIcon, color: goldAccent, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.facultyTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchFacultyCourses,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: goldAccent,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            )
          : _courses.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.facultyIcon,
                    color: goldAccent.withOpacity(0.6),
                    size: 54,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'لا توجد مقررات مدرجة حالياً',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: goldAccent,
              onRefresh: _fetchFacultyCourses,
              child: ListView.separated(
                padding: const EdgeInsets.all(18),
                itemCount: _courses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  final courseId = course['id'].toString();
                  final courseName = course['name'] ?? 'مقرر دراسي';

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubjectProfessorsScreen(
                            subjectId: courseId,
                            subjectName: courseName,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: goldBorder.withOpacity(0.4),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cardSurface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: goldBorder.withOpacity(0.6),
                              ),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: goldAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              courseName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: goldAccent,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
