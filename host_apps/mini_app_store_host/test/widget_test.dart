import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_store_host/main.dart';

void main() {
  testWidgets('shows the calculator in the mini-app catalog', (tester) async {
    await tester.pumpWidget(const MiniAppStoreHost());

    expect(find.text('Mini App Store'), findsOneWidget);
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Offline math, memory and saved history'), findsOneWidget);
  });
}
