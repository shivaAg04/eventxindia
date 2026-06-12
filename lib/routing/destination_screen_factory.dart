import 'package:flutter/material.dart';

import '../features/navigation/domain/entities/destination.dart';

/// Builds the screen widget that renders a given [Destination] (R3.1).
///
/// The router is intentionally decoupled from concrete feature screens: it only
/// knows how to map a resolved [Destination] to a widget through this typedef.
/// The composition root supplies the real implementation (wiring each
/// destination to its feature screen and BLoC); tests and early integration can
/// supply [defaultDestinationScreenFactory] below.
typedef DestinationScreenFactory = Widget Function(Destination destination);

/// A lightweight default [DestinationScreenFactory].
///
/// It renders a minimal placeholder scaffold for every [Destination] so the
/// role-based router compiles and runs before each feature screen is wired in.
/// Replace this in the composition root (task 31.2) with a factory that returns
/// the real feature screens. Keeping placeholders here means the router has no
/// hard dependency on screens that may not exist yet.
Widget defaultDestinationScreenFactory(Destination destination) {
  return _DestinationPlaceholder(destination: destination);
}

class _DestinationPlaceholder extends StatelessWidget {
  const _DestinationPlaceholder({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(destination.name)),
      body: Center(
        child: Text(
          destination.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
