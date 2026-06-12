import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart' as core;
import '../../../../core/value_objects/geo_point.dart';
import '../../../../core/value_objects/money.dart';
import '../../../profile/domain/entities/vendor.dart';
import '../../domain/validators/event_validators.dart';
import '../bloc/event_management_bloc.dart';

/// Vendor-facing create-event form (R5.1, R7.1–R7.4).
///
/// The form collects the raw event fields, assembles an [EventInput], and
/// dispatches [CreateRequested] to the shared [EventManagementBloc]. Creation
/// is gated on the vendor's approval status by the bloc (R5.1). On a validation
/// failure the bloc emits [Editing] carrying the submitted [EventInput] and the
/// exact set of [core.FieldError]s; the form retains the entered values and
/// surfaces each field's error beneath its input (R7.2, R7.3). On [Created] the
/// screen pops back to the manage-events list.
class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({required this.vendor, super.key});

  /// The vendor creating the event (resolved from the session).
  final Vendor vendor;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _locationLabel = TextEditingController();
  final TextEditingController _latitude = TextEditingController();
  final TextEditingController _longitude = TextEditingController();
  final TextEditingController _slots = TextEditingController();
  final TextEditingController _payPerHead = TextEditingController();

  DateTime? _date;
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _locationLabel.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _slots.dispose();
    _payPerHead.dispose();
    super.dispose();
  }

  /// Builds an [EventInput] from the current form values, parsing numeric and
  /// coordinate fields leniently so the domain validator (not construction)
  /// reports out-of-range values (R7.3).
  EventInput _buildInput() {
    return EventInput(
      title: _title.text,
      description: _description.text,
      date: _date,
      startTime: _startTime,
      endTime: _endTime,
      locationLabel: _locationLabel.text,
      geo: _parseGeo(),
      slots: int.tryParse(_slots.text.trim()),
      payPerHead: _parseMoney(),
    );
  }

  GeoPoint? _parseGeo() {
    final double? lat = double.tryParse(_latitude.text.trim());
    final double? lon = double.tryParse(_longitude.text.trim());
    if (lat == null || lon == null) {
      return null;
    }
    try {
      return GeoPoint(latitude: lat, longitude: lon);
    } on ArgumentError {
      return null;
    }
  }

  Money? _parseMoney() {
    final String raw = _payPerHead.text.trim();
    if (raw.isEmpty) {
      return null;
    }
    try {
      // Parse without enforcing the pay-per-head range so the domain validator
      // can report out-of-range amounts rather than throwing here (R7.3).
      return Money.parse(raw, requirePayPerHeadRange: false);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  void _submit(BuildContext context) {
    context.read<EventManagementBloc>().add(
          CreateRequested(
            vendor: widget.vendor,
            eventId: 'evt_${DateTime.now().microsecondsSinceEpoch}',
            input: _buildInput(),
            now: DateTime.now(),
          ),
        );
  }

  String? _errorFor(List<core.FieldError> errors, String field) {
    for (final core.FieldError error in errors) {
      if (error.field == field) {
        return error.message;
      }
    }
    return null;
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) {
      return;
    }
    final DateTime base = _date ?? DateTime.now();
    final DateTime value = DateTime(
      base.year,
      base.month,
      base.day,
      picked.hour,
      picked.minute,
    );
    setState(() {
      if (isStart) {
        _startTime = value;
      } else {
        _endTime = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EventManagementBloc, EventManagementState>(
      listenWhen: (_, EventManagementState state) =>
          state is Created || state is EventManagementFailure,
      listener: (BuildContext context, EventManagementState state) {
        if (state is Created) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Event created.')),
            );
          Navigator.of(context).pop();
        } else if (state is EventManagementFailure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (BuildContext context, EventManagementState state) {
        final List<core.FieldError> errors =
            state is Editing ? state.fieldErrors : const <core.FieldError>[];
        final bool isCreating = state is Creating;
        return Scaffold(
          appBar: AppBar(title: const Text('Create event')),
          body: AbsorbPointer(
            absorbing: isCreating,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _field(
                  controller: _title,
                  label: 'Title',
                  errorText: _errorFor(errors, EventFields.title),
                  fieldKey: 'create-event-title',
                ),
                _field(
                  controller: _description,
                  label: 'Description',
                  errorText: _errorFor(errors, EventFields.description),
                  fieldKey: 'create-event-description',
                  maxLines: 3,
                ),
                _pickerTile(
                  label: 'Date',
                  value: _date == null
                      ? 'Choose a date'
                      : '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}'
                          '-${_date!.day.toString().padLeft(2, '0')}',
                  errorText: _errorFor(errors, EventFields.date),
                  onTap: _pickDate,
                ),
                _pickerTile(
                  label: 'Start time',
                  value: _formatTime(_startTime),
                  errorText: _errorFor(errors, EventFields.startTime),
                  onTap: () => _pickTime(isStart: true),
                ),
                _pickerTile(
                  label: 'End time',
                  value: _formatTime(_endTime),
                  errorText: _errorFor(errors, EventFields.endTime),
                  onTap: () => _pickTime(isStart: false),
                ),
                _field(
                  controller: _locationLabel,
                  label: 'Location',
                  errorText: _errorFor(errors, EventFields.location),
                  fieldKey: 'create-event-location',
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _field(
                        controller: _latitude,
                        label: 'Latitude',
                        fieldKey: 'create-event-latitude',
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        controller: _longitude,
                        label: 'Longitude',
                        fieldKey: 'create-event-longitude',
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                _field(
                  controller: _slots,
                  label: 'Slots',
                  errorText: _errorFor(errors, EventFields.slots),
                  fieldKey: 'create-event-slots',
                  keyboardType: TextInputType.number,
                ),
                _field(
                  controller: _payPerHead,
                  label: 'Pay per head (₹)',
                  errorText: _errorFor(errors, EventFields.payPerHead),
                  fieldKey: 'create-event-pay',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey<String>('create-event-submit'),
                  onPressed: isCreating ? null : () => _submit(context),
                  child: isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create event'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) {
      return 'Choose a time';
    }
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String fieldKey,
    String? errorText,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: ValueKey<String>(fieldKey),
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: errorText,
        ),
      ),
    );
  }

  Widget _pickerTile({
    required String label,
    required String value,
    required VoidCallback onTap,
    String? errorText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: errorText,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(value),
                const Icon(Icons.calendar_today_outlined, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
