/// يبني سطر التصنيف الأكاديمي "الجامعة › الكلية" من بيانات المادة
/// (يتطلب تضمين universities(name), faculties(name) في استعلام المادة).
String hierarchyPath(Map? subject) {
  if (subject == null) return '';
  String? n(dynamic v) => (v is Map ? v['name'] : null)?.toString().trim();
  final parts = [n(subject['universities']), n(subject['faculties'])]
      .where((e) => e != null && e.isNotEmpty)
      .cast<String>()
      .toList();
  return parts.join(' › ');
}
