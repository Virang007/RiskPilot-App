import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/main.dart';
import 'package:my_app/repositories/stock_repository.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    final stockRepository = StockRepository();
    await tester.pumpWidget(MyApp(stockRepository: stockRepository));
    expect(find.byType(MyApp), findsOneWidget);
  });
}
