import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/event_status.dart';
import '../../domain/entities/event.dart';
import '../../domain/repositories/event_repository.dart';
import '../datasources/firestore_event_data_source.dart';
import '../dtos/event_dto.dart';

/// Firestore implementation of [EventRepository].
///
/// Translates pure domain [Event] values to/from Firestore documents via
/// [EventDto] and routes every operation through [FirestoreEventDataSource]
/// (the `events` collection, R7.6). All writes (create, status change, code
/// set) run under the [withRetry] policy with [kDefaultMaxWriteAttempts] (3)
/// attempts so that a transient failure is retried and a total failure commits
/// no partial data (R14.6). Reads/queries map snapshots to domain entities;
/// stream queries return only the matching subset (active events for
/// discovery, R8.1; a vendor's own events, R5.2).
///
/// This is the only events-layer place that knows about Firebase. Swapping in a
/// REST backend means writing a sibling implementation and changing one DI
/// binding — domain and presentation are untouched.
@LazySingleton(as: EventRepository)
class FirestoreEventRepositoryImpl implements EventRepository {
  /// Creates the repository over the given [dataSource].
  const FirestoreEventRepositoryImpl(this._dataSource);

  final FirestoreEventDataSource _dataSource;

  @override
  Future<Result<Event, Failure>> create(Event event) {
    final EventDto dto = EventDto.fromEntity(event);
    return withRetry<Event>(
      kDefaultMaxWriteAttempts,
      () async {
        await _dataSource.create(event.eventId, dto.toFirestore());
        return event;
      },
    );
  }

  @override
  Stream<List<Event>> watchActive() {
    return _dataSource.watchActive().map(
          (snapshot) => snapshot.docs
              .map((doc) => EventDto.fromFirestore(doc).toEntity())
              .toList(),
        );
  }

  @override
  Stream<List<Event>> watchByVendor(String vendorId) {
    return _dataSource.watchByVendor(vendorId).map(
          (snapshot) => snapshot.docs
              .map((doc) => EventDto.fromFirestore(doc).toEntity())
              .toList(),
        );
  }

  @override
  Future<Result<Event, Failure>> getById(String eventId) async {
    try {
      final doc = await _dataSource.getById(eventId);
      if (!doc.exists) {
        return const Result<Event, Failure>.err(NotFoundFailure());
      }
      return Result<Event, Failure>.ok(EventDto.fromFirestore(doc).toEntity());
    } catch (_) {
      return const Result<Event, Failure>.err(PersistenceFailure());
    }
  }

  @override
  Future<Result<Event, Failure>> updateStatus(
    String eventId,
    EventStatus status,
  ) {
    return withRetry<Event>(
      kDefaultMaxWriteAttempts,
      () async {
        await _dataSource.update(eventId, <String, dynamic>{
          'status': status.wireName,
          'updatedAt': _now(),
        });
        return _requireEvent(eventId);
      },
    );
  }

  @override
  Future<Result<Event, Failure>> setCode(
    String eventId,
    EventCodeKind kind,
    String code,
  ) {
    final String field =
        kind == EventCodeKind.start ? 'startCode' : 'endCode';
    return withRetry<Event>(
      kDefaultMaxWriteAttempts,
      () async {
        await _dataSource.update(eventId, <String, dynamic>{
          field: code,
          'updatedAt': _now(),
        });
        return _requireEvent(eventId);
      },
    );
  }

  @override
  Future<Result<Event, Failure>> setApprovedCount(
    String eventId,
    int approvedCount,
  ) {
    return withRetry<Event>(
      kDefaultMaxWriteAttempts,
      () async {
        await _dataSource.update(eventId, <String, dynamic>{
          'approvedCount': approvedCount,
          'updatedAt': _now(),
        });
        return _requireEvent(eventId);
      },
    );
  }

  /// Reads back the persisted event after a write so the caller receives the
  /// up-to-date entity. Throws when the document is missing so the surrounding
  /// [withRetry] maps it to a [PersistenceFailure].
  Future<Event> _requireEvent(String eventId) async {
    final doc = await _dataSource.getById(eventId);
    if (!doc.exists) {
      throw StateError('Event $eventId not found after write');
    }
    return EventDto.fromFirestore(doc).toEntity();
  }

  static Timestamp _now() => Timestamp.fromDate(DateTime.now().toUtc());
}
