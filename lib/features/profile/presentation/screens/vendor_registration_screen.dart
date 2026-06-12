import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/validators/profile_validators.dart';
import '../bloc/registration_bloc.dart';
import '../bloc/registration_event.dart';
import '../bloc/registration_state.dart';

/// Vendor registration form wired to the [RegistrationBloc] (R2.6–R2.8).
///
/// As the user edits, [VendorFieldsChanged] keeps the bloc's [VendorFormData]
/// draft in sync so entered values survive a rejected submission (R2.8).
/// Submitting dispatches [VendorSubmitted]; per-field errors from
/// [RegistrationEditing.fieldErrors] are surfaced beneath the offending field,
/// and a non-validation [RegistrationFailure] is shown via a snackbar. The
/// optional Aadhaar/PAN, website, and social-link fields are stored only when
/// provided (R2.7).
///
/// The widget reads its [RegistrationBloc] from the surrounding [BlocProvider],
/// so it never talks to a use case or repository directly.
class VendorRegistrationScreen extends StatefulWidget {
  const VendorRegistrationScreen({required this.uid, super.key});

  /// The authenticated vendor's id (their profile id).
  final String uid;

  @override
  State<VendorRegistrationScreen> createState() =>
      _VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState extends State<VendorRegistrationScreen> {
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _agencyName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _aadhaarOrPan = TextEditingController();
  final TextEditingController _website = TextEditingController();
  final TextEditingController _socialLinks = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _agencyName.dispose();
    _phone.dispose();
    _city.dispose();
    _address.dispose();
    _aadhaarOrPan.dispose();
    _website.dispose();
    _socialLinks.dispose();
    super.dispose();
  }

  /// Splits the comma/newline-separated social-link text into a trimmed,
  /// non-empty list, preserving order.
  List<String> _parseSocialLinks() {
    return _socialLinks.text
        .split(RegExp(r'[,\n]'))
        .map((String link) => link.trim())
        .where((String link) => link.isNotEmpty)
        .toList();
  }

  /// Returns the trimmed text, or `null` when empty, so optional fields are
  /// stored only when provided (R2.7).
  String? _optional(String raw) {
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _syncFields(BuildContext context) {
    context.read<RegistrationBloc>().add(
          VendorFieldsChanged(
            VendorFormData(
              fullName: _fullName.text,
              agencyName: _agencyName.text,
              phone: _phone.text,
              city: _city.text,
              address: _address.text,
              aadhaarOrPan: _optional(_aadhaarOrPan.text),
              website: _optional(_website.text),
              socialLinks: _parseSocialLinks(),
            ),
          ),
        );
  }

  void _submit(BuildContext context) {
    _syncFields(context);
    context.read<RegistrationBloc>().add(VendorSubmitted(uid: widget.uid));
  }

  String? _errorFor(RegistrationState state, String field) {
    if (state is! RegistrationEditing) {
      return null;
    }
    for (final FieldError error in state.fieldErrors) {
      if (error.field == field) {
        return error.message;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor registration')),
      body: BlocConsumer<RegistrationBloc, RegistrationState>(
        listener: (BuildContext context, RegistrationState state) {
          final ScaffoldMessengerState messenger =
              ScaffoldMessenger.of(context);
          if (state is Registered) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Profile created.')),
              );
          } else if (state is RegistrationFailure) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (BuildContext context, RegistrationState state) {
          final bool busy = state is RegistrationSubmitting;
          return AbsorbPointer(
            absorbing: busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _field(
                  controller: _fullName,
                  label: 'Full name',
                  fieldKey: 'vendor-full-name',
                  errorText: _errorFor(state, ProfileFields.fullName),
                  onChanged: () => _syncFields(context),
                ),
                _field(
                  controller: _agencyName,
                  label: 'Agency name',
                  fieldKey: 'vendor-agency-name',
                  errorText: _errorFor(state, ProfileFields.agencyName),
                  onChanged: () => _syncFields(context),
                ),
                _field(
                  controller: _phone,
                  label: 'Phone number (10 digits)',
                  fieldKey: 'vendor-phone',
                  keyboardType: TextInputType.phone,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  errorText: _errorFor(state, 'phone'),
                  onChanged: () => _syncFields(context),
                ),
                _field(
                  controller: _city,
                  label: 'City',
                  fieldKey: 'vendor-city',
                  errorText: _errorFor(state, ProfileFields.city),
                  onChanged: () => _syncFields(context),
                ),
                _field(
                  controller: _address,
                  label: 'Address',
                  fieldKey: 'vendor-address',
                  maxLines: 2,
                  errorText: _errorFor(state, ProfileFields.address),
                  onChanged: () => _syncFields(context),
                ),
                const Divider(height: 32),
                const Text('Optional'),
                const SizedBox(height: 12),
                _field(
                  controller: _aadhaarOrPan,
                  label: 'Aadhaar / PAN',
                  fieldKey: 'vendor-aadhaar-pan',
                  onChanged: () => _syncFields(context),
                ),
                _field(
                  controller: _website,
                  label: 'Website',
                  fieldKey: 'vendor-website',
                  keyboardType: TextInputType.url,
                  onChanged: () => _syncFields(context),
                ),
                _field(
                  controller: _socialLinks,
                  label: 'Social links (comma separated)',
                  fieldKey: 'vendor-social-links',
                  maxLines: 2,
                  onChanged: () => _syncFields(context),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey<String>('vendor-register-submit'),
                  onPressed: busy ? null : () => _submit(context),
                  child: busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create profile'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String fieldKey,
    required VoidCallback onChanged,
    String? errorText,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: ValueKey<String>(fieldKey),
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: errorText,
        ),
      ),
    );
  }
}
