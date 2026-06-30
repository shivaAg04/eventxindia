import 'dart:async';

import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/core/value_objects/event_status.dart';
import 'package:eventxindia/features/applications/domain/entities/application.dart';
import 'package:eventxindia/features/applications/domain/repositories/application_repository.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/events/domain/repositories/event_repository.dart';
import 'package:eventxindia/features/profile/domain/entities/student.dart';
import 'package:eventxindia/features/profile/domain/entities/vendor.dart';
import 'package:eventxindia/features/profile/domain/repositories/profile_repository.dart';

/// An in-memory [EventRepository] fake for use-case tests.
class FakeEventRepository implements EventRepository {
  final Map<String, Event> _events = <String, Event>{};

  /// Seeds the repository with [event], keyed by its id.
  void seed(Event event) => _events[event.eventId] = event;

  @override
  Future<Result<Event, Failure>> getById(String eventId) async {
    final Event? event = _events[eventId];
    if (event == null) {
      return const Result<Event, Failure>.err(NotFoundFailure());
    }
    return Result<Event, Failure>.ok(event);
  }

  @override
  Future<Result<Event, Failure>> create(Event event) async {
    _events[event.eventId] = event;
    return Result<Event, Failure>.ok(event);
  }

  @override
  Stream<List<Event>> watchActive() =>
      Stream<List<Event>>.value(_events.values
          .where((Event e) => e.status == EventStatus.active)
          .toList());

  @override
  Stream<List<Event>> watchByVendor(String vendorId) =>
      Stream<List<Event>>.value(_events.values
          .where((Event e) => e.vendorId == vendorId)
          .toList());

  @override
  Future<Result<Event, Failure>> updateStatus(
    String eventId,
    EventStatus status,
  ) async {
    final Event? event = _events[eventId];
    if (event == null) {
      return const Result<Event, Failure>.err(NotFoundFailure());
    }
    final Event updated = event.copyWith(status: status);
    _events[eventId] = updated;
    return Result<Event, Failure>.ok(updated);
  }

  @override
  Future<Result<Event, Failure>> setCode(
    String eventId,
    EventCodeKind kind,
    String code,
  ) async {
    final Event? event = _events[eventId];
    if (event == null) {
      return const Result<Event, Failure>.err(NotFoundFailure());
    }
    final Event updated = switch (kind) {
      EventCodeKind.start => event.copyWith(startCode: code),
      EventCodeKind.end => event.copyWith(endCode: code),
    };
    _events[eventId] = updated;
    return Result<Event, Failure>.ok(updated);
  }

  @override
  Future<Result<Event, Failure>> setApprovedCount(
    String eventId,
    int approvedCount,
  ) async {
    final Event? event = _events[eventId];
    if (event == null) {
      return const Result<Event, Failure>.err(NotFoundFailure());
    }
    final Event updated = event.copyWith(approvedCount: approvedCount);
    _events[eventId] = updated;
    return Result<Event, Failure>.ok(updated);
  }
}

/// An in-memory [ApplicationRepository] fake for use-case tests.
class FakeApplicationRepository implements ApplicationRepository {
  final Map<String, Application> _applications = <String, Application>{};

  /// Applications passed to [create], in call order.
  final List<Application> created = <Application>[];

  /// Applications passed to [decide], in call order.
  final List<Application> decided = <Application>[];

  /// When set, [create] returns this failure instead of persisting.
  Failure? createFailure;

  /// When set, [decide] returns this failure instead of persisting.
  Failure? decideFailure;

  /// Seeds the repository with [application], keyed by its composite id.
  void seed(Application application) =>
      _applications[application.applicationId] = application;

  @override
  Future<Result<Application, Failure>> create(Application application) async {
    if (createFailure != null) {
      return Result<Application, Failure>.err(createFailure!);
    }
    created.add(application);
    _applications[application.applicationId] = application;
    return Result<Application, Failure>.ok(application);
  }

  @override
  Future<Result<Application, Failure>> decide(Application application) async {
    if (decideFailure != null) {
      return Result<Application, Failure>.err(decideFailure!);
    }
    decided.add(application);
    _applications[application.applicationId] = application;
    return Result<Application, Failure>.ok(application);
  }

  @override
  Future<Result<Application, Failure>> getById(String applicationId) async {
    final Application? application = _applications[applicationId];
    if (application == null) {
      return const Result<Application, Failure>.err(NotFoundFailure());
    }
    return Result<Application, Failure>.ok(application);
  }

  @override
  Stream<List<Application>> watchByEvent(String eventId) =>
      Stream<List<Application>>.value(_applications.values
          .where((Application a) => a.eventId == eventId)
          .toList());

  @override
  Stream<List<Application>> watchByStudent(String studentId) =>
      Stream<List<Application>>.value(_applications.values
          .where((Application a) => a.studentId == studentId)
          .toList());
}

/// An in-memory [ProfileRepository] fake for use-case tests.
///
/// Only the [getStudent] read is exercised by the application use cases (for the
/// apply-time profile snapshot); unseeded students return a [NotFoundFailure]
/// so the snapshot is simply omitted.
class FakeProfileRepository implements ProfileRepository {
  final Map<String, Student> _students = <String, Student>{};

  /// Seeds the repository with [student], keyed by uid.
  void seedStudent(Student student) => _students[student.uid] = student;

  @override
  Future<Result<Student, Failure>> getStudent(String uid) async {
    final Student? student = _students[uid];
    return student == null
        ? const Result<Student, Failure>.err(NotFoundFailure())
        : Result<Student, Failure>.ok(student);
  }

  @override
  Future<Result<Student, Failure>> createStudent(Student student) async {
    _students[student.uid] = student;
    return Result<Student, Failure>.ok(student);
  }

  @override
  Future<Result<Vendor, Failure>> getVendor(String uid) async =>
      const Result<Vendor, Failure>.err(NotFoundFailure());

  @override
  Future<Result<Vendor, Failure>> createVendor(Vendor vendor) async =>
      Result<Vendor, Failure>.ok(vendor);
}
