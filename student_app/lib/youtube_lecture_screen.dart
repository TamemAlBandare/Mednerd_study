import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'bookmarks_service.dart';
import 'pdf_viewer_screen.dart';
import 'quiz_screen.dart';
import 'security_service.dart';
import 'vault_security_service.dart';
import 'watch_progress_service.dart';
import 'video_player_screen.dart';
import 'theme/app_theme.dart';

String? youtubeIdFromUrl(String? url) {
  if (url == null) return null;
  final u = url.trim();
  if (u.isEmpty) return null;
  final m = RegExp(
    r'(?:youtu\.be/|youtube(?:-nocookie)?\.com/(?:watch\?(?:.*&)?v=|embed/|shorts/|live/|v/))([A-Za-z0-9_-]{11})',
  ).firstMatch(u);
  return m?.group(1);
}

class LecturePlayerRouter extends StatefulWidget {
  final Map<String, dynamic> currentLecture;
  final List<Map<String, dynamic>> allLectures;
  final String subjectTitle;
  final String? studentIdentifier;
  final int? startAtSeconds;

  const LecturePlayerRouter({
    super.key,
    required this.currentLecture,
    required this.allLectures,
    required this.subjectTitle,
    this.studentIdentifier,
    this.startAtSeconds,
  });

  @override
  State<LecturePlayerRouter> createState() => _LecturePlayerRouterState();
}

class _LecturePlayerRouterState extends State<LecturePlayerRouter> {
  bool _checkingAccess = true;
  String? _accessError;

  @override
  void initState() {
    super.initState();
    _verifyAccess();
  }

  Future<void> _verifyAccess() async {
    setState(() {
      _checkingAccess = true;
      _accessError = null;
    });

    final subjectId = widget.currentLecture['subject_id']?.toString() ?? '';
    final professorId = widget.currentLecture['professor_id']?.toString();

    if (subjectId.isEmpty) {
      if (mounted) {
        setState(() => _checkingAccess = false);
      }
      return;
    }

    final check = await VaultSecurityService.verifyOnlineAccess(
      subjectId: subjectId,
      professorId: professorId,
    );

    if (!mounted) return;
    if (check['ok'] == true) {
      setState(() => _checkingAccess = false);
    } else {
      setState(() {
        _checkingAccess = false;
        _accessError =
            check['message']?.toString() ?? 'تعذر التحقق من صلاحية الاشتراك.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? AppColors.darkScaffoldBg
        : AppColors.lightScaffoldBg;
    final cardBg = isDark ? AppColors.darkCardBg : AppColors.lightEmeraldDark;

    if (_checkingAccess) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.goldAccent),
        ),
      );
    }

    if (_accessError != null) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: cardBg,
          foregroundColor: Colors.white,
          title: Text(
            widget.subjectTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.goldBorder.withOpacity(0.6),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.gpp_bad_rounded,
                    color: AppColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _accessError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: AppColors.goldBorder.withOpacity(0.5),
                          ),
                        ),
                        child: const Text('رجوع'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _verifyAccess,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.goldAccent,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text(
                          'إعادة المحاولة',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final isYoutube =
        youtubeIdFromUrl(widget.currentLecture['video_url']?.toString()) !=
        null;
    if (isYoutube) {
      return YoutubeLectureScreen(
        currentLecture: widget.currentLecture,
        allLectures: widget.allLectures,
        subjectTitle: widget.subjectTitle,
        studentIdentifier: widget.studentIdentifier,
        startAtSeconds: widget.startAtSeconds,
      );
    }
    return VideoPlayerScreen(
      currentLecture: widget.currentLecture,
      allLectures: widget.allLectures,
      subjectTitle: widget.subjectTitle,
      studentIdentifier: widget.studentIdentifier,
      startAtSeconds: widget.startAtSeconds,
    );
  }
}

class YoutubeLectureScreen extends StatefulWidget {
  final Map<String, dynamic> currentLecture;
  final List<Map<String, dynamic>> allLectures;
  final String subjectTitle;
  final String? studentIdentifier;
  final int? startAtSeconds;

  const YoutubeLectureScreen({
    super.key,
    required this.currentLecture,
    required this.allLectures,
    required this.subjectTitle,
    this.studentIdentifier,
    this.startAtSeconds,
  });

  @override
  State<YoutubeLectureScreen> createState() => _YoutubeLectureScreenState();
}

class _YoutubeLectureScreenState extends State<YoutubeLectureScreen> {
  static const double _videoFraction = 0.28;
  static const double _logoBlockWidth = 72;
  static const double _logoBlockHeight = 44;

  late final YoutubePlayerController _yt;
  late Map<String, dynamic> _active;
  String _watermark = 'MEDNERD';
  String _description = '';
  Alignment _wmAlign = Alignment.center;
  Timer? _wmTimer;
  Timer? _progressTimer;
  bool _savingProgress = false;
  int _lastKnownPos = 0;
  int _lastKnownTotal = 0;
  bool _isBookmarked = false;
  final Random _rand = Random();
  bool _full = false;

  int _fallbackDurationSeconds() {
    final minsRaw = _active['duration_minutes'];
    final mins = minsRaw is num
        ? minsRaw.toInt()
        : (int.tryParse('$minsRaw') ?? 0);
    return mins > 0 ? mins * 60 : 0;
  }

  @override
  void initState() {
    super.initState();
    SecurityService.enableSecureScreen();
    _active = widget.currentLecture;
    _lastKnownPos = widget.startAtSeconds ?? 0;
    _lastKnownTotal = _fallbackDurationSeconds();
    _resolveWatermark();
    _checkBookmarkStatus();
    _yt = YoutubePlayerController.fromVideoId(
      videoId: youtubeIdFromUrl(_active['video_url']?.toString()) ?? '',
      autoPlay: true,
      startSeconds: widget.startAtSeconds?.toDouble(),
      params: const YoutubePlayerParams(
        showFullscreenButton: false,
        strictRelatedVideos: true,
        enableKeyboard: false,
        origin: 'https://www.youtube-nocookie.com',
      ),
    );
    _progressTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _saveProgress(),
    );
    _wmTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted) return;
      setState(() {
        _wmAlign = Alignment(
          (_rand.nextDouble() * 1.6) - 0.8,
          (_rand.nextDouble() * 1.4) - 0.7,
        );
      });
    });
    _loadDescription();
  }

  Future<void> _checkBookmarkStatus() async {
    final lectureId = _active['id']?.toString() ?? '';
    if (lectureId.isNotEmpty) {
      final isFav = await BookmarksService.isFavorite(lectureId);
      if (mounted) {
        setState(() => _isBookmarked = isFav);
      }
    }
  }

  void _resolveWatermark() {
    final id = widget.studentIdentifier?.trim();
    if (id != null && id.isNotEmpty) {
      _watermark = id;
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final name = user.userMetadata?['full_name']?.toString();
    if (name != null && name.isNotEmpty) {
      _watermark = name;
    } else if (user.email != null) {
      _watermark = user.email!.split('@').first;
    } else {
      _watermark = 'ID: ${user.id.substring(0, 8)}';
    }
  }

  Future<void> _loadDescription() async {
    final id = _active['id']?.toString();
    if (id == null) return;
    try {
      final row = await Supabase.instance.client
          .from('lectures')
          .select('description')
          .eq('id', id)
          .maybeSingle();
      if (!mounted || _active['id']?.toString() != id) return;
      setState(
        () => _description = (row?['description'] ?? '').toString().trim(),
      );
    } catch (_) {}
  }

  void _restoreUi() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _toggleFull() {
    setState(() => _full = !_full);
    if (_full) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      _restoreUi();
    }
  }

  Future<void> _saveProgress() async {
    if (_savingProgress) return;
    _savingProgress = true;
    try {
      final pos = (await _yt.currentTime).floor();
      var total = (await _yt.duration).floor();
      if (total <= 0) total = _fallbackDurationSeconds();
      if (pos > 0) _lastKnownPos = pos;
      if (total > 0) _lastKnownTotal = total;
      await _persistProgressValues(_lastKnownPos, _lastKnownTotal);
    } catch (_) {
      await _persistProgressValues(_lastKnownPos, _lastKnownTotal);
    } finally {
      _savingProgress = false;
    }
  }

  Future<void> _persistProgressValues(int pos, int total) async {
    final effectiveTotal = total > 0 ? total : _fallbackDurationSeconds();
    if (effectiveTotal > 0 && pos >= effectiveTotal - 10) {
      await WatchProgressService.clearProgress();
    } else if (pos >= 3) {
      await WatchProgressService.saveProgress(
        lecture: _active,
        allLectures: widget.allLectures,
        subjectTitle: widget.subjectTitle,
        positionSeconds: pos,
        totalDurationSeconds: effectiveTotal,
      );
    }
  }

  Future<void> _open(Map<String, dynamic> lecture) async {
    final subjectId = lecture['subject_id']?.toString() ?? '';
    if (subjectId.isNotEmpty) {
      final check = await VaultSecurityService.verifyOnlineAccess(
        subjectId: subjectId,
        professorId: lecture['professor_id']?.toString(),
      );
      if (check['ok'] != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            content: Text(
              check['message']?.toString() ?? 'انتهت صلاحية الاشتراك.',
            ),
          ),
        );
        Navigator.pop(context);
        return;
      }
    }

    final id = youtubeIdFromUrl(lecture['video_url']?.toString());
    if (id != null) {
      await _saveProgress();
      if (!mounted) return;
      setState(() {
        _active = lecture;
        _description = '';
        _lastKnownPos = 0;
        _lastKnownTotal = _fallbackDurationSeconds();
      });
      _checkBookmarkStatus();
      _yt.loadVideoById(videoId: id);
      _loadDescription();
    } else {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LecturePlayerRouter(
            currentLecture: lecture,
            allLectures: widget.allLectures,
            subjectTitle: widget.subjectTitle,
            studentIdentifier: widget.studentIdentifier,
          ),
        ),
      );
    }
  }

  bool get _hasPdf =>
      (_active['pdf_url']?.toString().trim().isNotEmpty ?? false) ||
      (_active['telegram_pdf_id']?.toString().trim().isNotEmpty ?? false);

  void _openQuiz() {
    _yt.pauseVideo();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          title: _active['title']?.toString() ?? 'اختبار المحاضرة',
          lectureId: _active['id']?.toString(),
          subjectId: _active['subject_id']?.toString(),
        ),
      ),
    );
  }

  void _openPdf() {
    _yt.pauseVideo();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProtectedPdfViewerScreen(
          lectureId: _active['id']?.toString() ?? 'lec_temp',
          title: _active['title']?.toString() ?? 'ملخص المحاضرة',
          directPdfUrl: _active['pdf_url']?.toString(),
          telegramPdfId: _active['telegram_pdf_id']?.toString(),
          studentName: _watermark,
          subjectId: _active['subject_id']?.toString(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _wmTimer?.cancel();
    _progressTimer?.cancel();
    _persistProgressValues(_lastKnownPos, _lastKnownTotal);
    _yt.close();
    if (_full) _restoreUi();
    SecurityService.disableSecureScreen();
    super.dispose();
  }

  Widget _player() {
    return LayoutBuilder(
      builder: (context, c) {
        var w = c.maxWidth;
        final maxH = c.maxHeight.isFinite ? c.maxHeight : w * 9 / 16;
        var h = w * 9 / 16;
        if (h > maxH) {
          h = maxH;
          w = h * 16 / 9;
        }
        final topBlockH = min(52.0, h * 0.3);
        final logoBlockH = min(_logoBlockHeight, h * 0.3);
        final logoBlockW = min(_logoBlockWidth, w * 0.2);
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                YoutubePlayer(controller: _yt, aspectRatio: 16 / 9),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: topBlockH,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  width: logoBlockW,
                  height: logoBlockH,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: IconButton(
                    icon: Icon(
                      _full ? Icons.fullscreen_exit : Icons.fullscreen,
                      color: AppColors.goldAccent,
                    ),
                    onPressed: _toggleFull,
                  ),
                ),
                IgnorePointer(
                  child: AnimatedAlign(
                    duration: const Duration(seconds: 2),
                    alignment: _wmAlign,
                    child: Opacity(
                      opacity: 0.30,
                      child: Text(
                        _watermark,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoSection(bool isDark) {
    final cardBg = isDark ? AppColors.darkCardBg : AppColors.lightEmeraldDark;
    final duration = _active['duration_minutes'];
    final meta = <String>[
      widget.subjectTitle,
      if (duration != null && duration.toString() != '0') '$duration دقيقة',
    ].join('  •  ');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _active['title']?.toString() ?? 'محاضرة',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: _isBookmarked ? 'إزالة من المفضلة' : 'حفظ في المفضلة',
                icon: Icon(
                  _isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: AppColors.goldAccent,
                ),
                onPressed: () async {
                  final added = await BookmarksService.toggleFavorite(
                    lecture: _active,
                    subjectTitle: widget.subjectTitle,
                  );
                  if (mounted) {
                    setState(() => _isBookmarked = added);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: cardBg,
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          added
                              ? 'تمت إضافة المحاضرة للمفضلة'
                              : 'تمت إزالة المحاضرة من المفضلة',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          Text(
            meta,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
          if (_description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _description,
              style: const TextStyle(fontSize: 13.5, height: 1.5),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.goldAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: _openQuiz,
                icon: const Icon(Icons.quiz_outlined, size: 18),
                label: const Text(
                  'اختبار المحاضرة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (_hasPdf)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.goldAccent,
                    side: const BorderSide(color: AppColors.goldBorder),
                  ),
                  onPressed: _openPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text(
                    'ملخص PDF',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lecturesSection() {
    final n = widget.allLectures.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'محاضرات المقرر ($n)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: n,
            itemBuilder: (context, i) {
              final l = widget.allLectures[i];
              final isActive = l['id'] == _active['id'];
              return ListTile(
                selected: isActive,
                selectedColor: AppColors.goldAccent,
                leading: Icon(
                  isActive ? Icons.play_circle_fill : Icons.play_circle_outline,
                  color: isActive ? AppColors.goldAccent : null,
                ),
                title: Text(l['title']?.toString() ?? 'محاضرة ${i + 1}'),
                subtitle: l['duration_minutes'] != null
                    ? Text('${l['duration_minutes']} دقيقة')
                    : null,
                onTap: isActive ? null : () => _open(l),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDark ? AppColors.darkCardBg : AppColors.lightEmeraldDark;

    return PopScope(
      canPop: !_full,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _persistProgressValues(_lastKnownPos, _lastKnownTotal);
          return;
        }
        if (_full) _toggleFull();
      },
      child: Scaffold(
        backgroundColor: _full ? Colors.black : null,
        appBar: _full
            ? null
            : AppBar(
                backgroundColor: appBarBg,
                foregroundColor: Colors.white,
                title: Text(
                  widget.subjectTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final videoH = _full ? c.maxHeight : c.maxHeight * _videoFraction;
              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: videoH,
                    child: ColoredBox(color: Colors.black, child: _player()),
                  ),
                  if (!_full) Expanded(flex: 1, child: _infoSection(isDark)),
                  if (!_full) const Divider(height: 1),
                  if (!_full) Expanded(flex: 2, child: _lecturesSection()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
