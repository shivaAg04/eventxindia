import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/user_role.dart';
import '../bloc/auth_bloc.dart';
import 'otp_entry_screen.dart';

/// The login entry point where a user chooses a role and enters a phone number
/// to receive an OTP (R1.1, R1.5, R2.1, R2.2).
///
/// The screen reads its [AuthBloc] from the surrounding [BlocProvider] and
/// dispatches [OtpRequested] with the chosen [UserRole] and the raw phone text;
/// the bloc performs role-specific format validation downstream. While an OTP
/// is being sent ([OtpSending]) the form is disabled. On [OtpSent] the user is
/// routed to the [OtpEntryScreen]; an [AuthFailure] (e.g. an invalid phone) or
/// a [PhoneLocked] lockout is surfaced inline and via a snackbar.
class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final TextEditingController _phone = TextEditingController();
  UserRole _role = UserRole.student;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _requestOtp(BuildContext context) {
    context.read<AuthBloc>().add(
          OtpRequested(rawPhone: _phone.text.trim(), role: _role),
        );
  }

  /// Whether the current [state] should keep the form locked/disabled.
  bool _isBusy(AuthState state) => state is OtpSending || state is Verifying;

  /// The inline error message to show under the phone field, if any.
  String? _phoneError(AuthState state) {
    if (state is AuthFailure) {
      return state.message;
    }
    if (state is PhoneLocked) {
      return state.message;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (_, AuthState state) =>
            state is OtpSent ||
            state is PhoneLocked ||
            state is AuthFailure,
        listener: (BuildContext context, AuthState state) {
          final ScaffoldMessengerState messenger =
              ScaffoldMessenger.of(context);
          if (state is OtpSent) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider<AuthBloc>.value(
                  value: context.read<AuthBloc>(),
                  child: const OtpEntryScreen(),
                ),
              ),
            );
          } else if (state is PhoneLocked) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is AuthFailure) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (BuildContext context, AuthState state) {
          final bool busy = _isBusy(state);
          return AbsorbPointer(
            absorbing: busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                const Text('I am a'),
                const SizedBox(height: 8),
                SegmentedButton<UserRole>(
                  segments: const <ButtonSegment<UserRole>>[
                    ButtonSegment<UserRole>(
                      value: UserRole.student,
                      label: Text('Student'),
                    ),
                    ButtonSegment<UserRole>(
                      value: UserRole.vendor,
                      label: Text('Vendor'),
                    ),
                  ],
                  selected: <UserRole>{_role},
                  onSelectionChanged: busy
                      ? null
                      : (Set<UserRole> selection) {
                          setState(() => _role = selection.first);
                        },
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const ValueKey<String>('phone-entry-phone'),
                  controller: _phone,
                  enabled: !busy,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: _role == UserRole.vendor
                        ? 'Phone number (10 digits)'
                        : 'Phone number (with country code)',
                    hintText: _role == UserRole.vendor
                        ? '9876543210'
                        : '+919876543210',
                    border: const OutlineInputBorder(),
                    errorText: _phoneError(state),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey<String>('phone-entry-submit'),
                  onPressed:
                      busy ? null : () => _requestOtp(context),
                  child: state is OtpSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send OTP'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
