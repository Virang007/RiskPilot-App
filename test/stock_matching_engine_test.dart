import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/stock_model.dart';
import 'package:my_app/repositories/stock_matching_engine.dart';

void main() {
  group('StockMatchingEngine Advanced Tests', () {
    late StockMatchingEngine engine;
    late List<StockModel> mockStocks;

    setUp(() {
      engine = StockMatchingEngine();
      mockStocks = const [
        StockModel(
          securityId: '2885',
          symbol: 'RELIANCE',
          name: 'Reliance Industries Limited',
          lastPrice: 2980.0,
        ),
        StockModel(
          securityId: '11536',
          symbol: 'TCS',
          name: 'Tata Consultancy Services Limited',
          lastPrice: 4150.0,
        ),
        StockModel(
          securityId: '3045',
          symbol: 'SBIN',
          name: 'State Bank of India',
          lastPrice: 795.0,
        ),
        StockModel(
          securityId: '3456',
          symbol: 'TATAMOTORS',
          name: 'Tata Motors Limited',
          lastPrice: 950.0,
        ),
        StockModel(
          securityId: '3499',
          symbol: 'TATASTEEL',
          name: 'Tata Steel Limited',
          lastPrice: 155.0,
        ),
        StockModel(
          securityId: '3426',
          symbol: 'TATAPOWER',
          name: 'Tata Power Company Limited',
          lastPrice: 420.0,
        ),
        StockModel(
          securityId: '3405',
          symbol: 'TATACHEM',
          name: 'Tata Chemicals Limited',
          lastPrice: 1080.0,
        ),
      ];
    });

    test('TATA MORTE fuzzy matches TATAMOTORS and does NOT return all other Tata shares', () {
      final rawLines = [
        'TATA MORTE',
      ];

      final result = engine.matchStocks(
        rawLines: rawLines,
        allStocks: mockStocks,
      );

      expect(result.matchedStocks.isNotEmpty, isTrue);
      // The top and only matched stock should be TATAMOTORS
      expect(result.matchedStocks.first.symbol, equals('TATAMOTORS'));

      // Ensure other Tata stocks are NOT returned
      expect(result.matchedStocks.any((s) => s.symbol == 'TATASTEEL'), isFalse);
      expect(result.matchedStocks.any((s) => s.symbol == 'TATAPOWER'), isFalse);
      expect(result.matchedStocks.any((s) => s.symbol == 'TATACHEM'), isFalse);
      expect(result.matchedStocks.any((s) => s.symbol == 'TCS'), isFalse);
    });

    test('TATA MOTORS matches TATAMOTORS specifically without returning other Tata stocks', () {
      final rawLines = [
        'BUY TATA MOTORS TARGET 1020 SL 910',
      ];

      final result = engine.matchStocks(
        rawLines: rawLines,
        allStocks: mockStocks,
      );

      expect(result.matchedStocks.isNotEmpty, isTrue);
      expect(result.matchedStocks.first.symbol, equals('TATAMOTORS'));
      expect(result.matchedStocks.length, equals(1));
    });

    test('Filters out stopwords and matches exact symbol RELIANCE', () {
      final rawLines = [
        'BUY RELIANCE CMP 2980',
        'TARGET 3100 SL 2900 INTRADAY',
      ];

      final result = engine.matchStocks(
        rawLines: rawLines,
        allStocks: mockStocks,
      );

      expect(result.matchedStocks.isNotEmpty, isTrue);
      expect(result.matchedStocks.first.symbol, equals('RELIANCE'));
      expect(result.detectedTokens.contains('RELIANCE'), isTrue);
      expect(result.detectedTokens.contains('BUY'), isFalse);
      expect(result.detectedTokens.contains('CMP'), isFalse);
      expect(result.detectedTokens.contains('SL'), isFalse);
    });

    test('Matches company name State Bank of India to SBIN', () {
      final rawLines = [
        'Breaking News: State Bank of India Q2 Profit Surges',
      ];

      final result = engine.matchStocks(
        rawLines: rawLines,
        allStocks: mockStocks,
      );

      expect(result.matchedStocks.any((s) => s.symbol == 'SBIN'), isTrue);
    });

    test('Returns empty when no stock matches', () {
      final rawLines = [
        'RANDOM TEXT WITHOUT ANY STOCK SYMBOL 12345',
      ];

      final result = engine.matchStocks(
        rawLines: rawLines,
        allStocks: mockStocks,
      );

      expect(result.matchedStocks.isEmpty, isTrue);
    });
  });
}
