enum ApprovalStatus {
  approved,
  pending,
  rejected,
  expired,
  unknown;

  static ApprovalStatus parse(Object? value) =>
      ApprovalStatus.values.firstWhere((s) => s.name == value, orElse: () => ApprovalStatus.unknown);

  String get label => switch (this) {
        approved => 'Approved',
        pending => 'Approval pending',
        rejected => 'Registration rejected',
        expired => 'Approval expired',
        unknown => 'Unknown status',
      };
}

/// Reference photos ship inside the app (assets/medicines/); a medicine
/// document names the file.
String? medicinePhotoAsset(Object? fileName) =>
    fileName is String && fileName.isNotEmpty ? 'assets/medicines/$fileName' : null;

/// A registered medicine: a `medicines/{barcode}` document.
class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    required this.genericName,
    required this.manufacturer,
    required this.dosageForm,
    required this.strength,
    required this.barcode,
    required this.regulatoryBody,
    required this.approvalNumber,
    required this.approvalStatus,
    this.tabletPhotoAsset,
    this.packagePhotoAsset,
    this.packageVerification = const [],
  });

  factory Medicine.fromFirestore(String id, Map<String, dynamic> data) {
    final photos = data['photos'] as Map<String, dynamic>? ?? const {};
    return Medicine(
      id: id,
      name: data['name'] as String,
      genericName: data['genericName'] as String?,
      manufacturer: data['manufacturer'] as String,
      dosageForm: data['dosageForm'] as String?,
      strength: data['strength'] as String?,
      barcode: data['barcode'] as String? ?? id,
      regulatoryBody: data['regulatoryBody'] as String,
      approvalNumber: data['approvalNumber'] as String,
      approvalStatus: ApprovalStatus.parse(data['approvalStatus']),
      tabletPhotoAsset: medicinePhotoAsset(photos['tablet']),
      packagePhotoAsset: medicinePhotoAsset(photos['package']),
      packageVerification: (data['packageVerification'] as List? ?? const []).cast<String>(),
    );
  }

  /// The document ID, which is the barcode.
  final String id;
  final String name;
  final String? genericName;
  final String manufacturer;
  final String? dosageForm;
  final String? strength;
  final String barcode;
  final String regulatoryBody;
  final String approvalNumber;
  final ApprovalStatus approvalStatus;

  /// Asset paths of the reference photos; null when that angle isn't on file.
  final String? tabletPhotoAsset;
  final String? packagePhotoAsset;

  /// "How to identify a genuine package" checklist.
  final List<String> packageVerification;
}

/// Medicines matching a search, best matches first: name starts with the
/// query, then name contains it, then generic name contains it. Case-
/// insensitive, like the old API's ILIKE search.
List<Medicine> searchMedicines(Iterable<Medicine> medicines, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  int? rank(Medicine m) {
    final name = m.name.toLowerCase();
    if (name.startsWith(q)) return 0;
    if (name.contains(q)) return 1;
    if (m.genericName?.toLowerCase().contains(q) ?? false) return 2;
    return null;
  }

  final ranked = [
    for (final m in medicines)
      if (rank(m) case final r?) (r, m),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2.name.compareTo(b.$2.name));
  return [for (final (_, m) in ranked) m];
}
