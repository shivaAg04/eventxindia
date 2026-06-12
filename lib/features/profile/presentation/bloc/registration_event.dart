import 'package:equatable/equatable.dart';

import '../../domain/repositories/storage_repository.dart';
import 'registration_state.dart';

/// Intents the registration UI sends to the [RegistrationBloc].
sealed class RegistrationEvent extends Equatable {
  const RegistrationEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// The Student form fields changed.
///
/// Carries the full current [form] draft so the BLoC simply replaces its held
/// values, guaranteeing the entered values are retained verbatim (R1.7).
class StudentFieldsChanged extends RegistrationEvent {
  const StudentFieldsChanged(this.form);

  /// The latest Student form draft.
  final StudentFormData form;

  @override
  List<Object?> get props => <Object?>[form];
}

/// A profile photo was picked for the Student form.
class PhotoPicked extends RegistrationEvent {
  const PhotoPicked(this.photo);

  /// The chosen photo, or `null` to clear a previously chosen one.
  final PhotoUpload? photo;

  @override
  List<Object?> get props => <Object?>[photo];
}

/// The Student registration form was submitted.
///
/// [gender] and [dateOfBirth] are carried explicitly because they are selected
/// via pickers rather than free text; the remaining values come from the held
/// [StudentFormData] draft. [uid] is the authenticated user's id.
class StudentSubmitted extends RegistrationEvent {
  const StudentSubmitted({required this.uid});

  /// The authenticated user's id (the student's profile id).
  final String uid;

  @override
  List<Object?> get props => <Object?>[uid];
}

/// The Vendor form fields changed.
///
/// Carries the full current [form] draft so the BLoC simply replaces its held
/// values, guaranteeing the entered values are retained verbatim (R2.8).
class VendorFieldsChanged extends RegistrationEvent {
  const VendorFieldsChanged(this.form);

  /// The latest Vendor form draft.
  final VendorFormData form;

  @override
  List<Object?> get props => <Object?>[form];
}

/// The Vendor registration form was submitted.
///
/// [uid] is the authenticated user's id (the vendor's profile id).
class VendorSubmitted extends RegistrationEvent {
  const VendorSubmitted({required this.uid});

  /// The authenticated user's id (the vendor's profile id).
  final String uid;

  @override
  List<Object?> get props => <Object?>[uid];
}
