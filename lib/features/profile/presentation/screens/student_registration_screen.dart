import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/student.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../domain/validators/profile_validators.dart';
import '../bloc/registration_bloc.dart';
import '../bloc/registration_event.dart';
import '../bloc/registration_state.dart';
import 'profile_photo_picker.dart';

/// Student registration form wired to the [RegistrationBloc] (R1.5–R1.9).
///
/// As the user edits, [StudentFieldsChanged] keeps the bloc's [StudentFormData]
/// draft in sync so entered values survive a rejected submission (R1.7). The
/// profile photo is chosen through the injected [ProfilePhotoPicker] and pushed
/// to the bloc via [PhotoPicked] (R1.8). Submitting dispatches
/// [StudentSubmitted]; per-field errors from [RegistrationEditing.fieldErrors]
/// are surfaced beneath the offending field, and a non-validation
/// [RegistrationFailure] is shown via a snackbar.
///
/// The widget reads its [RegistrationBloc] from the surrounding [BlocProvider],
/// so it never talks to a use case or repository directly.
class StudentRegistrationScreen extends StatefulWidget {
  const StudentRegistrationScreen({
    required this.uid,
    this.photoPicker = const StubPhotoPicker(),
    super.key,
  });

  /// The authenticated student's id (their profile id).
  final String uid;

  /// The picker used to choose a profile photo (R1.8).
  final ProfilePhotoPicker photoPicker;

  @override
  State<StudentRegistrationScreen> createState() =>
      _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _height = TextEditingController();

  Gender? _gender;
  DateTime? _dateOfBirth;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _city.dispose();
    _height.dispose();
    super.dispose();
  }

  /// Pushes the current form values into the bloc as a [StudentFormData] draft,
  /// preserving any already-picked photo held in the bloc's state.
  void _syncFields(BuildContext context) {
    final RegistrationBloc bloc = context.read<RegistrationBloc>();
    final PhotoUpload? photo = bloc.state.studentForm.photo;
    bloc.add(
      StudentFieldsChanged(
        StudentFormData(
          fullName: _fullName.text,
          phone: _phone.text,
          gender: _gender,
          dateOfBirth: _dateOfBirth,
          city: _city.text,
          height: _height.text,
          photo: photo,
        ),
      ),
    );
  }

  Future<void> _pickPhoto(BuildContext context) async {
    final RegistrationBloc bloc = context.read<RegistrationBloc>();
    final PhotoUpload? photo = await widget.photoPicker.pickPhoto();
    if (photo == null) {
      return;
    }
    bloc.add(PhotoPicked(photo));
  }

  void _submit(BuildContext context) {
    _syncFields(context);
    context.read<RegistrationBloc>().add(StudentSubmitted(uid: widget.uid));
  }

  Future<void> _pickDateOfBirth(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
      if (context.mounted) {
        _syncFields(context);
      }
    }
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
      appBar: AppBar(title: const Text('Student registration')),
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
          final PhotoUpload? photo = state.studentForm.photo;
          return AbsorbPointer(
            absorbing: busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _field(
                  controller: _fullName,
                  label: 'Full name',
                  fieldKey: 'student-full-name',
                  errorText: _errorFor(state, ProfileFields.fullName),
                  onChanged: () => _syncFields(context),
                ),
                _field(
                  controller: _phone,
                  label: 'Phone number',
                  fieldKey: 'student-phone',
                  keyboardType: TextInputType.phone,
                  errorText: _errorFor(state, 'phone'),
                  onChanged: () => _syncFields(context),
                ),
                _genderField(context, state),
                _dateOfBirthField(context, state),
                _field(
                  controller: _city,
                  label: 'City',
                  fieldKey: 'student-city',
                  errorText: _errorFor(state, ProfileFields.city),
                  onChanged: () => _syncFields(context),
                ),
                _field(
                  controller: _height,
                  label: 'Height (cm)',
                  fieldKey: 'student-height',
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  errorText: _errorFor(state, ProfileFields.heightCm),
                  onChanged: () => _syncFields(context),
                ),
                _photoField(context, state, photo),
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey<String>('student-register-submit'),
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

  Widget _genderField(BuildContext context, RegistrationState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<Gender>(
        key: const ValueKey<String>('student-gender'),
        initialValue: _gender,
        decoration: InputDecoration(
          labelText: 'Gender',
          border: const OutlineInputBorder(),
          errorText: _errorFor(state, ProfileFields.gender),
        ),
        items: const <DropdownMenuItem<Gender>>[
          DropdownMenuItem<Gender>(
            value: Gender.male,
            child: Text('Male'),
          ),
          DropdownMenuItem<Gender>(
            value: Gender.female,
            child: Text('Female'),
          ),
          DropdownMenuItem<Gender>(
            value: Gender.other,
            child: Text('Other'),
          ),
        ],
        onChanged: (Gender? value) {
          setState(() => _gender = value);
          _syncFields(context);
        },
      ),
    );
  }

  Widget _dateOfBirthField(BuildContext context, RegistrationState state) {
    final String value = _dateOfBirth == null
        ? 'Choose a date'
        : '${_dateOfBirth!.year}-'
            '${_dateOfBirth!.month.toString().padLeft(2, '0')}-'
            '${_dateOfBirth!.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date of birth',
          border: const OutlineInputBorder(),
          errorText: _errorFor(state, ProfileFields.dateOfBirth),
        ),
        child: InkWell(
          key: const ValueKey<String>('student-dob'),
          onTap: () => _pickDateOfBirth(context),
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

  Widget _photoField(
    BuildContext context,
    RegistrationState state,
    PhotoUpload? photo,
  ) {
    final String? error = _errorFor(state, ProfileFields.profilePhoto);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Profile photo',
          border: const OutlineInputBorder(),
          errorText: error,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                photo == null ? 'No photo selected' : photo.fileName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              key: const ValueKey<String>('student-pick-photo'),
              onPressed: () => _pickPhoto(context),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(photo == null ? 'Pick photo' : 'Change'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String fieldKey,
    required VoidCallback onChanged,
    String? errorText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: ValueKey<String>(fieldKey),
        controller: controller,
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
