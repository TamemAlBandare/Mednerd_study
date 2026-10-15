import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'main.dart';
import 'pdf_viewer_screen.dart';
import 'vault_security_service.dart';
import 'backend_errors.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _vaultItems = [];
  int _totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadVaultFiles();
  }

  String _restoreUuidIfNeeded(String raw) {
    if (raw.length == 32 && !raw.contains('-')) {
      return '${raw.substring(0, 8)}-${raw.substring(8, 12)}-${raw.substring(12, 16)}-${raw.substring(16, 20)}-${raw.substring(20)}';
    }
    return raw;
  }

  Future<void> _loadVaultFiles() async {
    setState(() => _isLoading = true);
    try {
      final dir = await getApplicationSupportDirectory();
      final vaultDir = Directory('${dir.path}/.offline_vault');

      if (await vaultDir.exists()) {
        final files = vaultDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.med_vault'))
            .toList();

        int sumBytes = 0;
        final List<Map<String, dynamic>> items = [];
        for (final file in files) {
          sumBytes += file.lengthSync();
          final fileName = file.path.split(Platform.pathSeparator).last;
          final baseName = fileName.replaceAll('.med_vault', '');
          final meta = await VaultSecurityService.getFileMeta(fileName);

          String lectureId = meta?['lecture_id'] ?? '';
          String? subjectId = meta?['subject_id'];
          String title = meta?['title'] ?? '';

          if (lectureId.isEmpty) {
            if (baseName.startsWith('sub_') && baseName.contains('_lec_')) {
              final parts = baseName.substring(4).split('_lec_');
              subjectId = _restoreUuidIfNeeded(parts.first);
              lectureId = _restoreUuidIfNeeded(parts.last);
            } else {
              lectureId = _restoreUuidIfNeeded(
                baseName.replaceFirst('lec_', ''),
              );
            }
          }

          if (title.isEmpty) {
            title = 'ملخص المحاضرة';
          }

          items.add({
            'file': file,
            'fileName': fileName,
            'lectureId': lectureId,
            'subjectId': subjectId,
            'title': title,
          });
        }

        if (mounted) {
          setState(() {
            _vaultItems = items;
            _totalBytes = sumBytes;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _vaultItems = [];
            _totalBytes = 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading downloads: $e');
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTotalSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getFileSize(File file) {
    return _formatTotalSize(file.lengthSync());
  }

  Future<void> _deleteFile(File file, String fileName) async {
    try {
      await file.delete();
      await VaultSecurityService.removeFileMeta(fileName);
      _loadVaultFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            content: Text('تمت إزالة الملخص من الخزنة المحلية.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر حذف الملف')));
      }
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
          'المحملات الذكية (أوفلاين)',
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
          : Column(
              children: [
                if (_vaultItems.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.security_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'المحملات محمية ومتاحة للقراءة بدون إنترنت (${_vaultItems.length} ملف • ${_formatTotalSize(_totalBytes)})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _vaultItems.isEmpty
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
                                    Icons.cloud_off_rounded,
                                    color: goldAccent,
                                    size: 44,
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    'لا توجد ملخصات محفوظة محلياً',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'عند فتح أي ملخص PDF للمحاضرات سيتم حفظه تلقائياً للقراءة بدون إنترنت.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(18),
                          itemCount: _vaultItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _vaultItems[index];
                            final file = item['file'] as File;
                            final fileName = item['fileName'] as String;
                            final lectureId = item['lectureId'] as String;
                            final subjectId = item['subjectId'] as String?;
                            final title = item['title'] as String;
                            final size = _getFileSize(file);

                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProtectedPdfViewerScreen(
                                      lectureId: lectureId,
                                      subjectId: subjectId,
                                      title: title,
                                    ),
                                  ),
                                ).then((_) => _loadVaultFiles());
                              },
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
                                      color: Colors.black.withOpacity(0.18),
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
                                        border: Border.all(
                                          color: border.withOpacity(0.6),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.picture_as_pdf_rounded,
                                        color: goldAccent,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.lock_rounded,
                                                color: Color(0xFF10B981),
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'مشفر • $size',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.65),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFEF4444),
                                        size: 22,
                                      ),
                                      onPressed: () =>
                                          _deleteFile(file, fileName),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: goldAccent,
                                      size: 18,
                                    ),
                                  ],
                                ),
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
