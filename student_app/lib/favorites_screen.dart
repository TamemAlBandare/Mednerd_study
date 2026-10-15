import 'package:flutter/material.dart';

import 'bookmarks_service.dart';
import 'main.dart';
import 'vault_security_service.dart';
import 'youtube_lecture_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final list = await BookmarksService.getFavorites();
    if (mounted) {
      setState(() {
        _favorites = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _openFavoriteLecture(
    Map<String, dynamic> lecture,
    String subjectTitle,
  ) async {
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LecturePlayerRouter(
          currentLecture: lecture,
          allLectures: _favorites,
          subjectTitle: subjectTitle,
        ),
      ),
    ).then((_) => _loadFavorites());
  }

  Future<void> _removeFromFavorites(Map<String, dynamic> lecture) async {
    await BookmarksService.toggleFavorite(
      lecture: lecture,
      subjectTitle: lecture['subject_title'] ?? '',
    );
    _loadFavorites();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          content: Text('تمت إزالة المحاضرة من المفضلة'),
        ),
      );
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
          'المفضلة',
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
          : _favorites.isEmpty
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
                        Icons.bookmark_border_rounded,
                        color: goldAccent,
                        size: 44,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'قائمة المفضلة فارغة',
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
              itemCount: _favorites.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final lecture = _favorites[index];
                final String subjectTitle =
                    lecture['subject_title'] ?? 'المقرر';

                return InkWell(
                  onTap: () => _openFavoriteLecture(lecture, subjectTitle),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: border.withOpacity(0.6),
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
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cardSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: border.withOpacity(0.6)),
                          ),
                          child: const Icon(
                            Icons.play_circle_fill_rounded,
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
                                lecture['title'] ?? 'محاضرة',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subjectTitle,
                                style: TextStyle(
                                  color: goldAccent.withOpacity(0.9),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.bookmark_remove_rounded,
                            color: Color(0xFFEF4444),
                            size: 22,
                          ),
                          tooltip: 'إزالة من المفضلة',
                          onPressed: () => _removeFromFavorites(lecture),
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
