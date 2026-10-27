import 'package:equatable/equatable.dart';
import '../../models/stock_model.dart';

abstract class StockDetailEvent extends Equatable {
  const StockDetailEvent();

  @override
  List<Object?> get props => [];
}

class LoadStockDetailEvent extends StockDetailEvent {
  final StockModel stock;
  final String timeframe;

  const LoadStockDetailEvent({
    required this.stock,
    this.timeframe = '1D',
  });

  @override
  List<Object?> get props => [stock, timeframe];
}

class ChangeTimeframeEvent extends StockDetailEvent {
  final String timeframe;

  const ChangeTimeframeEvent(this.timeframe);

  @override
  List<Object?> get props => [timeframe];
}

class RefreshStockDetailEvent extends StockDetailEvent {
  const RefreshStockDetailEvent();
}
