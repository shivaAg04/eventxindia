import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/value_objects/application_status.dart';
import '../../domain/entities/application.dart';
import '../dtos/application_dto.dart';

/// Converts between the Firebase [ApplicationDto] and the pure domain
/// [Application] entity.
///
/// This is the boundary where Firebase types (`Timestamp`) become pure Dart
/// values (`DateTime`) and where the wire status string becomes the typed
/// [ApplicationStatus] value object. Domain code never sees a `Timestamp` or a
/// raw status string.
extension ApplicationDtoX on ApplicationDto {
  /// Maps this DTO to a pure domain [Application].
  ///
  /// Converts `Timestamp` -> `DateTime` and parses the status string into an
  /// [ApplicationStatus], rejecting any unknown value at the boundary.
  Application toEntity() => Application(
        applicationId: applicationId,
        eventId: eventId,
        studentId: studentId,
        status: ApplicationStatusX.parse(status),
        applicantName: applicantName,
        applicantPhone: applicantPhone,
        applicantCity: applicantCity,
        eventTitle: eventTitle,
        eventLocation: eventLocation,
        eventPayMinorUnits: eventPayMinorUnits,
        eventCommissionPercent: eventCommissionPercent,
        eventDate: eventDate?.toDate(),
        createdAt: createdAt.toDate(),
        updatedAt: updatedAt.toDate(),
      );
}

/// Maps domain [Application] entities to Firebase [ApplicationDto]s.
extension ApplicationEntityX on Application {
  /// Maps this pure domain entity to a Firebase [ApplicationDto].
  ///
  /// Converts `DateTime` -> `Timestamp` and the typed [ApplicationStatus] back
  /// to its canonical wire string.
  ApplicationDto toDto() => ApplicationDto(
        applicationId: applicationId,
        eventId: eventId,
        studentId: studentId,
        status: status.wireName,
        applicantName: applicantName,
        applicantPhone: applicantPhone,
        applicantCity: applicantCity,
        eventTitle: eventTitle,
        eventLocation: eventLocation,
        eventPayMinorUnits: eventPayMinorUnits,
        eventCommissionPercent: eventCommissionPercent,
        eventDate:
            eventDate == null ? null : Timestamp.fromDate(eventDate!),
        createdAt: Timestamp.fromDate(createdAt),
        updatedAt: Timestamp.fromDate(updatedAt),
      );
}
