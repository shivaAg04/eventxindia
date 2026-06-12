import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/application.dart';
import '../../domain/repositories/application_repository.dart';
import '../datasources/firestore_application_data_source.dart';
import '../dtos/application_dto.dart';
import '../mappers/application_mapper.dart';

/// Firestore-backed implementation of [ApplicationRepository].
///
/// Persists applications under the composite document id
/// `"{eventId}_{studentId}"` (R9.6) and wraps every write in the pure
/// [withRetry] policy (3 attempts, no partial commit on total failure — R14.6).
/// All Firebase access is delegated to [FirestoreApplicationDataSource]; this
/// class only converts between domain entities and DTOs and maps errors onto
/// the [Failure] hierarchy.
@LazySingleton(as: ApplicationRepository)
class FirestoreApplicationRepositoryImpl implements ApplicationRepository {
  const FirestoreApplicationRepositoryImpl(this._dataSource);

  final FirestoreApplicationDataSource _dataSource;

  @override
  Future<Result<Application, Failure>> create(Application application) async {
    final Result<void, Failure> result = await withRetry<void>(
      kDefaultMaxWriteAttempts,
      () => _dataSource.createIfAbsent(application.toDto()),
      onFailure: (Object error, StackTrace _) {
        // A duplicate is a deterministic business-rule violation (R9.2), not a
        // transient persistence error, so it must not be retried into success.
        if (error is ApplicationAlreadyExistsException) {
          return const StateTransitionFailure(
            message: 'You have already applied to this event.',
          );
        }
        return const PersistenceFailure();
      },
    );
    return result.map((_) => application);
  }

  @override
  Future<Result<Application, Failure>> decide(Application application) async {
    final Result<void, Failure> result = await withRetry<void>(
      kDefaultMaxWriteAttempts,
      () => _dataSource.update(application.toDto()),
    );
    return result.map((_) => application);
  }

  @override
  Future<Result<Application, Failure>> getById(String applicationId) async {
    try {
      final Application application =
          (await _dataSource.getById(applicationId)).toEntity();
      return Result<Application, Failure>.ok(application);
    } on ApplicationNotFoundException {
      return const Result<Application, Failure>.err(
        NotFoundFailure(message: 'The requested application was not found.'),
      );
    } catch (_) {
      return const Result<Application, Failure>.err(PersistenceFailure());
    }
  }

  @override
  Stream<List<Application>> watchByEvent(String eventId) {
    return _dataSource.watchByEvent(eventId).map(_toEntities);
  }

  @override
  Stream<List<Application>> watchByStudent(String studentId) {
    return _dataSource.watchByStudent(studentId).map(_toEntities);
  }

  List<Application> _toEntities(List<ApplicationDto> dtos) {
    return dtos
        .map((ApplicationDto dto) => dto.toEntity())
        .toList(growable: false);
  }
}
