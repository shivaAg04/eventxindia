import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';

/// An app-bar action that signs the current user out (R3.4).
///
/// Dispatches [SignedOut] to the ambient [AuthBloc] (provided above the
/// role-based router), which clears the backend session; `watchSession` then
/// emits Unauthenticated and the router returns to the authentication screen.
/// A confirmation dialog guards against accidental taps.
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey<String>('logout-button'),
      icon: const Icon(Icons.logout),
      tooltip: 'Log out',
      onPressed: () => _confirmAndSignOut(context),
    );
  }

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final AuthBloc authBloc = context.read<AuthBloc>();
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Log out?'),
            content: const Text('You will need to sign in again.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Log out'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      authBloc.add(const SignedOut());
    }
  }
}
