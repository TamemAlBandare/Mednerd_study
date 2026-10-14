import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'security_service.dart';
import 'vault_security_service.dart';
import 'backend_errors.dart';

class ProtectedPdfViewerScreen extends StatefulWidget {
  final String lectureId;
  final String title;
  final String? directPdfUrl;
  final String? telegramPdfId;
  final String? studentName;
  final String? subjectId;

  const ProtectedPdfViewerScreen({
    super.key,
    required this.lectureId,
    required this.title,
    this.directPdfUrl,
    this.telegramPdfId,
    this.studentName,
    this.subjectId,
  });

  @override
  State<ProtectedPdfViewerScreen> createState() =>
      _ProtectedPdfViewerScreenState();
}

class _ProtectedPdfViewerScreenState extends State<ProtectedPdfViewerScreen> {
  Uint8List? _activePdfBytes;
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isOfflineAvailable = false;
  String? _errorMessage;
  int _totalPages = 0;
  int _currentPage = 0;

  String _watermarkText = 'MEDNERD';
  Alignment _watermarkAlignment = Alignment.topRight;
  Timer? _watermarkTimer;
  final Random _random = Random();

  String get _effectiveSubjectId =>
      (widget.subjectId != null && widget.subjectId!.trim().isNotEmpty)
          ? widget.subjectId!.trim()
          : widget.lectureId;

  @override
  void initState() {
    super.initState();
    _enableSecureScreen();
    _resolveWatermark();
    _checkAndOpenPdf();
    _startWatermarkAnimation();
  }

  Future<void> _enableSecureScreen() => SecurityService.enableSecureScreen();

  Future<void> _disableSecureScreen() => SecurityService.disableSecureScreen();

  void _resolveWatermark() {
    if (widget.studentName != null && widget.studentName!.isNotEmpty) {
      _watermarkText = widget.studentName!;
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (user.userMetadata != null &&
          user.userMetadata!['full_name'] != null) {
        _watermarkText = user.userMetadata!['full_name'].toString();
      } else if (user.email != null) {
        _watermarkText = user.email!.split('@').first;
      }
    }
  }

  void _startWatermarkAnimation() {
    _watermarkTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() {
          final double x = (_random.nextDouble() * 1.6) - 0.8;
          final double y = (_random.nextDouble() * 1.6) - 0.8;
          _watermarkAlignment = Alignment(x, y);
        });
      }
    });
  }

  Future<File> _getVaultFile() async {
    final dir = await getApplicationSupportDirectory();
    final vaultDir = Directory('${dir.path}/.offline_vault');
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);

    final fileName = VaultSecurityService.buildVaultFileName(
      subjectId: _effectiveSubjectId,
      lectureId: widget.lectureId,
    );
    final newFile = File('${vaultDir.path}/$fileName');

    // توافق رجعي مع الصيغة القديمة إذا كان الملف قد حُفظ سابقاً
    if (!await newFile.exists()) {
      final legacyName = 'lec_${widget.lectureId.replaceAll('-', '')}.med_vault';
      final legacyFile = File('${vaultDir.path}/$legacyName');
      if (await legacyFile.exists()) {
        await legacyFile.rename(newFile.path);
      }
    }
    return newFile;
  }

  Future<void> _checkAndOpenPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dynamicKey = await VaultSecurityService.getOrRenewVaultKey(
        subjectId: _effectiveSubjectId,
      );

      if (dynamicKey == null) {
        throw Exception(
            'تم تعليق أو انتهاء صلاحية ترخيص هذا المقرر. يرجى الاتصال بالإنترنت لتجديد الصلاحية.');
      }

      final vaultFile = await _getVaultFile();
      final fileName = vaultFile.path.split(Platform.pathSeparator).last;

      // 1. إذا كان الملف محفوظاً مسبقاً، يتم فك تشفيره بالمفتاح الديناميكي
      if (await vaultFile.exists()) {
        final encryptedData = await vaultFile.readAsBytes();
        final rawPdfBytes =
            await VaultSecurityService.decryptBytes(encryptedData, dynamicKey);
        if (VaultSecurityService.isLegacyFormat(encryptedData)) {
          await vaultFile.writeAsBytes(
            await VaultSecurityService.encryptBytes(rawPdfBytes, dynamicKey),
            flush: true,
          );
        }

        await VaultSecurityService.saveFileMeta(
          fileName: fileName,
          lectureId: widget.lectureId,
          subjectId: _effectiveSubjectId,
          title: widget.title,
        );

        if (mounted) {
          setState(() {
            _activePdfBytes = rawPdfBytes;
            _isOfflineAvailable = true;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. إذا لم يكن محفوظاً، نتحقق من الرابط المباشر أو معرف تيليجرام
      String? resolvedUrl = widget.directPdfUrl?.trim();
      if ((resolvedUrl == null || resolvedUrl.isEmpty) &&
          widget.telegramPdfId != null &&
          widget.telegramPdfId!.trim().isNotEmpty) {
        final tgId = widget.telegramPdfId!.trim();
        if (tgId.startsWith('http')) {
          resolvedUrl = tgId;
        } else {
          try {
            final res = await Supabase.instance.client.rpc(
              'get_telegram_pdf_url',
              params: {'p_file_id': tgId},
            );
            resolvedUrl = res?.toString();
          } catch (_) {
            resolvedUrl = tgId;
          }
        }
      }

      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        throw Exception(
            'هذا الملخص غير متاح للتحميل حالياً أو لم يتم إضافة رابط له.');
      }

      setState(() => _isDownloading = true);

      var pdfUrl = resolvedUrl;
      if (!pdfUrl.startsWith('http')) {
        pdfUrl = await Supabase.instance.client.storage
            .from('lecture-pdfs')
            .createSignedUrl(pdfUrl, 120);
      }

      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode != 200) {
        throw Exception(
            'فشل الاتصال لتحميل الملف (رمز الخطأ: ${response.statusCode})');
      }

      final rawPdfBytes = response.bodyBytes;
      final encryptedBytes =
          await VaultSecurityService.encryptBytes(rawPdfBytes, dynamicKey);

      await vaultFile.writeAsBytes(encryptedBytes, flush: true);
      await VaultSecurityService.saveFileMeta(
        fileName: fileName,
        lectureId: widget.lectureId,
        subjectId: _effectiveSubjectId,
        title: widget.title,
      );

      if (mounted) {
        setState(() {
          _activePdfBytes = rawPdfBytes;
          _isOfflineAvailable = true;
          _isDownloading = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final rawMsg = e.toString().replaceAll('Exception: ', '');
          _errorMessage = RegExp(r'[\u0600-\u06FF]').hasMatch(rawMsg)
              ? rawMsg
              : friendlyError(e);
          _isDownloading = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteDownloadedPdf() async {
    final vaultFile = await _getVaultFile();
    final fileName = vaultFile.path.split(Platform.pathSeparator).last;
    if (await vaultFile.exists()) await vaultFile.delete();
    await VaultSecurityService.removeFileMeta(fileName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          content: Text('تم حذف الملخص من الذاكرة المحلية.'),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _disableSecureScreen();
    _watermarkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF0B0F17) : const Color(0xFFF3EFE6);
    final cardBg = isDark ? const Color(0xFF151E2E) : const Color(0xFF0E332E);
    const border = Color(0xFFC5A059);
    const goldAccent = Color(0xFFD8B467);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Icon(
                  _isOfflineAvailable
                      ? Icons.check_circle_rounded
                      : Icons.cloud_download_rounded,
                  color: _isOfflineAvailable
                      ? const Color(0xFF10B981)
                      : goldAccent,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  _isOfflineAvailable
                      ? 'محفوظ ومحمي ديناميكياً'
                      : 'جاري الحفظ المشفر',
                  style: TextStyle(
                    color: _isOfflineAvailable
                        ? const Color(0xFF10B981)
                        : Colors.white60,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: goldAccent, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isOfflineAvailable)
            IconButton(
              tooltip: 'حذف من التحميلات المحلية',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white60, size: 20),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: cardBg,
                    title: const Text('حذف الملخص',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    content: const Text(
                      'هل تريد إزالة هذا الملخص من التخزين بدون إنترنت؟ ستحتاج لإعادة تحميله لاحقاً.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء',
                            style: TextStyle(color: Colors.white60)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteDownloadedPdf();
                        },
                        child: const Text('حذف',
                            style: TextStyle(color: Color(0xFFEF4444))),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: const TextStyle(
                      color: goldAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading || _isDownloading)
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border.withOpacity(0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: goldAccent),
                    const SizedBox(height: 18),
                    Text(
                      _isDownloading
                          ? 'جاري التحقق وتشفير الملخص...'
                          : 'جاري فك تشفير الخزنة الآمنة...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'تشفير ديناميكي مرتبط بصلاحية اشتراكك',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gpp_bad_rounded,
                        color: Color(0xFFEF4444), size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color:
                              isDark ? Colors.white70 : const Color(0xFF0E332E),
                          fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _checkAndOpenPdf,
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
          else if (_activePdfBytes != null)
            PDFView(
              pdfData: _activePdfBytes,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              nightMode: isDark,
              onRender: (pages) {
                setState(() => _totalPages = pages ?? 0);
              },
              onPageChanged: (page, total) {
                setState(() => _currentPage = page ?? 0);
              },
            ),
          if (!_isLoading && !_isDownloading && _errorMessage == null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedAlign(
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeInOut,
                  alignment: _watermarkAlignment,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _watermarkText,
                      style: TextStyle(
                        color: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.black.withOpacity(0.18),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
