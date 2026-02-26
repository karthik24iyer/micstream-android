// MicQ Phase 1 Widget Test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:micstream_android/main.dart';

void main() {
  testWidgets('MicQ app loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MicQApp());

    // Verify that the app title is displayed
    expect(find.text('MicQ'), findsOneWidget);

    // Verify that the connect button is present
    expect(find.text('CONNECT'), findsOneWidget);
  });
}
