import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'hierarchy_label.dart';
import 'backend_errors.dart';

class QuizScreen extends StatefulWidget {
  final String title;
  final String? subjectId;
  final String? lectureId;
  final String? initialSubjectId;
  final String? initialLectureId;

  const QuizScreen({
    super.key,
    this.title = 'بنك الأسئلة والاختبارات',
    this.subjectId,
    this.lectureId,
    this.initialSubjectId,
    this.initialLectureId,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // 0: المقررات | 1: المحاضرات | 2: الأسئلة
  int _currentStep = 0;

  List<Map<String, dynamic>> _enrolledSubjects = [];
  Map<String, dynamic>? _selectedSubject;

  List<Map<String, dynamic>> _lectures = [];
  Map<String, dynamic>? _selectedLecture;

  List<Map<String, dynamic>> _questions = [];
  int _questionIndex = 0;
  final Map<int, int> _selectedAnswers = {};
  bool _isSubmitted = false;
  String? _quizLectureId;

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
    final effectiveLectureId = widget.lectureId ?? widget.initialLectureId;
    final effectiveSubjectId = widget.subjectId ?? widget.initialSubjectId;

    if (effectiveLectureId != null) {
      _loadQuestionsForLecture(effectiveLectureId, widget.title);
    } else if (effectiveSubjectId != null) {
      _selectedSubject = {'id': effectiveSubjectId, 'name': widget.title};
      _loadLecturesForSubject(effectiveSubjectId);
    } else {
      _loadEnrolledSubjects();
    }
  }

  Future<void> _loadEnrolledSubjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentStep = 0;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

      final subs = await Supabase.instance.client
          .from('student_subscriptions')
          .select(
              'subject_id, professor_id, subjects(id, name, code_prefix, universities(name), faculties(name)), professors(id, name)')
          .eq('user_id', user.id)
          .eq('status', 'active');

      final List<Map<String, dynamic>> subjectsList = [];
      for (var s in (subs as List)) {
        if (s['subjects'] != null) {
          final sub = Map<String, dynamic>.from(s['subjects'] as Map);
          sub['professor_id'] = s['professor_id'];
          sub['professor_name'] = (s['professors'] as Map?)?['name'];
          sub['path'] = hierarchyPath(sub);
          subjectsList.add(sub);
        }
      }

      if (mounted) {
        setState(() {
          _enrolledSubjects = subjectsList;
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

  Future<void> _loadLecturesForSubject(String subjectId,
      {String? professorId}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentStep = 1;
    });

    try {
      var lecturesQuery = Supabase.instance.client
          .from('lectures')
          .select('id, title, order_index, duration_minutes')
          .eq('subject_id', subjectId);
      if (professorId != null && professorId.isNotEmpty) {
        lecturesQuery = lecturesQuery.eq('professor_id', professorId);
      }
      final data = await lecturesQuery.order('order_index', ascending: true);

      if (mounted) {
        setState(() {
          _lectures = List<Map<String, dynamic>>.from(
            (data as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر تحميل المحاضرات. ${friendlyError(e)}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadQuestionsForLecture(
      String lectureId, String lectureTitle) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentStep = 2;
      _questionIndex = 0;
      _selectedAnswers.clear();
      _isSubmitted = false;
      _quizLectureId = lectureId;
    });

    try {
      final data = await Supabase.instance.client
          .rpc('get_quiz', params: {'p_lecture_id': lectureId});

      final List<Map<String, dynamic>> loaded = [];

      for (var rawItem in (data as List)) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        List<String> parsedOptions = [];

        if (item['options'] != null && item['options'] is List) {
          parsedOptions = List<String>.from(
              (item['options'] as List).map((e) => e.toString()));
        } else {
          for (var optKey in ['option_a', 'option_b', 'option_c', 'option_d']) {
            if (item[optKey] != null &&
                item[optKey].toString().trim().isNotEmpty) {
              parsedOptions.add(item[optKey].toString());
            }
          }
        }

        loaded.add({
          'id': item['id'],
          'question': item['question']?.toString() ?? 'سؤال بدون نص',
          'options': parsedOptions,
          'correct_index': -1,
          'explanation': item['explanation']?.toString() ?? '',
        });
      }

      if (mounted) {
        setState(() {
          _questions = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر تحميل بنك الأسئلة. ${friendlyError(e)}';
          _isLoading = false;
        });
      }
    }
  }

  void _handleBackNavigation() {
    final effectiveLectureId = widget.lectureId ?? widget.initialLectureId;
    final effectiveSubjectId = widget.subjectId ?? widget.initialSubjectId;

    if (_currentStep == 2) {
      if (effectiveLectureId != null) {
        Navigator.pop(context);
      } else {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      if (effectiveSubjectId != null) {
        Navigator.pop(context);
      } else {
        setState(() => _currentStep = 0);
      }
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submitQuiz() async {
    final lectureId = _quizLectureId;
    if (lectureId == null) return;
    setState(() => _isLoading = true);
    try {
      final answers = <String, int>{};
      for (int i = 0; i < _questions.length; i++) {
        final a = _selectedAnswers[i];
        if (a != null) answers[_questions[i]['id'].toString()] = a;
      }
      final res = Map<String, dynamic>.from(
        await Supabase.instance.client.rpc('submit_quiz', params: {
          'p_lecture_id': lectureId,
          'p_answers': answers,
        }) as Map,
      );
      final byId = <String, int>{
        for (final r in (res['results'] as List))
          r['id'].toString(): int.tryParse(r['correct_index'].toString()) ?? -1,
      };
      for (final q in _questions) {
        q['correct_index'] = byId[q['id'].toString()] ?? -1;
      }
      if (mounted) {
        setState(() {
          _isSubmitted = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('تعذر تسليم الاختبار، تحقق من الاتصال وحاول مرة أخرى')),
        );
      }
    }
  }

  int _calculateScore() {
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i]['correct_index']) {
        score++;
      }
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkScaffoldBg : lightScaffoldBg;
    final cardBg = isDark ? darkCardBg : lightEmeraldDark;
    final cardSurface = isDark ? darkCardSurface : lightEmeraldLight;
    final textColor = isDark ? Colors.white : lightEmeraldDark;

    final effectiveLectureId = widget.lectureId ?? widget.initialLectureId;
    final effectiveSubjectId = widget.subjectId ?? widget.initialSubjectId;

    String currentTitle = 'بنك الأسئلة';
    if (_currentStep == 0) {
      currentTitle = 'اختر المقرر الدراسي';
    } else if (_currentStep == 1) {
      currentTitle = _selectedSubject?['name'] ?? 'محاضرات المقرر';
    } else if (_currentStep == 2) {
      currentTitle = _selectedLecture?['title'] ?? widget.title;
    }

    return PopScope(
      canPop: _currentStep == 0 &&
          effectiveSubjectId == null &&
          effectiveLectureId == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: cardBg,
          elevation: 0,
          shape: Border(
            bottom: BorderSide(color: goldBorder.withValues(alpha: 0.35), width: 1),
          ),
          title: Text(
            currentTitle,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: goldAccent, size: 20),
            onPressed: _handleBackNavigation,
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
                          const Icon(Icons.error_outline_rounded,
                              color: Color(0xFFEF4444), size: 44),
                          const SizedBox(height: 12),
                          Text(_errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textColor, fontSize: 13)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              if (_currentStep == 0) _loadEnrolledSubjects();
                              if (_currentStep == 1 &&
                                  _selectedSubject != null) {
                                _loadLecturesForSubject(
                                    _selectedSubject!['id'].toString(),
                                    professorId: _selectedSubject![
                                            'professor_id']
                                        ?.toString());
                              }
                              if (_currentStep == 2 && _quizLectureId != null) {
                                _loadQuestionsForLecture(
                                  _quizLectureId!,
                                  _selectedLecture?['title']?.toString() ??
                                      widget.title,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: goldAccent,
                                foregroundColor: Colors.black),
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildCurrentView(isDark, cardBg, cardSurface, textColor),
      ),
    );
  }

  Widget _buildCurrentView(
      bool isDark, Color cardBg, Color cardSurface, Color textColor) {
    switch (_currentStep) {
      case 0:
        return _buildSubjectsGrid(isDark, cardBg, cardSurface, textColor);
      case 1:
        return _buildLecturesGrid(isDark, cardBg, cardSurface, textColor);
      case 2:
        return _isSubmitted
            ? _buildResultView(isDark, cardBg, cardSurface, textColor)
            : _buildQuestionsView(isDark, cardBg, cardSurface, textColor);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSubjectsGrid(
      bool isDark, Color cardBg, Color cardSurface, Color textColor) {
    if (_enrolledSubjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_outlined,
                  color: goldAccent, size: 48),
              const SizedBox(height: 14),
              Text(
                'لا توجد مقررات مفعلة حالياً',
                style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'قم بتفعيل اشتراك مقرر أولاً لعرض بنك الأسئلة الخاص به.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: _enrolledSubjects.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final sub = _enrolledSubjects[index];
        return InkWell(
          onTap: () {
            _selectedSubject = sub;
            _loadLecturesForSubject(sub['id'].toString(),
                professorId: sub['professor_id']?.toString());
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: goldBorder.withValues(alpha: 0.5), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: goldBorder.withValues(alpha: 0.6)),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: goldAccent, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  sub['name'] ?? 'المقرر',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((sub['professor_name'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'د. ${sub['professor_name']}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: goldAccent.withValues(alpha: 0.9), fontSize: 11.5),
                  ),
                ],
                if ((sub['path'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub['path'].toString(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLecturesGrid(
      bool isDark, Color cardBg, Color cardSurface, Color textColor) {
    if (_lectures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.quiz_outlined, color: goldAccent, size: 48),
              const SizedBox(height: 14),
              Text(
                'لا توجد محاضرات في هذا المقرر بعد',
                style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: _lectures.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final lec = _lectures[index];
        return InkWell(
          onTap: () {
            _selectedLecture = lec;
            _loadQuestionsForLecture(
                lec['id'].toString(), lec['title'] ?? 'المحاضرة ${index + 1}');
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: goldBorder.withValues(alpha: 0.4), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: goldBorder.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.quiz_outlined,
                      color: goldAccent, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  lec['title'] ?? 'المحاضرة ${index + 1}',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestionsView(
      bool isDark, Color cardBg, Color cardSurface, Color textColor) {
    if (_questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.playlist_remove_rounded,
                  color: goldAccent, size: 48),
              const SizedBox(height: 14),
              Text(
                'لم يتم رفع أسئلة لهذه المحاضرة بعد',
                style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'سيتم تحديث بنك الأسئلة قريباً من قبل إدارة المادة.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: textColor.withValues(alpha: 0.7), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final currentQ = _questions[_questionIndex];
    final List<String> options = List<String>.from(currentQ['options'] ?? []);
    final selectedOption = _selectedAnswers[_questionIndex];

    return SafeArea(
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (_questionIndex + 1) / _questions.length,
            backgroundColor: isDark ? darkCardSurface : Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(goldAccent),
            minHeight: 4,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'السؤال ${_questionIndex + 1} من ${_questions.length}',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  'المجاب: ${_selectedAnswers.length}/${_questions.length}',
                  style: const TextStyle(
                      color: goldAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: goldBorder.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      currentQ['question']?.toString() ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(options.length, (optIndex) {
                    final isChoiceSelected = selectedOption == optIndex;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedAnswers[_questionIndex] = optIndex;
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isChoiceSelected
                                ? goldAccent.withValues(alpha: 0.18)
                                : cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isChoiceSelected
                                  ? goldAccent
                                  : goldBorder.withValues(alpha: 0.35),
                              width: isChoiceSelected ? 1.6 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isChoiceSelected
                                      ? goldAccent
                                      : Colors.transparent,
                                  border: Border.all(
                                      color: isChoiceSelected
                                          ? goldAccent
                                          : Colors.white38),
                                ),
                                child: Center(
                                  child: Text(
                                    String.fromCharCode(65 + optIndex),
                                    style: TextStyle(
                                      color: isChoiceSelected
                                          ? Colors.black
                                          : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  options[optIndex],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: isChoiceSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(
                  top: BorderSide(color: goldBorder.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                if (_questionIndex > 0)
                  OutlinedButton(
                    onPressed: () => setState(() => _questionIndex--),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                          color: goldBorder.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    child: const Text('السابق'),
                  ),
                const Spacer(),
                if (_questionIndex < _questions.length - 1)
                  ElevatedButton(
                    onPressed: () => setState(() => _questionIndex++),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: goldAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('التالي',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                else
                  ElevatedButton(
                    onPressed: _submitQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('تسليم الإجابات',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(
      bool isDark, Color cardBg, Color cardSurface, Color textColor) {
    final score = _calculateScore();
    final total = _questions.length;
    final percentage = total > 0 ? ((score / total) * 100).toInt() : 0;
    final passed = percentage >= 60;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: goldBorder, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: passed
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : const Color(0xFFEF4444).withValues(alpha: 0.2),
                    border: Border.all(
                        color: passed
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        color: passed
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  passed
                      ? 'أحسنت! إتقان ممتاز للمحاضرة'
                      : 'راجع الأسئلة لتعزيز فهمك',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'أجبت بشكل صحيح على $score من أصل $total أسئلة',
                  style: const TextStyle(
                      color: goldAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'مراجعة الإجابات والشرح العلمي',
                style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final q = _questions[index];
              final userAns = _selectedAnswers[index];
              final correctAns = q['correct_index'] is int
                  ? q['correct_index'] as int
                  : int.tryParse('${q['correct_index']}') ?? -1;
              final isCorrect = userAns == correctAns;
              final List<String> options =
                  List<String>.from(q['options'] ?? []);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCorrect
                        ? const Color(0xFF10B981).withValues(alpha: 0.6)
                        : const Color(0xFFEF4444).withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isCorrect
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: isCorrect
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'س ${index + 1}: ${q['question']}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (userAns != null && userAns < options.length)
                      Text(
                        'إجابتك: ${options[userAns]}',
                        style: TextStyle(
                          color: isCorrect
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (!isCorrect &&
                        correctAns >= 0 &&
                        correctAns < options.length)
                      Text(
                        'الإجابة الصحيحة: ${options[correctAns]}',
                        style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    if (q['explanation'] != null &&
                        q['explanation'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cardSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'التوضيح: ${q['explanation']}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11.5,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              final effectiveLectureId =
                  widget.lectureId ?? widget.initialLectureId;
              if (effectiveLectureId != null) {
                Navigator.pop(context);
              } else {
                setState(() {
                  _isSubmitted = false;
                  _currentStep = 1;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: goldAccent,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.replay_rounded, size: 18),
            label: const Text('العودة لمحاضرات المقرر',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}