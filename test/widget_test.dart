// Basic smoke test for the EventXIndia app scaffold.
//
// Verifies the root widget builds and renders without errors. When DI has not
// been bootstrapped (as in this test), the app hosts the role-based router with
// its placeholder destination factory and lands on the authentication
// destination for an unauthenticated session.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eventxindia/main.dart';
import 'package:eventxindia/features/navigation/domain/entities/destination.dart';

void main() {
  testWidgets('App boots and renders the role-based router', (tester) async {
    await tester.pumpWidget(const EventXIndiaApp());
    await tester.pump();

    // The MaterialApp scaffold is present.
    expect(find.byType(MaterialApp), findsOneWidget);

    // For an unauthenticated session the router resolves to the authentication
    // destination, rendered here by the placeholder factory.
    expect(find.text(Destination.authentication.name), findsWidgets);
  });
}
