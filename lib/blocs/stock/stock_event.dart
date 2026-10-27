import 'package:equatable/equatable.dart';

abstract class StockEvent extends Equatable {
  const StockEvent();

  @override
  List<Object?> get props => [];
}

class LoadTopStocksEvent extends StockEvent {
  const LoadTopStocksEvent();
}

class SearchStocksEvent extends StockEvent {
  final String query;

  const SearchStocksEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class ClearSearchEvent extends StockEvent {
  const ClearSearchEvent();
}
