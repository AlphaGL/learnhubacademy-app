// Minimal smoke test placeholder. Replace with real widget tests as the app
// grows. Kept here so `flutter create` does not generate the default test that
// references a non-existent `MyApp`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a MaterialApp', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('LearnHub'))),
    );
    expect(find.text('LearnHub'), findsOneWidget);
  });
}
