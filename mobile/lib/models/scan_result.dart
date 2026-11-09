import 'medicine.dart';

/// The outcome of scanning a barcode.
class ScanResult {
  const ScanResult({
    required this.verified,
    required this.scanId,
    required this.barcode,
    required this.medicine,
    required this.batchNumber,
    required this.expiryDate,
    required this.message,
  });

  final bool verified;

  /// ID of the `scans` log entry, which a report can link to.
  final String scanId;
  final String barcode;

  /// Null when the barcode isn't in the Hakikisha registry at all.
  final ScannedMedicine? medicine;

  /// Batch-level data. The registry doesn't hold batches yet, so these are
  /// always null for now.
  final String? batchNumber;
  final DateTime? expiryDate;

  /// Status-specific explanation (pending/rejected/expired approval, or an
  /// unknown barcode). Null for a clean, approved match.
  final String? message;

  /// The value logged in `scans.result`; the security rules check it agrees
  /// with the registry.
  String get resultCode => verified ? 'authentic' : 'unknown';
}

class ScannedMedicine {
  const ScannedMedicine({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.approvalStatus,
  });

  final String id;
  final String name;
  final String manufacturer;
  final ApprovalStatus approvalStatus;
}

/// Decides what a scan means from the barcode's `medicines` document (null
/// when it isn't registered). Same rules and wording as the old API.
ScanResult evaluateScan({
  required String barcode,
  required String scanId,
  required Map<String, dynamic>? medicine,
}) {
  if (medicine == null) {
    return ScanResult(
      verified: false,
      scanId: scanId,
      barcode: barcode,
      medicine: null,
      batchNumber: null,
      expiryDate: null,
      message: 'This barcode does not exist in the Hakikisha database.',
    );
  }

  final status = ApprovalStatus.parse(medicine['approvalStatus']);
  return ScanResult(
    verified: status == ApprovalStatus.approved,
    scanId: scanId,
    barcode: barcode,
    medicine: ScannedMedicine(
      id: barcode,
      name: medicine['name'] as String,
      manufacturer: medicine['manufacturer'] as String,
      approvalStatus: status,
    ),
    batchNumber: null,
    expiryDate: null,
    message: switch (status) {
      ApprovalStatus.approved => null,
      ApprovalStatus.pending => 'This medicine is registered but awaiting regulatory approval.',
      ApprovalStatus.rejected => "This medicine's registration was rejected by the regulator — treat with caution.",
      ApprovalStatus.expired => "This medicine's regulatory approval has expired.",
      ApprovalStatus.unknown => 'This medicine is registered but not yet approved.',
    },
  );
}
