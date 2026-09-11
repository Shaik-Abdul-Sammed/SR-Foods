import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sr_foods/main.dart';


void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Just pump the widget once with a duration to clear any pending timers 
    // from the splash screen animations/delays, but avoiding pumpAndSettle 
    // which hangs on the infinite LinearProgressIndicator.
    await tester.pump(const Duration(seconds: 6));

    // Verify that the app has initialized and shows some expected UI
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
