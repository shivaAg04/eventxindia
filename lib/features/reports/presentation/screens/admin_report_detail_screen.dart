import 'package:flutter/material.dart';

import '../../domain/entities/report.dart';

/// Admin read-only detail view of a submitted [Report] (R12.6).
///
/// Displays the report's category, full description, submitting user identity
/// (id and role), and creation timestamp for review. This is purely a
/// presentation of an already-loaded [Report] — there are no actions and no
/// bloc, since the admin reports list (backed by `ListReports`) supplies the
/// entity.
class AdminReportDetailScreen extends StatelessWidget {
  const AdminReportDetailScreen({
    required this.report,
    super.key,
  });

  /// The report being reviewed.
  final Report report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _DetailField(
            label: 'Category',
            value: _categoryLabel(report.category),
          ),
          _DetailField(
            label: 'Submitted by',
            value: '${report.submitterId} '
                '(${_roleLabel(report.submitterRole)})',
          ),
          _DetailField(
            label: 'Submitted at',
            value: _formatTimestamp(report.createdAt),
          ),
          _DetailField(
            label: 'Description',
            value: report.description,
          ),
        ],
      ),
    );
  }
}

/// A labelled, read-only value row used throughout the detail view.
class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// A human-readable label for a [ReportCategory].
String _categoryLabel(ReportCategory category) {
  switch (category) {
    case ReportCategory.fakeEvent:
      return 'Fake event';
    case ReportCategory.vendorIssue:
      return 'Vendor issue';
    case ReportCategory.noShow:
      return 'No show';
    case ReportCategory.misbehavior:
      return 'Misbehavior';
  }
}

/// A human-readable label for a [SubmitterRole].
String _roleLabel(SubmitterRole role) {
  switch (role) {
    case SubmitterRole.student:
      return 'Student';
    case SubmitterRole.vendor:
      return 'Vendor';
  }
}

/// Formats [timestamp] as a stable, zero-padded `YYYY-MM-DD HH:MM` string.
String _formatTimestamp(DateTime timestamp) {
  final DateTime local = timestamp.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
