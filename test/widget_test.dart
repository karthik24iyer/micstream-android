// MicStream Phase 1 Widget Test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:micstream_android/main.dart';

void main() {
  testWidgets('MicStream app loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MicStreamApp());

    // Verify that the app title is displayed
    expect(find.text('MicStream'), findsOneWidget);

    // Verify that the connect button is present
    expect(find.text('CONNECT'), findsOneWidget);
  });
}
