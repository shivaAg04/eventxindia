import 'package:flutter/material.dart';

import '../../../../core/value_objects/approval_status.dart';
import '../../domain/entities/vendor.dart';

/// Vendor-facing view of their own profile (R2.6–R2.9).
///
/// A read-only presentation of the signed-in vendor's details — agency, contact,
/// address, approval status, and the optional KYC/website/social fields when
/// present. It is built from the [Vendor] already loaded for the vendor home,
/// so it needs no additional read.
class VendorProfileScreen extends StatelessWidget {
  const VendorProfileScreen({required this.vendor, super.key});

  final Vendor vendor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String initials = _initials(vendor.agencyName.isNotEmpty
        ? vendor.agencyName
        : vendor.fullName);

    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(radius: 32, child: Text(initials)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(vendor.agencyName, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(vendor.fullName, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              _ApprovalBadge(status: vendor.approvalStatus),
            ],
          ),
          const SizedBox(height: 20),
          _DetailCard(
            title: 'Contact',
            rows: <MapEntry<String, String>>[
              MapEntry<String, String>('Full name', vendor.fullName),
              MapEntry<String, String>('Agency', vendor.agencyName),
              MapEntry<String, String>('Phone', vendor.phone.e164),
              MapEntry<String, String>('City', vendor.city),
              MapEntry<String, String>('Address', vendor.address),
            ],
          ),
          const SizedBox(height: 16),
          _DetailCard(
            title: 'Account',
            rows: <MapEntry<String, String>>[
              MapEntry<String, String>(
                'Approval status',
                vendor.approvalStatus.wireName,
              ),
              MapEntry<String, String>(
                'Member since',
                _date(vendor.createdAt),
              ),
            ],
          ),
          if (_hasOptional) ...<Widget>[
            const SizedBox(height: 16),
            _DetailCard(
              title: 'Additional',
              rows: <MapEntry<String, String>>[
                if (vendor.aadhaarOrPan != null &&
                    vendor.aadhaarOrPan!.isNotEmpty)
                  MapEntry<String, String>(
                    'Aadhaar / PAN',
                    vendor.aadhaarOrPan!,
                  ),
                if (vendor.website != null && vendor.website!.isNotEmpty)
                  MapEntry<String, String>('Website', vendor.website!),
                if (vendor.socialLinks.isNotEmpty)
                  MapEntry<String, String>(
                    'Social links',
                    vendor.socialLinks.join('\n'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasOptional =>
      (vendor.aadhaarOrPan != null && vendor.aadhaarOrPan!.isNotEmpty) ||
      (vendor.website != null && vendor.website!.isNotEmpty) ||
      vendor.socialLinks.isNotEmpty;

  static String _initials(String name) {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static String _date(DateTime d) {
    final DateTime l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year}';
  }
}

/// A titled card rendering a list of label/value rows.
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.rows});

  final String title;
  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleMedium),
            const Divider(height: 20),
            for (final MapEntry<String, String> row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(width: 120, child: Text(row.key)),
                    Expanded(
                      child: Text(
                        row.value,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A compact coloured chip for the vendor's approval status.
class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({required this.status});

  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      ApprovalStatus.approved => Colors.greenAccent,
      ApprovalStatus.rejected => Theme.of(context).colorScheme.error,
      ApprovalStatus.pending => Colors.amberAccent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.wireName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
