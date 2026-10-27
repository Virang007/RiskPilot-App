import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock_model.dart';

class StockRepository {
  List<StockModel> _allStocks = [];
  bool _isLoaded = false;
  static const String _watchlistKey = 'dhan_user_watchlist_ids';

  // Top 10 prominent NSE Equities security IDs / symbols from Dhan master
  static const List<String> top10Symbols = [
    'RELIANCE',
    'TCS',
    'HDFCBANK',
    'ICICIBANK',
    'INFY',
    'SBIN',
    'BHARTIARTL',
    'ITC',
    'LT',
    'TATASTEEL',
  ];

  // Base prices for Top 10 for realistic view if live quote is not yet authenticated
  static const Map<String, double> _referencePrices = {
    'RELIANCE': 2980.50,
    'TCS': 4150.20,
    'HDFCBANK': 1680.10,
    'ICICIBANK': 1250.75,
    'INFY': 1885.30,
    'SBIN': 795.40,
    'BHARTIARTL': 1685.00,
    'ITC': 490.60,
    'LT': 3550.00,
    'TATASTEEL': 155.80,
  };

  /// Load all 2,732 NSE Equity instruments from Dhan master JSON
  Future<List<StockModel>> loadInstruments() async {
    if (_isLoaded && _allStocks.isNotEmpty) {
      return _allStocks;
    }

    try {
      final jsonString = await rootBundle.loadString('assets/dhan_nse_equity.json');
      final List<dynamic> data = jsonDecode(jsonString);
      _allStocks = data.map((item) {
        final stock = StockModel.fromJson(item as Map<String, dynamic>);
        final refPrice = _referencePrices[stock.symbol];
        if (refPrice != null) {
          // Provide realistic price & change
          final changeVal = (stock.symbol.hashCode % 30 - 12) * 1.25;
          final pct = (changeVal / refPrice) * 100;
          return stock.copyWith(
            lastPrice: refPrice + changeVal,
            change: changeVal,
            changePercent: pct,
          );
        } else {
          // Deterministic price based on security ID
          final pseudoPrice = 150.0 + (int.tryParse(stock.securityId) ?? 500) % 2500;
          final pseudoChange = ((stock.symbol.hashCode % 20) - 9) * 0.8;
          final pseudoPct = (pseudoChange / pseudoPrice) * 100;
          return stock.copyWith(
            lastPrice: pseudoPrice,
            change: pseudoChange,
            changePercent: pseudoPct,
          );
        }
      }).toList();

      _isLoaded = true;
      return _allStocks;
    } catch (e) {
      return [];
    }
  }

  /// Get Top 10 Stocks
  Future<List<StockModel>> getTop10Stocks() async {
    final stocks = await loadInstruments();
    final List<StockModel> topList = [];

    for (final sym in top10Symbols) {
      final found = stocks.where((s) => s.symbol.toUpperCase() == sym.toUpperCase());
      if (found.isNotEmpty) {
        topList.add(found.first);
      }
    }

    // Fallback if some symbols weren't found
    if (topList.length < 10 && stocks.isNotEmpty) {
      for (final s in stocks) {
        if (!topList.contains(s)) {
          topList.add(s);
          if (topList.length == 10) break;
        }
      }
    }

    return topList;
  }

  /// Search stocks by query across all 2,732 Dhan NSE Equity instruments
  Future<List<StockModel>> searchStocks(String query) async {
    final stocks = await loadInstruments();
    final clean = query.trim().toUpperCase();
    if (clean.isEmpty) {
      return getTop10Stocks();
    }

    // Rank matching: Exact symbol > Starts with symbol > Contains symbol > Name contains
    final exactSymbol = <StockModel>[];
    final startsWithSymbol = <StockModel>[];
    final containsSymbol = <StockModel>[];
    final containsName = <StockModel>[];

    for (final s in stocks) {
      final sym = s.symbol.toUpperCase();
      final name = s.name.toUpperCase();

      if (sym == clean) {
        exactSymbol.add(s);
      } else if (sym.startsWith(clean)) {
        startsWithSymbol.add(s);
      } else if (sym.contains(clean)) {
        containsSymbol.add(s);
      } else if (name.contains(clean)) {
        containsName.add(s);
      }
    }

    final results = [
      ...exactSymbol,
      ...startsWithSymbol,
      ...containsSymbol,
      ...containsName,
    ];

    // Return maximum 50 matches for smooth performance
    return results.take(50).toList();
  }

  /// Load Watchlist Security IDs from local storage
  Future<List<String>> getWatchlistIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_watchlistKey) ?? [];
  }

  /// Toggle stock in Watchlist
  Future<List<StockModel>> toggleWatchlist(StockModel stock) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_watchlistKey) ?? [];

    if (ids.contains(stock.securityId)) {
      ids.remove(stock.securityId);
    } else {
      ids.insert(0, stock.securityId);
    }

    await prefs.setStringList(_watchlistKey, ids);
    return getWatchlistStocks();
  }

  /// Get all Watchlist stocks
  Future<List<StockModel>> getWatchlistStocks() async {
    final ids = await getWatchlistIds();
    if (ids.isEmpty) return [];

    final all = await loadInstruments();
    final map = {for (final s in all) s.securityId: s};

    final List<StockModel> list = [];
    for (final id in ids) {
      if (map.containsKey(id)) {
        list.add(map[id]!);
      }
    }
    return list;
  }
}
