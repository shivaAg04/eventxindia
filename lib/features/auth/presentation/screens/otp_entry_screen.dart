import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';

/// The OTP verification screen where the user enters the code delivered to
/// their phone (R1.2, R1.3, R2.3).
///
/// The screen reads its [AuthBloc] from the surrounding [BlocProvider] and
/// dispatches [OtpSubmitted] with the entered code. While the code is being
/// verified ([Verifying]) the form is disabled. An invalid/expired code
/// surfaces as an [AuthFailure] inline and via a snackbar; a [PhoneLocked]
/// lockout pops back to the phone-entry screen so the user can retry later.
/// On [Authenticated] the screen pops, letting the router route by role.
class OtpEntryScreen extends StatefulWidget {
  const OtpEntryScreen({super.key});

  @override
  State<OtpEntryScreen> createState() => _OtpEntryScreenState();
}

class _OtpEntryScreenState extends State<OtpEntryScreen> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    context.read<AuthBloc>().add(OtpSubmitted(_code.text.trim()));
  }

  String? _codeError(AuthState state) {
    if (state is AuthFailure) {
      return state.message;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (_, AuthState state) =>
            state is Authenticated ||
            state is PhoneLocked ||
            state is AuthFailure,
        listener: (BuildContext context, AuthState state) {
          final NavigatorState navigator = Navigator.of(context);
          final ScaffoldMessengerState messenger =
              ScaffoldMessenger.of(context);
          if (state is Authenticated) {
            navigator.pop();
          } else if (state is PhoneLocked) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message)));
            navigator.pop();
          } else if (state is AuthFailure) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (BuildContext context, AuthState state) {
          final bool busy = state is Verifying;
          return AbsorbPointer(
            absorbing: busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                const Text(
                  'Enter the code sent to your phone.',
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const ValueKey<String>('otp-entry-code'),
                  controller: _code,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: 'OTP code',
                    border: const OutlineInputBorder(),
                    errorText: _codeError(state),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey<String>('otp-entry-submit'),
                  onPressed: busy ? null : () => _submit(context),
                  child: busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
