import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';
import '../dtos/auth_throttle_dto.dart';

/// Thin Firebase-backed data source for authentication (R2.1, R14.1).
///
/// Wraps [fb.FirebaseAuth] phone verification and the Firestore documents the
/// auth flow reads/writes (`users/{uid}` for the role, `authThrottle/{phone}`
/// for application-level attempt/lockout state). It is the only auth class that
/// touches Firebase SDK types; the [AuthRepository] implementation built on top
/// converts everything to pure domain values.
///
/// The phone-OTP flow is modelled as a two-step exchange that matches the
/// domain's `OtpSession`:
/// * [requestOtp] kicks off `verifyPhoneNumber` and completes with the
///   backend-issued `verificationId` once the SMS is sent.
/// * [verifyOtp] exchanges that `verificationId` plus the user-entered
///   `smsCode` for a signed-in [fb.User] via `signInWithCredential`.
@injectable
class FirebaseAuthDataSource extends FirebaseAuthDataSourceBase {
  @factoryMethod
  FirebaseAuthDataSource.inject(
    fb.FirebaseAuth auth, {
    required FirebaseFirestore firestore,
  }) : this(auth, firestore: firestore);

  FirebaseAuthDataSource(
    super.auth, {
    required FirebaseFirestore firestore,
    Duration codeSentTimeout = const Duration(seconds: 60),
  })  : _firestore = firestore,
        _codeSentTimeout = codeSentTimeout;

  final FirebaseFirestore _firestore;

  /// How long to wait for the `codeSent` callback before giving up.
  final Duration _codeSentTimeout;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _throttle =>
      _firestore.collection('authThrottle');

  /// The currently signed-in Firebase user, or `null` when unauthenticated.
  fb.User? get currentUser => auth.currentUser;

  /// Streams Firebase authentication-state changes (signed in / out).
  Stream<fb.User?> authStateChanges() => auth.authStateChanges();

  /// Requests OTP delivery to [phoneNumber] (E.164) and returns the
  /// backend-issued `verificationId` once the SMS has been sent (R2.1).
  ///
  /// Throws an [fb.FirebaseAuthException] when verification fails (e.g. invalid
  /// number or quota exceeded), or a [TimeoutException] if no `codeSent`
  /// callback arrives within the configured timeout.
  Future<String> requestOtp(String phoneNumber) async {
    final Completer<String> completer = Completer<String>();

    await auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: _codeSentTimeout,
      verificationCompleted: (fb.PhoneAuthCredential credential) {
        // Android instant/auto-verification. The OtpSession model still
        // requires a verificationId for the explicit verify step, so we do not
        // auto-sign-in here; the user-entered code drives [verifyOtp].
      },
      verificationFailed: (fb.FirebaseAuthException error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      codeSent: (String verificationId, int? forceResendingToken) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // The auto-retrieval window elapsed; if codeSent already fired this is
        // a no-op. Otherwise surface the verificationId so verify can proceed.
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
    );

    return completer.future.timeout(
      _codeSentTimeout + const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException(
        'Timed out waiting for OTP code to be sent.',
        _codeSentTimeout,
      ),
    );
  }

  /// Exchanges [verificationId] and the user-entered [smsCode] for a signed-in
  /// [fb.User] (R1.2, R2.3).
  ///
  /// Throws an [fb.FirebaseAuthException] (e.g. `invalid-verification-code`)
  /// when the code does not match or has expired.
  Future<fb.User> verifyOtp(String verificationId, String smsCode) async {
    final fb.PhoneAuthCredential credential = fb.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final fb.UserCredential result =
        await auth.signInWithCredential(credential);
    final fb.User? user = result.user;
    if (user == null) {
      throw fb.FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user returned after credential sign-in.',
      );
    }
    return user;
  }

  /// Signs the current user out.
  Future<void> signOut() => auth.signOut();

  /// Reads the persisted `users/{uid}` document (role, phone, etc.).
  Future<DocumentSnapshot<Map<String, dynamic>>> readUserDoc(String uid) {
    return _users.doc(uid).get();
  }

  /// Streams the `users/{uid}` document so the session state reflects role
  /// changes (R3.3, R3.4).
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDoc(String uid) {
    return _users.doc(uid).snapshots();
  }

  /// Reads the application-level throttle record for [phone] (R1.4, R2.4,
  /// R2.5). A missing document yields a fresh, unlocked record.
  Future<AuthThrottleDto> readThrottle(String phone) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _throttle.doc(phone).get();
    return AuthThrottleDto.fromFirestore(snapshot, fallbackId: phone);
  }

  /// Persists the throttle record for `dto.phone` (R1.4, R2.4, R2.5).
  Future<void> writeThrottle(AuthThrottleDto dto) {
    return _throttle.doc(dto.phone).set(dto.toFirestore());
  }
}
