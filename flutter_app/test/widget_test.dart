import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_lottery_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await dotenv.load(fileName: '.env');
    await tester.pumpWidget(const ProviderScope(child: SmartLotteryApp()));
    expect(find.byType(SmartLotteryApp), findsOneWidget);
  });
}
