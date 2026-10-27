import 'package:equatable/equatable.dart';
import '../../models/stock_model.dart';

abstract class WatchlistEvent extends Equatable {
  const WatchlistEvent();

  @override
  List<Object?> get props => [];
}

class LoadWatchlistEvent extends WatchlistEvent {
  const LoadWatchlistEvent();
}

class ToggleWatchlistStockEvent extends WatchlistEvent {
  final StockModel stock;

  const ToggleWatchlistStockEvent(this.stock);

  @override
  List<Object?> get props => [stock];
}
