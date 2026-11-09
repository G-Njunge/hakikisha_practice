import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportStatus {
  pending,
  investigating,
  escalated,
  resolved,
  dismissed;

  static ReportStatus parse(Object? value) =>
      ReportStatus.values.firstWhere((s) => s.name == value, orElse: () => ReportStatus.pending);

  String get label => switch (this) {
        pending => 'Pending',
        investigating => 'Investigating',
        escalated => 'Escalated',
        resolved => 'Resolved',
        dismissed => 'Dismissed',
      };

  bool get isClosed => this == resolved || this == dismissed;
}

/// What an admin can do with a report, as on the old API: review and
/// escalate move it along; approve and dismiss close it.
enum ReportAction {
  review(ReportStatus.investigating, 'Start review'),
  escalate(ReportStatus.escalated, 'Escalate'),
  approve(ReportStatus.resolved, 'Confirm & resolve'),
  dismiss(ReportStatus.dismissed, 'Dismiss');

  const ReportAction(this.result, this.label);

  final ReportStatus result;
  final String label;

  /// Closing actions also record who closed the report and when.
  bool get closes => result.isClosed;
}

/// Actions that make sense from [status]: nothing once a report is closed,
/// and never "back" to an earlier stage.
List<ReportAction> availableActions(ReportStatus status) => switch (status) {
      ReportStatus.pending => ReportAction.values,
      ReportStatus.investigating => [ReportAction.escalate, ReportAction.approve, ReportAction.dismiss],
      ReportStatus.escalated => [ReportAction.approve, ReportAction.dismiss],
      ReportStatus.resolved || ReportStatus.dismissed => const [],
    };

/// A counterfeit report, as admins see it.
class Report {
  const Report({
    required this.id,
    required this.scanId,
    required this.productName,
    required this.medicineName,
    required this.description,
    required this.country,
    required this.purchaseLocation,
    required this.hasPhoto,
    required this.status,
    required this.reportedBy,
    required this.createdAt,
    required this.adminNotes,
    required this.regulatorNotifiedAt,
    required this.resolvedAt,
  });

  factory Report.fromFirestore(String id, Map<String, dynamic> data) => Report(
        id: id,
        scanId: data['scanId'] as String?,
        productName: data['productName'] as String?,
        medicineName: data['medicineName'] as String?,
        description: data['description'] as String? ?? '',
        country: data['country'] as String? ?? '',
        purchaseLocation: data['purchaseLocation'] as String?,
        hasPhoto: data['hasPhoto'] as bool? ?? false,
        status: ReportStatus.parse(data['status']),
        reportedBy: data['reportedBy'] as String?,
        createdAt: _date(data['createdAt']),
        adminNotes: data['adminNotes'] as String?,
        regulatorNotifiedAt: _date(data['regulatorNotifiedAt']),
        resolvedAt: _date(data['resolvedAt']),
      );

  final String id;
  final String? scanId;
  final String? productName;
  final String? medicineName;
  final String description;
  final String country;
  final String? purchaseLocation;
  final bool hasPhoto;
  final ReportStatus status;
  final String? reportedBy;
  final DateTime? createdAt;
  final String? adminNotes;
  final DateTime? regulatorNotifiedAt;
  final DateTime? resolvedAt;

  /// The registered medicine's name when the report came from a scan of one,
  /// otherwise what the reporter typed.
  String get displayName => medicineName ?? productName ?? 'Unknown product';
}

/// The email an admin sends a regulator about a report. There's no server on
/// the free Firebase plan, so the app opens the admin's own mail app with
/// this filled in. Same content as the old automated alert.
({String subject, String body}) regulatorEmail(Report report) {
  final filed = report.createdAt == null ? 'Unknown' : formatDate(report.createdAt!);
  final lines = [
    'A counterfeit medicine report has been filed in Hakikisha.',
    '',
    'Product: ${report.displayName}',
    if (report.productName != null && report.productName != report.displayName) 'Name given: ${report.productName}',
    'Country: ${report.country}',
    if (report.purchaseLocation != null) 'Where bought: ${report.purchaseLocation}',
    'Date filed: $filed',
    if (report.hasPhoto) 'Photo: attached to the report in Hakikisha',
    '',
    'Description:',
    report.description,
    '',
    'Hakikisha report reference: ${report.id}',
  ];
  return (subject: 'Counterfeit medicine report: ${report.displayName}', body: lines.join('\n'));
}

String formatDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final d = date.toLocal();
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;
