import 'package:flutter/material.dart';

import '../../../../core/value_objects/event_status.dart';
import '../../../../core/value_objects/money.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/domain/event_status_policy.dart';
import '../../../profile/domain/entities/vendor.dart';

/// The event status filter on the admin vendor detail.
enum _VendorEventFilter { all, active, closed, completed }

/// Admin drill-down for a single vendor (R6): profile detail, a **summary**
/// (total events + total budget across them), a **status filter**, and the
/// filtered list of the vendor's events.
class AdminVendorDetailScreen extends StatefulWidget {
  const AdminVendorDetailScreen({
    required this.vendor,
    required this.eventsStream,
    required this.onOpenEvent,
    super.key,
  });

  final Vendor vendor;
  final Stream<List<Event>> eventsStream;

  /// Opens the admin event-detail page when an event card is tapped.
  final void Function(BuildContext context, String eventId) onOpenEvent;

  @override
  State<AdminVendorDetailScreen> createState() =>
      _AdminVendorDetailScreenState();
}

class _AdminVendorDetailScreenState extends State<AdminVendorDetailScreen> {
  _VendorEventFilter _filter = _VendorEventFilter.all;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  EventStatus? _target(_VendorEventFilter f) => switch (f) {
        _VendorEventFilter.all => null,
        _VendorEventFilter.active => EventStatus.active,
        _VendorEventFilter.closed => EventStatus.closed,
        _VendorEventFilter.completed => EventStatus.completed,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.vendor.agencyName)),
      body: StreamBuilder<List<Event>>(
        stream: widget.eventsStream,
        builder: (BuildContext context, AsyncSnapshot<List<Event>> snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<Event> events = snap.data!;
          final DateTime now = DateTime.now();

          // Total budget across all the vendor's events (pay × capacity).
          int totalMinor = 0;
          for (final Event e in events) {
            totalMinor += e.payPerHead.minorUnits * e.slots;
          }
          final Money totalBudget =
              Money.fromMinorUnits(totalMinor, requirePayPerHeadRange: false);

          final EventStatus? target = _target(_filter);
          final String q = _query.toLowerCase();
          final List<Event> visible = events.where((Event e) {
            if (target != null && effectiveEventStatus(e, now) != target) {
              return false;
            }
            if (q.isNotEmpty && !e.title.toLowerCase().contains(q)) {
              return false;
            }
            return true;
          }).toList(growable: false);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _ProfileCard(vendor: widget.vendor),
              const SizedBox(height: 16),
              _SummaryCard(
                totalEvents: events.length,
                totalBudget: totalBudget,
              ),
              const SizedBox(height: 20),
              Text('Events', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                onChanged: (String v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search events by name',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              _FilterBar(
                filter: _filter,
                onChanged: (_VendorEventFilter f) =>
                    setState(() => _filter = f),
              ),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                Text('No events match your search or filter.',
                    style: theme.textTheme.bodySmall)
              else
                for (final Event e in visible)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(e.title),
                    subtitle: Text(
                      '${effectiveEventStatus(e, now).wireName} • '
                      '${e.slots} slots • ₹${e.payPerHead.formatted}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onOpenEvent(context, e.eventId),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.vendor});

  final Vendor vendor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _row('Agency', vendor.agencyName),
            _row('Contact', vendor.fullName),
            _row('Phone', vendor.phone.e164),
            _row('City', vendor.city),
            _row('Address', vendor.address),
            _row('Approval', vendor.approvalStatus.wireName),
            if (vendor.website != null && vendor.website!.isNotEmpty)
              _row('Website', vendor.website!),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(width: 100, child: Text(label)),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totalEvents, required this.totalBudget});

  final int totalEvents;
  final Money totalBudget;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _metric(theme, 'Total events', '$totalEvents'),
            ),
            Container(width: 1, height: 40, color: theme.dividerColor),
            Expanded(
              child: _metric(
                  theme, 'Total budget', '₹${totalBudget.formatted}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(ThemeData theme, String label, String value) => Column(
        children: <Widget>[
          Text(value,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final _VendorEventFilter filter;
  final ValueChanged<_VendorEventFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const Map<_VendorEventFilter, String> labels = <_VendorEventFilter, String>{
      _VendorEventFilter.all: 'All',
      _VendorEventFilter.active: 'Active',
      _VendorEventFilter.closed: 'Closed',
      _VendorEventFilter.completed: 'Completed',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final MapEntry<_VendorEventFilter, String> e in labels.entries)
            ...<Widget>[
            ChoiceChip(
              key: ValueKey<String>('vendor-filter-${e.key.name}'),
              label: Text(e.value),
              selected: filter == e.key,
              onSelected: (_) => onChanged(e.key),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
