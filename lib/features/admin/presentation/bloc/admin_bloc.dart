import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../events/domain/entities/event.dart';
import '../../../profile/domain/entities/student.dart';
import '../../../profile/domain/entities/vendor.dart';
import '../../domain/entities/metrics.dart';
import '../../domain/usecases/approve_vendor.dart';
import '../../domain/usecases/get_metrics.dart';
import '../../domain/usecases/list_events.dart';
import '../../domain/usecases/list_students.dart';
import '../../domain/usecases/list_vendors.dart';
import '../../domain/usecases/reject_vendor.dart';
import 'admin_event.dart';
import 'admin_state.dart';

/// Presentation-layer state machine for the Admin dashboard (R6).
///
/// [AdminBloc] translates admin UI intent ([AdminEvent]s) into calls on the
/// admin use cases and emits [AdminState]s the admin screens render. Per the
/// architecture's dependency rule it depends *only* on use cases ([ApproveVendor],
/// [RejectVendor], [ListStudents], [ListVendors], [ListEvents], [GetMetrics])
/// injected via the constructor — never on a repository or any backend type.
///
/// Event → state mapping (design BLoC table):
/// * [VendorApproveRequested] → approves a vendor (R6.1); on rejection of a
///   non-`Pending` vendor emits [AdminActionFailure] (R6.3). The watched vendor
///   stream re-emits the updated status, so no success state is emitted here.
/// * [VendorRejectRequested] → rejects a vendor (R6.2); same failure handling
///   (R6.3).
/// * [ListsWatchStarted] → subscribes to the students/vendors/events streams
///   and emits [ListsLoaded] once all three have produced a value (R6.4–R6.6),
///   or [EmptyState] when every list is empty (R6.9).
/// * [MetricsWatchStarted] → subscribes to the metrics stream and emits
///   [MetricsLoaded] for every aggregated value (R6.7).
///
/// A bloc instance serves a single admin screen: the approval/lists screen
/// dispatches [ListsWatchStarted] while the metrics screen dispatches
/// [MetricsWatchStarted], so the single-state model never has to multiplex
/// list and metric projections.
@injectable
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  AdminBloc(
    this._approveVendor,
    this._rejectVendor,
    this._listStudents,
    this._listVendors,
    this._listEvents,
    this._getMetrics,
  ) : super(const AdminInitial()) {
    on<VendorApproveRequested>(_onVendorApproveRequested);
    on<VendorRejectRequested>(_onVendorRejectRequested);
    on<ListsWatchStarted>(_onListsWatchStarted);
    on<MetricsWatchStarted>(_onMetricsWatchStarted);
    on<StudentsUpdated>(_onStudentsUpdated);
    on<VendorsUpdated>(_onVendorsUpdated);
    on<EventsUpdated>(_onEventsUpdated);
    on<ListsErrored>(_onListsErrored);
    on<MetricsUpdated>(_onMetricsUpdated);
    on<MetricsErrored>(_onMetricsErrored);
  }

  final ApproveVendor _approveVendor;
  final RejectVendor _rejectVendor;
  final ListStudents _listStudents;
  final ListVendors _listVendors;
  final ListEvents _listEvents;
  final GetMetrics _getMetrics;

  StreamSubscription<List<Student>>? _studentsSub;
  StreamSubscription<List<Vendor>>? _vendorsSub;
  StreamSubscription<List<Event>>? _eventsSub;
  StreamSubscription<Metrics>? _metricsSub;

  // Latest snapshot of each list; `null` until the stream emits its first
  // value, so the combined [ListsLoaded] is held back until all three arrive.
  List<Student>? _students;
  List<Vendor>? _vendors;
  List<Event>? _events;

  Future<void> _onVendorApproveRequested(
    VendorApproveRequested event,
    Emitter<AdminState> emit,
  ) async {
    final result = await _approveVendor(event.vendorId);
    result.fold(
      (_) {}, // Success is reflected by the watched vendor stream (R6.5).
      (failure) => emit(AdminActionFailure(failure.message)),
    );
  }

  Future<void> _onVendorRejectRequested(
    VendorRejectRequested event,
    Emitter<AdminState> emit,
  ) async {
    final result = await _rejectVendor(event.vendorId);
    result.fold(
      (_) {}, // Success is reflected by the watched vendor stream (R6.5).
      (failure) => emit(AdminActionFailure(failure.message)),
    );
  }

  Future<void> _onListsWatchStarted(
    ListsWatchStarted event,
    Emitter<AdminState> emit,
  ) async {
    await _studentsSub?.cancel();
    await _vendorsSub?.cancel();
    await _eventsSub?.cancel();
    _students = null;
    _vendors = null;
    _events = null;

    _studentsSub = _listStudents().listen(
      (students) => add(StudentsUpdated(students)),
      onError: (Object error) => add(ListsErrored(error.toString())),
    );
    _vendorsSub = _listVendors().listen(
      (vendors) => add(VendorsUpdated(vendors)),
      onError: (Object error) => add(ListsErrored(error.toString())),
    );
    _eventsSub = _listEvents().listen(
      (events) => add(EventsUpdated(events)),
      onError: (Object error) => add(ListsErrored(error.toString())),
    );
  }

  Future<void> _onMetricsWatchStarted(
    MetricsWatchStarted event,
    Emitter<AdminState> emit,
  ) async {
    await _metricsSub?.cancel();
    _metricsSub = _getMetrics().listen(
      (metrics) => add(MetricsUpdated(metrics)),
      onError: (Object error) => add(MetricsErrored(error.toString())),
    );
  }

  void _onStudentsUpdated(StudentsUpdated event, Emitter<AdminState> emit) {
    _students = event.students;
    _emitListsIfReady(emit);
  }

  void _onVendorsUpdated(VendorsUpdated event, Emitter<AdminState> emit) {
    _vendors = event.vendors;
    _emitListsIfReady(emit);
  }

  void _onEventsUpdated(EventsUpdated event, Emitter<AdminState> emit) {
    _events = event.events;
    _emitListsIfReady(emit);
  }

  void _onListsErrored(ListsErrored event, Emitter<AdminState> emit) {
    emit(AdminActionFailure(event.message));
  }

  void _onMetricsUpdated(MetricsUpdated event, Emitter<AdminState> emit) {
    emit(MetricsLoaded(event.metrics));
  }

  void _onMetricsErrored(MetricsErrored event, Emitter<AdminState> emit) {
    emit(AdminActionFailure(event.message));
  }

  /// Emits the combined lists state once every list stream has produced a
  /// value: [EmptyState] when all are empty (R6.9), otherwise [ListsLoaded]
  /// (R6.4–R6.6).
  void _emitListsIfReady(Emitter<AdminState> emit) {
    final students = _students;
    final vendors = _vendors;
    final events = _events;
    if (students == null || vendors == null || events == null) {
      return;
    }
    if (students.isEmpty && vendors.isEmpty && events.isEmpty) {
      emit(const EmptyState());
      return;
    }
    emit(ListsLoaded(students: students, vendors: vendors, events: events));
  }

  @override
  Future<void> close() async {
    await _studentsSub?.cancel();
    await _vendorsSub?.cancel();
    await _eventsSub?.cancel();
    await _metricsSub?.cancel();
    return super.close();
  }
}
