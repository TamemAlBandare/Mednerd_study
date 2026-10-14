import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import 'bookmarks_service.dart';
import 'pdf_viewer_screen.dart';
import 'quiz_screen.dart';
import 'security_service.dart';
import 'watch_progress_service.dart';
import 'youtube_lecture_screen.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> currentLecture;
  final List<Map<String, dynamic>> allLectures;
  final String subjectTitle;
  final String? studentIdentifier;
  final int? startAtSeconds;

  const VideoPlayerScreen({
    super.key,
    required this.currentLecture,
    required this.allLectures,
    required this.subjectTitle,
    this.studentIdentifier,
    this.startAtSeconds,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _showControls = true;
  bool _isLoadingVideo = true;
  String? _videoError;
  Timer? _hideTimer;
  double _currentSpeed = 1.0;
  double _savedSpeedBeforeLongPress = 1.0;
  bool _isLongPressing2x = false;

  bool _showForwardIndicator = false;
  bool _showRewindIndicator = false;
  Timer? _indicatorTimer;

  late Map<String, dynamic> _activeLecture;
  String _watermarkText = 'MEDNERD';
  bool _isBookmarked = false;

  Timer? _watermarkTimer;
  Alignment _watermarkAlignment = Alignment.topRight;
  final Random _random = Random();

  static const Color lightScaffoldBg = Color(0xFFF3EFE6);
  static const Color lightEmeraldDark = Color(0xFF0E332E);
  static const Color lightEmeraldLight = Color(0xFF15443E);
  static const Color lightGoldBorder = Color(0xFFC5A059);

  static const Color darkScaffoldBg = Color(0xFF0B0F17);
  static const Color darkCardBg = Color(0xFF151E2E);
  static const Color darkCardSurface = Color(0xFF1E2B40);
  static const Color darkGoldBorder = Color(0xFFC5A059);

  static const Color goldAccent = Color(0xFFD8B467);

  final List<double> _speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void initState() {
    super.initState();
    _enableSecureScreen();

    _activeLecture = widget.currentLecture;
    _resolveWatermarkText();
    _checkBookmarkStatus();
    _startWatermarkAnimation();
    _initializeVideo(seekToSeconds: widget.startAtSeconds);
  }

  Future<void> _checkBookmarkStatus() async {
    final lectureId = _activeLecture['id']?.toString() ?? '';
    if (lectureId.isNotEmpty) {
      final isFav = await BookmarksService.isFavorite(lectureId);
      if (mounted) {
        setState(() => _isBookmarked = isFav);
      }
    }
  }

  Future<void> _enableSecureScreen() async {
    await SecurityService.enableSecureScreen();
  }

  Future<void> _disableSecureScreen() async {
    await SecurityService.disableSecureScreen();
  }

  void _resolveWatermarkText() {
    if (widget.studentIdentifier != null &&
        widget.studentIdentifier!.trim().isNotEmpty) {
      _watermarkText = widget.studentIdentifier!.trim();
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (user.userMetadata != null &&
          user.userMetadata!['full_name'] != null) {
        _watermarkText = user.userMetadata!['full_name'].toString();
      } else if (user.email != null) {
        _watermarkText = user.email!.split('@').first;
      } else {
        _watermarkText = 'ID: ${user.id.substring(0, 8)}';
      }
    }
  }

  void _startWatermarkAnimation() {
    _watermarkTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (mounted) {
        setState(() {
          final double x = (_random.nextDouble() * 1.6) - 0.8;
          final double y = (_random.nextDouble() * 1.4) - 0.7;
          _watermarkAlignment = Alignment(x, y);
        });
      }
    });
  }

  Future<void> _initializeVideo({int? seekToSeconds}) async {
    setState(() {
      _isLoadingVideo = true;
      _videoError = null;
    });

    if (_controller != null) {
      await _controller!.pause();
      await _controller!.dispose();
      _controller = null;
    }

    final rawUrl = _activeLecture['video_url']?.toString().trim();
    if (rawUrl == null || rawUrl.isEmpty) {
      setState(() {
        _isLoadingVideo = false;
        _videoError = 'رابط الفيديو غير متوفر حالياً.';
      });
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(rawUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      _controller = controller;

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _isLoadingVideo = false;
        if (seekToSeconds != null && seekToSeconds > 0) {
          controller.seekTo(Duration(seconds: seekToSeconds));
        }

        controller.play();
        controller.setPlaybackSpeed(_currentSpeed);
        _startHideTimer();
      });

      controller.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
          _videoError = 'تعذر تشغيل الفيديو، تحقق من الاتصال بالإنترنت.';
        });
      }
    }
  }

  void _saveWatchProgress() {
    if (_controller != null && _controller!.value.isInitialized) {
      final pos = _controller!.value.position.inSeconds;
      final total = _controller!.value.duration.inSeconds;
      if (total > 0 && pos >= total - 10) {
        WatchProgressService.clearProgress();
      } else {
        WatchProgressService.saveProgress(
          lecture: _activeLecture,
          allLectures: widget.allLectures,
          subjectTitle: widget.subjectTitle,
          positionSeconds: pos,
          totalDurationSeconds: total,
        );
      }
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted &&
          (_controller?.value.isPlaying ?? false) &&
          !_isLongPressing2x) {
        setState(() => _showControls = false);
      }
    });
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        _controller!.play();
        _showControls = true;
        _startHideTimer();
      }
    });
  }

  void _seekForward10() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final target = _controller!.value.position + const Duration(seconds: 10);
    if (target < _controller!.value.duration) {
      _controller!.seekTo(target);
    } else {
      _controller!.seekTo(_controller!.value.duration);
    }
    _showFeedback(isForward: true);
  }

  void _seekRewind10() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final target = _controller!.value.position - const Duration(seconds: 10);
    _controller!.seekTo(target > Duration.zero ? target : Duration.zero);
    _showFeedback(isForward: false);
  }

  void _showFeedback({required bool isForward}) {
    _indicatorTimer?.cancel();
    setState(() {
      if (isForward) {
        _showForwardIndicator = true;
        _showRewindIndicator = false;
      } else {
        _showRewindIndicator = true;
        _showForwardIndicator = false;
      }
    });
    _indicatorTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _showForwardIndicator = false;
          _showRewindIndicator = false;
        });
      }
    });
    _startHideTimer();
  }

  void _onLongPressStart() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    _savedSpeedBeforeLongPress = _currentSpeed;
    _controller!.setPlaybackSpeed(2.0);
    setState(() {
      _isLongPressing2x = true;
      _showControls = false;
    });
  }

  void _onLongPressEnd() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    _controller!.setPlaybackSpeed(_savedSpeedBeforeLongPress);
    setState(() {
      _isLongPressing2x = false;
    });
    _startHideTimer();
  }

  void _switchLecture(Map<String, dynamic> lecture) {
    if (_activeLecture['id'] == lecture['id']) return;
    _saveWatchProgress();
    _hideTimer?.cancel();

    if (youtubeIdFromUrl(lecture['video_url']?.toString()) != null) {
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
      return;
    }

    setState(() {
      _activeLecture = lecture;
    });
    _checkBookmarkStatus();
    _initializeVideo();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _openFullScreen() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    _hideTimer?.cancel();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenVideoPage(
          controller: _controller!,
          currentSpeed: _currentSpeed,
          speeds: _speeds,
          watermarkText: _watermarkText,
          onSpeedChanged: (speed) {
            setState(() => _currentSpeed = speed);
          },
        ),
      ),
    );
    if (mounted) {
      setState(() {});
      _startHideTimer();
    }
  }

  void _showSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFFC5A059), width: 1.2),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'سرعة التشغيل',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ..._speeds.map((speed) {
                final isSelected = _currentSpeed == speed;
                return ListTile(
                  title: Text(
                    speed == 1.0 ? 'عادية (1.0x)' : '${speed}x',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? goldAccent : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: goldAccent,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _currentSpeed = speed;
                      _controller?.setPlaybackSpeed(speed);
                    });
                    Navigator.pop(ctx);
                    _startHideTimer();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _saveWatchProgress();
    _disableSecureScreen();
    _hideTimer?.cancel();
    _indicatorTimer?.cancel();
    _watermarkTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkScaffoldBg : lightScaffoldBg;
    final cardBg = isDark ? darkCardBg : lightEmeraldDark;
    final border = isDark ? darkGoldBorder : lightGoldBorder;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(color: border.withOpacity(0.35), width: 1),
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
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWideScreen = constraints.maxWidth >= 850;

            if (isWideScreen) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _buildVideoPlayerArea(border),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: _buildLectureInfoCard(isDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: border.withOpacity(0.2),
                  ),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: _buildLecturesSection(isDark),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildVideoPlayerArea(border),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLectureInfoCard(isDark),
                        const SizedBox(height: 22),
                        _buildLecturesSection(isDark),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoPlayerArea(Color border) {
    if (_isLoadingVideo) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: goldAccent),
        ),
      );
    }

    if (_videoError != null) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                _videoError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _initializeVideo(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller!;

    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.isInitialized
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(controller),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedAlign(
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
                alignment: _watermarkAlignment,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _watermarkText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.18),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlayPause,
              onLongPressStart: (_) => _onLongPressStart(),
              onLongPressEnd: (_) => _onLongPressEnd(),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: _seekRewind10,
                      onTap: _togglePlayPause,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: _seekForward10,
                      onTap: _togglePlayPause,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showForwardIndicator)
            Positioned(
              right: 28,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: goldAccent.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fast_forward_rounded,
                      color: goldAccent,
                      size: 22,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '+10s',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_showRewindIndicator)
            Positioned(
              left: 28,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: goldAccent.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '-10s',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.fast_rewind_rounded,
                      color: goldAccent,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          if (_isLongPressing2x)
            Positioned(
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: goldAccent, width: 1.2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '2x Speed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.bolt_rounded, color: goldAccent, size: 16),
                  ],
                ),
              ),
            ),
          if (_showControls && !_isLongPressing2x)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildYoutubeStyleBottomControls(),
            ),
        ],
      ),
    );
  }

  Widget _buildLectureInfoCard(bool isDark) {
    final cardBg = isDark ? darkCardBg : lightEmeraldDark;
    final surfaceBg = isDark ? darkCardSurface : lightEmeraldLight;
    final border = isDark ? darkGoldBorder : lightGoldBorder;
    final hasPdf =
        (_activeLecture['telegram_pdf_id'] != null &&
            _activeLecture['telegram_pdf_id'].toString().trim().isNotEmpty) ||
        (_activeLecture['pdf_url'] != null &&
            _activeLecture['pdf_url'].toString().trim().isNotEmpty);
    final description = (_activeLecture['description'] ?? '').toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: border.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border, width: 0.8),
                ),
                child: Text(
                  'المحاضرة ${_activeLecture['order_index'] ?? 1}',
                  style: const TextStyle(
                    color: goldAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: _isBookmarked ? 'إزالة من المفضلة' : 'حفظ في المفضلة',
                icon: Icon(
                  _isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _isBookmarked ? goldAccent : Colors.white70,
                  size: 24,
                ),
                onPressed: () async {
                  final added = await BookmarksService.toggleFavorite(
                    lecture: _activeLecture,
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
          const SizedBox(height: 10),
          Text(
            _activeLecture['title'] ?? 'عنوان المحاضرة',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: goldAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  _controller?.pause();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(
                        title:
                            _activeLecture['title']?.toString() ??
                            'اختبار المحاضرة',
                        lectureId: _activeLecture['id']?.toString(),
                        subjectId: _activeLecture['subject_id']?.toString(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.quiz_outlined, size: 18),
                label: const Text(
                  'اختبار المحاضرة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (hasPdf)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: goldAccent,
                    side: BorderSide(color: border),
                    backgroundColor: surfaceBg,
                  ),
                  onPressed: () {
                    _controller?.pause();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProtectedPdfViewerScreen(
                          lectureId:
                              _activeLecture['id']?.toString() ?? 'lec_temp',
                          title:
                              _activeLecture['title']?.toString() ??
                              'ملخص المحاضرة',
                          directPdfUrl: _activeLecture['pdf_url']?.toString(),
                          telegramPdfId: _activeLecture['telegram_pdf_id']
                              ?.toString(),
                          studentName: _watermarkText,
                          subjectId: _activeLecture['subject_id']?.toString(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text(
                    'الملخص',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLecturesSection(bool isDark) {
    final border = isDark ? darkGoldBorder : lightGoldBorder;
    final titleColor = isDark ? Colors.white : lightEmeraldDark;
    final cardBg = isDark ? darkCardBg : lightEmeraldDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'محاضرات المقرر (${widget.allLectures.length})',
              style: TextStyle(
                color: titleColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.allLectures.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final lecture = widget.allLectures[index];
            final isSelected = lecture['id'] == _activeLecture['id'];
            final hasDuration =
                lecture['duration_minutes'] != null &&
                lecture['duration_minutes'].toString() != '0';

            return InkWell(
              onTap: () => _switchLecture(lecture),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? darkCardSurface : lightEmeraldLight)
                      : cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? border : border.withValues(alpha: 0.3),
                    width: isSelected ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.play_circle_filled_rounded
                          : Icons.play_circle_outline_rounded,
                      color: isSelected ? goldAccent : Colors.white60,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lecture['title'] ?? 'محاضرة ${index + 1}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          if (hasDuration) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${lecture['duration_minutes']} دقيقة',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildYoutubeStyleBottomControls() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final durationSec = controller.value.duration.inSeconds.toDouble();
    final posSec = controller.value.position.inSeconds.toDouble();
    final maxSec = durationSec <= 0 ? 1.0 : durationSec;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbColor: goldAccent,
              activeTrackColor: goldAccent,
              inactiveTrackColor: Colors.white24,
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: posSec.clamp(0.0, maxSec),
              min: 0.0,
              max: maxSec,
              onChanged: (val) {
                _startHideTimer();
                controller.seekTo(Duration(seconds: val.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: _togglePlayPause,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.replay_10_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () {
                    _startHideTimer();
                    _seekRewind10();
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.forward_10_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () {
                    _startHideTimer();
                    _seekForward10();
                  },
                ),
                const SizedBox(width: 4),
                Text(
                  '${_formatDuration(controller.value.position)} / ${_formatDuration(controller.value.duration)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _showSpeedDialog,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: goldAccent.withValues(alpha: 0.7),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _currentSpeed == 1.0 ? '1.0x' : '${_currentSpeed}x',
                      style: const TextStyle(
                        color: goldAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'ملء الشاشة',
                  icon: const Icon(
                    Icons.fullscreen_rounded,
                    color: goldAccent,
                    size: 28,
                  ),
                  onPressed: _openFullScreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final double currentSpeed;
  final List<double> speeds;
  final String watermarkText;
  final ValueChanged<double> onSpeedChanged;

  const FullScreenVideoPage({
    super.key,
    required this.controller,
    required this.currentSpeed,
    required this.speeds,
    required this.watermarkText,
    required this.onSpeedChanged,
  });

  @override
  State<FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<FullScreenVideoPage> {
  bool _showControls = true;
  Timer? _hideTimer;
  late double _activeSpeed;
  double _savedSpeedBeforeLongPress = 1.0;
  bool _isLongPressing2x = false;

  bool _showForwardIndicator = false;
  bool _showRewindIndicator = false;
  Timer? _indicatorTimer;

  Timer? _watermarkTimer;
  Alignment _watermarkAlignment = Alignment.topRight;
  final Random _random = Random();

  static const Color goldAccent = Color(0xFFD8B467);

  @override
  void initState() {
    super.initState();
    SecurityService.enableSecureScreen();
    _activeSpeed = widget.currentSpeed;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);

    widget.controller.addListener(_videoListener);
    _startHideTimer();
    _startWatermarkAnimation();
  }

  void _startWatermarkAnimation() {
    _watermarkTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (mounted) {
        setState(() {
          final double x = (_random.nextDouble() * 1.6) - 0.8;
          final double y = (_random.nextDouble() * 1.4) - 0.7;
          _watermarkAlignment = Alignment(x, y);
        });
      }
    });
  }

  void _videoListener() {
    if (mounted) setState(() {});
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.value.isPlaying && !_isLongPressing2x) {
        setState(() => _showControls = false);
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        widget.controller.play();
        _showControls = true;
        _startHideTimer();
      }
    });
  }

  void _seekForward10() {
    final target =
        widget.controller.value.position + const Duration(seconds: 10);
    if (target < widget.controller.value.duration) {
      widget.controller.seekTo(target);
    } else {
      widget.controller.seekTo(widget.controller.value.duration);
    }
    _showFeedback(isForward: true);
  }

  void _seekRewind10() {
    final target =
        widget.controller.value.position - const Duration(seconds: 10);
    widget.controller.seekTo(target > Duration.zero ? target : Duration.zero);
    _showFeedback(isForward: false);
  }

  void _showFeedback({required bool isForward}) {
    _indicatorTimer?.cancel();
    setState(() {
      if (isForward) {
        _showForwardIndicator = true;
        _showRewindIndicator = false;
      } else {
        _showRewindIndicator = true;
        _showForwardIndicator = false;
      }
    });
    _indicatorTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _showForwardIndicator = false;
          _showRewindIndicator = false;
        });
      }
    });
    _startHideTimer();
  }

  void _onLongPressStart() {
    _savedSpeedBeforeLongPress = _activeSpeed;
    widget.controller.setPlaybackSpeed(2.0);
    setState(() {
      _isLongPressing2x = true;
      _showControls = false;
    });
  }

  void _onLongPressEnd() {
    widget.controller.setPlaybackSpeed(_savedSpeedBeforeLongPress);
    setState(() {
      _isLongPressing2x = false;
    });
    _startHideTimer();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFFC5A059), width: 1.2),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'سرعة التشغيل',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ...widget.speeds.map((speed) {
                final isSelected = _activeSpeed == speed;
                return ListTile(
                  title: Text(
                    speed == 1.0 ? 'عادية (1.0x)' : '${speed}x',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? goldAccent : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: goldAccent,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    setState(() => _activeSpeed = speed);
                    widget.controller.setPlaybackSpeed(speed);
                    widget.onSpeedChanged(speed);
                    Navigator.pop(ctx);
                    _startHideTimer();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _indicatorTimer?.cancel();
    _watermarkTimer?.cancel();
    widget.controller.removeListener(_videoListener);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SecurityService.disableSecureScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final durationSec = widget.controller.value.duration.inSeconds.toDouble();
    final posSec = widget.controller.value.position.inSeconds.toDouble();
    final maxSec = durationSec <= 0 ? 1.0 : durationSec;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.isInitialized
                    ? widget.controller.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(widget.controller),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedAlign(
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeInOut,
                  alignment: _watermarkAlignment,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.watermarkText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.18),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlayPause,
                onLongPressStart: (_) => _onLongPressStart(),
                onLongPressEnd: (_) => _onLongPressEnd(),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: _seekRewind10,
                        onTap: _togglePlayPause,
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: _seekForward10,
                        onTap: _togglePlayPause,
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showControls)
              Positioned(
                top: 20,
                left: 20,
                child: SafeArea(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            if (_showForwardIndicator)
              Positioned(
                right: 40,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: goldAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fast_forward_rounded,
                        color: goldAccent,
                        size: 22,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '+10s',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_showRewindIndicator)
              Positioned(
                left: 40,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: goldAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '-10s',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.fast_rewind_rounded,
                        color: goldAccent,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            if (_isLongPressing2x)
              Positioned(
                top: 30,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: goldAccent, width: 1.2),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '2x Speed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.bolt_rounded, color: goldAccent, size: 16),
                    ],
                  ),
                ),
              ),
            if (_showControls && !_isLongPressing2x)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbColor: goldAccent,
                          activeTrackColor: goldAccent,
                          inactiveTrackColor: Colors.white24,
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 10,
                          ),
                        ),
                        child: Slider(
                          value: posSec.clamp(0.0, maxSec),
                          min: 0.0,
                          max: maxSec,
                          onChanged: (val) {
                            _startHideTimer();
                            widget.controller.seekTo(
                              Duration(seconds: val.toInt()),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 12,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                widget.controller.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.replay_10_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () {
                                _startHideTimer();
                                _seekRewind10();
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.forward_10_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () {
                                _startHideTimer();
                                _seekForward10();
                              },
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_formatDuration(widget.controller.value.position)} / ${_formatDuration(widget.controller.value.duration)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: _showSpeedDialog,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: goldAccent.withValues(alpha: 0.7),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _activeSpeed == 1.0
                                      ? '1.0x'
                                      : '${_activeSpeed}x',
                                  style: const TextStyle(
                                    color: goldAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              tooltip: 'الخروج من ملء الشاشة',
                              icon: const Icon(
                                Icons.fullscreen_exit_rounded,
                                color: goldAccent,
                                size: 30,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
