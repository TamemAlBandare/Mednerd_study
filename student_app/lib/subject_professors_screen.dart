import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';
import 'device_service.dart';
import 'backend_errors.dart';
import 'course_details_screen.dart';

class SubjectProfessorsScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const SubjectProfessorsScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<SubjectProfessorsScreen> createState() =>
      _SubjectProfessorsScreenState();
}

class _SubjectProfessorsScreenState extends State<SubjectProfessorsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _professors = [];
  final Set<String> _enrolledProfIds = {};

  static const Color darkScaffoldBg = Color(0xFF0B0F17);
  static const Color darkCardBg = Color(0xFF151E2E);
  static const Color darkCardSurface = Color(0xFF1E2B40);
  static const Color darkInputBg = Color(0xFF101724);

  static const Color lightScaffoldBg = Color(0xFFF3EFE6);
  static const Color lightEmeraldDark = Color(0xFF0E332E);
  static const Color lightEmeraldLight = Color(0xFF15443E);

  static const Color goldAccent = Color(0xFFD8B467);
  static const Color goldBorder = Color(0xFFC5A059);

  @override
  void initState() {
    super.initState();
    _fetchProfessorsAndSubscriptions();
  }

  Future<void> _fetchProfessorsAndSubscriptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;

      _enrolledProfIds.clear();
      if (user != null) {
        final subs = await supabase
            .from('student_subscriptions')
            .select('professor_id')
            .eq('user_id', user.id)
            .eq('subject_id', widget.subjectId)
            .eq('status', 'active');

        for (var item in (subs as List)) {
          if (item['professor_id'] != null) {
            _enrolledProfIds.add(item['professor_id'].toString());
          }
        }
      }

      final data = await supabase
          .from('subject_professors')
          .select('professor_id, professors(id, name, avatar_url, bio)')
          .eq('subject_id', widget.subjectId);

      final List<Map<String, dynamic>> profList = [];
      for (var item in (data as List)) {
        if (item['professors'] != null) {
          profList.add(Map<String, dynamic>.from(item['professors'] as Map));
        }
      }

      if (mounted) {
        setState(() {
          _professors = profList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر تحميل بيانات الأساتذة. ${friendlyError(e)}';
          _isLoading = false;
        });
      }
    }
  }

  void _showActivationDialog(bool isDark) {
    final TextEditingController codeController = TextEditingController();
    String? dialogError;
    bool isVerifying = false;

    final dialogBg = isDark ? darkCardBg : lightEmeraldDark;
    const dialogBorder = goldBorder;

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
                    width: 400,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: dialogBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: dialogError != null
                            ? const Color(0xFFEF4444)
                            : dialogBorder.withOpacity(0.9),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: dialogBorder.withOpacity(0.2),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? darkCardSurface
                                  : lightEmeraldLight,
                              border: Border.all(
                                color: dialogBorder,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.vpn_key_rounded,
                              color: goldAccent,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'تفعيل كود المقرر',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? darkInputBg
                                  : const Color(0xFF08221E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: dialogError != null
                                    ? const Color(0xFFEF4444)
                                    : dialogBorder,
                              ),
                            ),
                            child: TextField(
                              controller: codeController,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                              decoration: InputDecoration(
                                hintText: 'XXX-XXX-XX-XXXX',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          if (dialogError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              dialogError!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isVerifying
                                      ? null
                                      : () => Navigator.pop(dialogContext),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side: BorderSide(
                                      color: dialogBorder.withOpacity(0.5),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('إلغاء'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: isVerifying
                                      ? null
                                      : () async {
                                          final code = codeController.text
                                              .trim();
                                          if (code.isEmpty) {
                                            setDialogState(
                                              () => dialogError =
                                                  'يرجى إدخال الكود',
                                            );
                                            return;
                                          }
                                          setDialogState(() {
                                            isVerifying = true;
                                            dialogError = null;
                                          });

                                          try {
                                            final user =
                                                supabase.auth.currentUser;
                                            if (user == null) {
                                              setDialogState(() {
                                                isVerifying = false;
                                                dialogError =
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
                                                      'p_code': code,
                                                      'p_fingerprint':
                                                          fingerprint,
                                                    },
                                                  ) as Map,
                                                );
                                            if (result['ok'] != true) {
                                              setDialogState(() {
                                                isVerifying = false;
                                                dialogError =
                                                    activationErrorMessage(
                                                      result['error']
                                                          ?.toString(),
                                                    );
                                              });
                                              return;
                                            }

                                            if (mounted) {
                                              Navigator.pop(dialogContext);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  backgroundColor: Color(
                                                    0xFF10B981,
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  content: Text(
                                                    'تم تفعيل الاشتراك بنجاح',
                                                  ),
                                                ),
                                              );
                                              _fetchProfessorsAndSubscriptions();
                                            }
                                          } on PostgrestException catch (e) {
                                            setDialogState(() {
                                              isVerifying = false;
                                              dialogError =
                                                  activationErrorMessage(
                                                    e.code == '23505'
                                                        ? 'already_subscribed'
                                                        : e.message,
                                                  );
                                            });
                                          } catch (e) {
                                            setDialogState(() {
                                              isVerifying = false;
                                              dialogError = 'تعذر التفعيل، تحقق من الاتصال وحاول مرة أخرى';
                                            });
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: goldAccent,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: isVerifying
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : const Text(
                                          'تفعيل',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
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

  void _showNotEnrolledSheet(String profName, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? darkCardBg : lightEmeraldDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: goldAccent.withOpacity(0.15),
                border: Border.all(color: goldBorder, width: 1.2),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: goldAccent,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'المقرر غير مفعل (د. $profName)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showActivationDialog(isDark);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.vpn_key_rounded, size: 18),
                label: const Text(
                  'تفعيل الكود',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkScaffoldBg : lightScaffoldBg;
    final cardBg = isDark ? darkCardBg : lightEmeraldDark;
    final textColor = isDark ? Colors.white : lightEmeraldDark;
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF5A6E69);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(color: goldBorder.withOpacity(0.35), width: 1),
        ),
        title: Text(
          widget.subjectName,
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
            tooltip: 'تفعيل كود',
            icon: const Icon(
              Icons.vpn_key_rounded,
              color: goldAccent,
              size: 20,
            ),
            onPressed: () => _showActivationDialog(isDark),
          ),
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
                      onPressed: _fetchProfessorsAndSubscriptions,
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
          : _professors.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    color: goldAccent.withOpacity(0.6),
                    size: 54,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'لا يوجد أساتذة مدرجون حالياً',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Text(
                    'مدرّسو المقرر',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _professors.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 150,
                          mainAxisSpacing: 22,
                          crossAxisSpacing: 18,
                          childAspectRatio: 0.76,
                        ),
                    itemBuilder: (context, index) {
                      final prof = _professors[index];
                      final profId = prof['id'].toString();
                      final avatarUrl = prof['avatar_url']?.toString();
                      final profName = prof['name'] ?? 'دكتور المقرر';
                      final bool isEnrolled = _enrolledProfIds.contains(profId);

                      return InkWell(
                        onTap: () {
                          if (isEnrolled) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CourseDetailsScreen(
                                  subjectId: widget.subjectId,
                                  subjectTitle: widget.subjectName,
                                  professorId: prof['id']?.toString(),
                                  professorName: profName,
                                ),
                              ),
                            );
                          } else {
                            _showNotEnrolledSheet(profName, isDark);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 86,
                                  height: 86,
                                  padding: const EdgeInsets.all(3.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: isEnrolled
                                          ? const [
                                              Color(0xFF10B981),
                                              Color(0xFF059669),
                                            ]
                                          : [
                                              goldAccent,
                                              goldBorder.withOpacity(0.4),
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark
                                          ? darkCardSurface
                                          : lightEmeraldDark,
                                    ),
                                    child: ClipOval(
                                      child:
                                          (avatarUrl != null &&
                                              avatarUrl.trim().isNotEmpty)
                                          ? Image.network(
                                              avatarUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                    Icons.person_rounded,
                                                    color: goldAccent,
                                                    size: 44,
                                                  ),
                                            )
                                          : const Icon(
                                              Icons.person_rounded,
                                              color: goldAccent,
                                              size: 44,
                                            ),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4.5),
                                  decoration: BoxDecoration(
                                    color: isEnrolled
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF1E2B40),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    isEnrolled
                                        ? Icons.check_rounded
                                        : Icons.lock_outline_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'د. $profName',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEnrolled ? 'مفعل' : 'مغلق',
                              style: TextStyle(
                                color: isEnrolled
                                    ? const Color(0xFF10B981)
                                    : subtitleColor,
                                fontSize: 10.5,
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
    );
  }
}
