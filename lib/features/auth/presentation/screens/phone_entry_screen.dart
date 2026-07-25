import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
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
          return SafeArea(
            child: AbsorbPointer(
              absorbing: busy,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                children: <Widget>[
                  const _BrandHeader(),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: AppDecorations.glassCard(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'I am a',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<UserRole>(
                          segments: const <ButtonSegment<UserRole>>[
                            ButtonSegment<UserRole>(
                              value: UserRole.student,
                              icon: Icon(Icons.school_outlined),
                              label: Text('Student'),
                            ),
                            ButtonSegment<UserRole>(
                              value: UserRole.vendor,
                              icon: Icon(Icons.storefront_outlined),
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
                          maxLength: 10,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Mobile number',
                            hintText: '9876543210',
                            counterText: '',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            prefixText: '+91 ',
                            errorText: _phoneError(state),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const ValueKey<String>('phone-entry-submit'),
                          onPressed: busy ? null : () => _requestOtp(context),
                          child: state is OtpSending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Send OTP'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'We’ll text you a one-time code to verify your number.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The branded login header: a glowing logo mark above the app name rendered
/// in the signature brand gradient, with a short tagline.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          height: 76,
          width: 76,
          decoration: BoxDecoration(
            gradient: AppGradients.brand,
            borderRadius: BorderRadius.circular(22),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 32,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.bolt_rounded,
            size: 42,
            color: Color(0xFF0A0E1F),
          ),
        ),
        const SizedBox(height: 24),
        ShaderMask(
          shaderCallback: (Rect bounds) =>
              AppGradients.brand.createShader(bounds),
          child: Text(
            'EventX',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Staff events. Smarter.',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
