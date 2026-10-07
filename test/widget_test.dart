// Replaces the counter-app test that `flutter create` generates.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natyakosha/shared/widgets/common_widgets.dart';

void main() {
  testWidgets('StatusChip shows its label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StatusChip(label: 'Paid', color: Colors.green)),
      ),
    );
    expect(find.text('Paid'), findsOneWidget);
  });

  testWidgets('EmptyState shows title, message and action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox,
            title: 'No events yet',
            message: 'Performances will show here.',
            action: TextButton(onPressed: () => tapped = true, child: const Text('Refresh')),
          ),
        ),
      ),
    );
    expect(find.text('No events yet'), findsOneWidget);
    expect(find.text('Performances will show here.'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    expect(tapped, isTrue);
  });
}
