import 'package:flutter/material.dart';
import 'main.dart';
import 'faculty_courses_screen.dart';
import 'backend_errors.dart';

class UniversityFacultiesScreen extends StatefulWidget {
  final String universityId;
  final String universityName;

  const UniversityFacultiesScreen({
    super.key,
    required this.universityId,
    required this.universityName,
  });

  @override
  State<UniversityFacultiesScreen> createState() => _UniversityFacultiesScreenState();
}

class _UniversityFacultiesScreenState extends State<UniversityFacultiesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _faculties = [];

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
    _fetchFaculties();
  }

  Future<void> _fetchFaculties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await supabase
          .from('faculties')
          .select('id, name')
          .eq('university_id', widget.universityId)
          .order('name');

      if (mounted) {
        setState(() {
          _faculties = List<Map<String, dynamic>>.from(data as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر تحميل الكليات. ${friendlyError(e)}';
          _isLoading = false;
        });
      }
    }
  }

  IconData _getFacultyIcon(String name) {
    if (name.contains('أسنان')) return Icons.biotech_outlined;
    if (name.contains('صيدلة')) return Icons.medication_liquid_outlined;
    if (name.contains('تمريض')) return Icons.favorite_outline;
    if (name.contains('معلوماتية')) return Icons.laptop_chromebook_rounded;
    return Icons.medical_services_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkScaffoldBg : lightScaffoldBg;
    final cardBg = isDark ? darkCardBg : lightEmeraldDark;
    final textColor = isDark ? Colors.white : lightEmeraldDark;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(color: goldBorder.withOpacity(0.35), width: 1),
        ),
        title: Text(
          widget.universityName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: goldAccent, size: 20),
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
          ? const Center(child: CircularProgressIndicator(color: goldAccent))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 44),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textColor, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchFaculties,
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
              : _faculties.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description_outlined, color: goldAccent.withOpacity(0.6), size: 54),
                          const SizedBox(height: 14),
                          Text(
                            'لا توجد كليات مدرجة في هذه الجامعة حالياً',
                            style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الكليات المتاحة',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: GridView.builder(
                              itemCount: _faculties.length,
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 150,
                                mainAxisSpacing: 18,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.78,
                              ),
                              itemBuilder: (context, index) {
                                final f = _faculties[index];
                                final icon = _getFacultyIcon(f['name'] ?? '');

                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FacultyCoursesScreen(
                                          facultyId: f['id'].toString(),
                                          facultyTitle: '${widget.universityName} - ${f['name']}',
                                          facultyIcon: icon,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Column(
                                    children: [
                                      // تصميم الورقة الأكاديمية
                                      Expanded(
                                        child: CustomPaint(
                                          painter: PaperSheetPainter(isDark: isDark),
                                          child: ClipPath(
                                            clipper: PaperSheetClipper(),
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: isDark
                                                      ? const [darkCardSurface, darkCardBg]
                                                      : const [lightEmeraldLight, lightEmeraldDark],
                                                  begin: Alignment.topRight,
                                                  end: Alignment.bottomLeft,
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const SizedBox(height: 12),
                                                  Container(
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withOpacity(0.2),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: goldAccent.withOpacity(0.4),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      icon,
                                                      color: goldAccent,
                                                      size: 28,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  // خطوط رمزية للورقة الأكاديمية
                                                  Container(
                                                    height: 3,
                                                    width: 44,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.25),
                                                      borderRadius: BorderRadius.circular(2),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    height: 3,
                                                    width: 28,
                                                    decoration: BoxDecoration(
                                                      color: goldAccent.withOpacity(0.45),
                                                      borderRadius: BorderRadius.circular(2),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        f['name'] ?? '',
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

/// قص الورقة الأكاديمية مع زاوية علوية مطوية
class PaperSheetClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const double radius = 10.0;
    const double foldSize = 22.0;

    final path = Path();
    path.moveTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.lineTo(size.width - foldSize, 0);
    path.lineTo(size.width, foldSize);
    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(size.width, size.height, size.width - radius, size.height);
    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// رسم إطار الورقة الذهبي ومثلث طيّة الزاوية (Corner Fold)
class PaperSheetPainter extends CustomPainter {
  final bool isDark;
  PaperSheetPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const double radius = 10.0;
    const double foldSize = 22.0;

    final borderPaint = Paint()
      ..color = const Color(0xFFC5A059)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final path = Path();
    path.moveTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.lineTo(size.width - foldSize, 0);
    path.lineTo(size.width, foldSize);
    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(size.width, size.height, size.width - radius, size.height);
    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    path.close();

    canvas.drawPath(path, borderPaint);

    // رسم طيّة الورقة بالزاوية العلوية
    final foldPaint = Paint()
      ..color = isDark ? const Color(0xFF24344E) : const Color(0xFF1D5A52)
      ..style = PaintingStyle.fill;

    final foldPath = Path();
    foldPath.moveTo(size.width - foldSize, 0);
    foldPath.lineTo(size.width - foldSize, foldSize);
    foldPath.lineTo(size.width, foldSize);
    foldPath.close();

    canvas.drawPath(foldPath, foldPaint);
    canvas.drawPath(foldPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant PaperSheetPainter oldPainter) => oldPainter.isDark != isDark;
}