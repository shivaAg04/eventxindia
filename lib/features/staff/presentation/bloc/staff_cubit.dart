import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/staff_member.dart';
import '../../domain/usecases/add_staff.dart';
import '../../domain/usecases/remove_staff.dart';
import '../../domain/usecases/watch_vendor_staff.dart';

part 'staff_state.dart';

/// Drives the vendor's staff-management screen: watches the roster and exposes
/// add/remove actions.
@injectable
class StaffCubit extends Cubit<StaffState> {
  StaffCubit(this._watchVendorStaff, this._addStaff, this._removeStaff)
      : super(const StaffLoading());

  final WatchVendorStaff _watchVendorStaff;
  final AddStaff _addStaff;
  final RemoveStaff _removeStaff;

  String? _vendorId;
  StreamSubscription<List<StaffMember>>? _sub;

  /// Starts watching [vendorId]'s staff roster.
  void watch(String vendorId) {
    _vendorId = vendorId;
    emit(const StaffLoading());
    _sub?.cancel();
    _sub = _watchVendorStaff(vendorId).listen(
      (List<StaffMember> staff) => emit(StaffLoaded(staff)),
      onError: (Object error, StackTrace _) =>
          emit(StaffFailure(error.toString())),
    );
  }

  /// Adds a staff member; returns the result so the form can report field
  /// errors or a duplicate.
  Future<Result<StaffMember, Failure>> add(StaffInput input) {
    return _addStaff(vendorId: _vendorId!, input: input);
  }

  /// Removes the staff member identified by [staffId].
  Future<Result<Unit, Failure>> remove(String staffId) =>
      _removeStaff(staffId);

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
