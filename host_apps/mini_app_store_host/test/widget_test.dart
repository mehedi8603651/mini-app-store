import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_store_host/main.dart';

void main() {
  testWidgets('shows available mini-programs in the catalog', (tester) async {
    await tester.pumpWidget(const MiniAppStoreHost());

    expect(find.text('Mini App Store'), findsOneWidget);
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Offline math, memory and saved history'), findsOneWidget);
    expect(find.text('Brain Test'), findsOneWidget);
    expect(
      find.text('Timed true-or-false arithmetic challenges'),
      findsOneWidget,
    );
    expect(find.text('Notepad'), findsOneWidget);
    expect(
      find.text('Private offline notes saved on this device'),
      findsOneWidget,
    );
    expect(find.text('Bangladesh Weather'), findsOneWidget);
    expect(
      find.text('Bangladesh locations and 7-day global forecasts'),
      findsOneWidget,
    );
  });
}
