import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart' as core;
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/otp_session.dart';
import '../../domain/entities/session_state.dart' as domain;
import '../../domain/entities/user_role.dart';
import '../../domain/usecases/request_otp.dart';
import '../../domain/usecases/verify_otp.dart';
import '../../domain/usecases/watch_session.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Presentation-layer state machine for the authentication flow
/// (R1.1–R1.4, R2.1, R2.3, R2.4, R3.4).
///
/// [AuthBloc] translates UI intent ([AuthEvent]s) into calls on the auth use
/// cases and emits [AuthState]s the auth screens render. Per the architecture's
/// dependency rule it depends *only* on use cases ([RequestOtp], [VerifyOtp],
/// [WatchSession]) injected via the constructor — never on a repository or any
/// Firebase type.
///
/// Event → state mapping:
/// * [OtpRequested] → `[OtpSending, OtpSent]` on success, or
///   `[OtpSending, PhoneLocked]` / `[OtpSending, AuthFailure]` on rejection.
/// * [OtpSubmitted] → `[Verifying, Authenticated]` on success, or
///   `[Verifying, PhoneLocked]` / `[Verifying, AuthFailure]` on rejection.
/// * [SessionWatchStarted] → subscribes to the session stream and emits
///   [Authenticated] / [AuthInitial] as the signed-in state changes (R3.4).
/// * [SignedOut] → resets the in-flight challenge and returns to [AuthInitial].
@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(
    this._requestOtp,
    this._verifyOtp,
    this._watchSession,
  ) : super(const AuthInitial()) {
    on<OtpRequested>(_onOtpRequested);
    on<OtpSubmitted>(_onOtpSubmitted);
    on<SessionWatchStarted>(_onSessionWatchStarted);
    on<SignedOut>(_onSignedOut);
  }

  final RequestOtp _requestOtp;
  final VerifyOtp _verifyOtp;
  final WatchSession _watchSession;

  /// The pending OTP challenge produced by the most recent [OtpRequested],
  /// needed to verify a subsequently submitted code.
  OtpSession? _pendingSession;

  /// The role chosen for the in-flight login, carried so [VerifyOtp] can apply
  /// the role-specific attempt/lockout policy.
  UserRole? _pendingRole;

  Future<void> _onOtpRequested(
    OtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const OtpSending());

    final result = await _requestOtp(
      rawPhone: event.rawPhone,
      role: event.role,
    );

    result.fold(
      (OtpSession session) {
        _pendingSession = session;
        _pendingRole = event.role;
        emit(OtpSent(session));
      },
      (core.Failure failure) => _emitFailure(failure, emit),
    );
  }

  Future<void> _onOtpSubmitted(
    OtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final OtpSession? session = _pendingSession;
    final UserRole? role = _pendingRole;

    if (session == null || role == null) {
      emit(
        const AuthFailure(
          'No OTP request in progress. Please request an OTP first.',
        ),
      );
      return;
    }

    emit(const Verifying());

    final result = await _verifyOtp(
      session: session,
      code: event.code,
      role: role,
    );

    result.fold(
      (AuthUser user) => emit(Authenticated(user.role)),
      (core.Failure failure) => _emitFailure(failure, emit),
    );
  }

  Future<void> _onSessionWatchStarted(
    SessionWatchStarted event,
    Emitter<AuthState> emit,
  ) async {
    await emit.forEach<domain.SessionState>(
      _watchSession(),
      onData: (domain.SessionState sessionState) => switch (sessionState) {
        domain.Authenticated(:final UserRole role) => Authenticated(role),
        domain.AuthenticatedNoRole() => const AuthInitial(),
        domain.Unauthenticated() => const AuthInitial(),
      },
    );
  }

  void _onSignedOut(SignedOut event, Emitter<AuthState> emit) {
    _pendingSession = null;
    _pendingRole = null;
    emit(const AuthInitial());
  }

  /// Maps a use-case [failure] to the appropriate terminal state.
  ///
  /// A lockout surfaces as [PhoneLocked]; every other authentication failure
  /// surfaces as [AuthFailure] carrying the human-readable message. The domain
  /// [core.AuthFailure] does not expose a structured unlock time, so
  /// [PhoneLocked.until] is left `null` and the message conveys the detail.
  void _emitFailure(core.Failure failure, Emitter<AuthState> emit) {
    if (failure is core.AuthFailure &&
        failure.message.toLowerCase().contains('locked')) {
      emit(PhoneLocked(message: failure.message));
      return;
    }
    emit(AuthFailure(failure.message));
  }
}
