import 'package:equatable/equatable.dart';
import '../../models/stock_model.dart';

abstract class StockState extends Equatable {
  const StockState();

  @override
  List<Object?> get props => [];
}

class StockInitial extends StockState {
  const StockInitial();
}

class StockLoading extends StockState {
  const StockLoading();
}

class StockLoaded extends StockState {
  final List<StockModel> top10Stocks;
  final List<StockModel> searchResults;
  final String query;
  final int totalInstruments;

  const StockLoaded({
    required this.top10Stocks,
    this.searchResults = const [],
    this.query = '',
    this.totalInstruments = 0,
  });

  bool get isSearching => query.trim().isNotEmpty;

  StockLoaded copyWith({
    List<StockModel>? top10Stocks,
    List<StockModel>? searchResults,
    String? query,
    int? totalInstruments,
  }) {
    return StockLoaded(
      top10Stocks: top10Stocks ?? this.top10Stocks,
      searchResults: searchResults ?? this.searchResults,
      query: query ?? this.query,
      totalInstruments: totalInstruments ?? this.totalInstruments,
    );
  }

  @override
  List<Object?> get props => [top10Stocks, searchResults, query, totalInstruments];
}

class StockError extends StockState {
  final String message;

  const StockError(this.message);

  @override
  List<Object?> get props => [message];
}
