import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stadia/ui/phone_column.dart';

void main() {
  Future<Size> pumpAt(
    WidgetTester tester,
    Size window, {
    required bool enabled,
  }) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Size seen;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            PhoneColumn(enabled: enabled, child: child!),
        home: Builder(
          builder: (context) {
            seen = MediaQuery.sizeOf(context);
            return const Scaffold(body: SizedBox.expand(key: Key('page')));
          },
        ),
      ),
    );
    return seen;
  }

  testWidgets('a wide browser window gets a phone-width column', (
    tester,
  ) async {
    final seen = await pumpAt(tester, const Size(1440, 900), enabled: true);
    // Screens lay out against the column, not the window.
    expect(seen, const Size(PhoneColumn.width, 900));
    expect(
      tester.getSize(find.byKey(const Key('page'))).width,
      PhoneColumn.width,
    );
    expect(tester.getCenter(find.byKey(const Key('page'))).dx, 720);
  });

  testWidgets('a phone-sized window is left as is', (tester) async {
    final seen = await pumpAt(tester, const Size(390, 844), enabled: true);
    expect(seen, const Size(390, 844));
  });

  testWidgets('native apps fill the device', (tester) async {
    final seen = await pumpAt(tester, const Size(1440, 900), enabled: false);
    expect(seen, const Size(1440, 900));
  });
}
