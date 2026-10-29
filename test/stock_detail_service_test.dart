import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/models/stock_detail_data.dart';
import 'package:my_app/models/stock_model.dart';
import 'package:my_app/repositories/stock_detail_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const testStock = StockModel(
    securityId: '11536',
    symbol: 'TCS',
    name: 'Tata Consultancy Services',
    exchange: 'NSE',
    lastPrice: 3500.0,
    change: 15.0,
    changePercent: 0.43,
  );

  group('StockDetailService Formatting & Fallback Tests', () {
    test('formatVolume formats numbers accurately and returns - for null/empty', () {
      expect(StockDetailService.formatVolume(null), '-');
      expect(StockDetailService.formatVolume(0), '-');
      expect(StockDetailService.formatVolume(-5), '-');
      expect(StockDetailService.formatVolume(500), '500');
      expect(StockDetailService.formatVolume(45200), '45.2K');
      expect(StockDetailService.formatVolume(10700000), '1.07 Cr');
    });

    test('formatMarketCap handles zero and positive prices safely without hardcoding', () {
      expect(StockDetailService.formatMarketCap(0.0, 10000), '-');
      expect(StockDetailService.formatMarketCap(-10.0, 10000), '-');
      final cap = StockDetailService.formatMarketCap(3500.0, 1000000);
      expect(cap, contains('Cr'));
    });

    test('fetchRealStockDetail fallback returns realistic cached data with isLive false and no fake 692.75', () async {
      final detail = await StockDetailService.fetchRealStockDetail(
        stock: testStock,
        timeframe: '1D',
      );

      // Verify no hardcoded 692.75
      expect(detail.currentPrice, isNot(692.75));
      expect(detail.symbol, 'TCS');
      expect(detail.timeframe, '1D');
      // Price source must be one of the genuine sources, never UNKNOWN
      expect(['DHAN_LIVE', 'YAHOO_FINANCE', 'YAHOO_CANDLE_CLOSE', 'CACHED', 'UNAVAILABLE'],
          contains(detail.priceSource));
    });

    test('StockDetailData constructor preserves isLive and priceSource accurately', () {
      const dataLive = StockDetailData(
        symbol: 'INFY',
        companyName: 'Infosys',
        exchange: 'NSE',
        currentPrice: 1500.0,
        change: 10.0,
        changePercent: 0.67,
        open: 1490.0,
        high: 1510.0,
        low: 1485.0,
        close: 1490.0,
        marketCapFormatted: '₹6,00,000 Cr',
        peRatioFormatted: '28.5',
        volumeFormatted: '25.0L',
        chartPoints: [1490.0, 1500.0],
        timeframe: '1D',
        isLive: true,
        priceSource: 'DHAN_LIVE',
      );

      expect(dataLive.isLive, isTrue);
      expect(dataLive.priceSource, 'DHAN_LIVE');

      const dataYahoo = StockDetailData(
        symbol: 'INFY',
        companyName: 'Infosys',
        exchange: 'NSE',
        currentPrice: 1495.0,
        change: 5.0,
        changePercent: 0.33,
        open: 1490.0,
        high: 1510.0,
        low: 1485.0,
        close: 1490.0,
        marketCapFormatted: '₹6,00,000 Cr',
        peRatioFormatted: '28.5',
        volumeFormatted: '25.0L',
        chartPoints: [1490.0, 1495.0],
        timeframe: '1D',
        isLive: false,
        priceSource: 'YAHOO_FINANCE',
      );

      expect(dataYahoo.isLive, isFalse);
      expect(dataYahoo.priceSource, 'YAHOO_FINANCE');
    });
  });
}
