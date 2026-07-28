part of 'staff_cubit.dart';

/// State for the vendor staff-management screen.
sealed class StaffState extends Equatable {
  const StaffState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The roster is loading (before the first stream emission).
class StaffLoading extends StaffState {
  const StaffLoading();
}

/// The roster loaded — [staff] is the vendor's current staff list.
class StaffLoaded extends StaffState {
  const StaffLoaded(this.staff);

  final List<StaffMember> staff;

  @override
  List<Object?> get props => <Object?>[staff];
}

/// The roster stream errored.
class StaffFailure extends StaffState {
  const StaffFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
