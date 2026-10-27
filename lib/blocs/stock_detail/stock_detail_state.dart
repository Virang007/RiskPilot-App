import 'package:equatable/equatable.dart';
import '../../models/stock_detail_data.dart';
import '../../models/stock_model.dart';

abstract class StockDetailState extends Equatable {
  const StockDetailState();

  @override
  List<Object?> get props => [];
}

class StockDetailInitial extends StockDetailState {
  const StockDetailInitial();
}

class StockDetailLoading extends StockDetailState {
  final StockModel stock;
  final String timeframe;
  final StockDetailData? previousData;

  const StockDetailLoading({
    required this.stock,
    this.timeframe = '1D',
    this.previousData,
  });

  @override
  List<Object?> get props => [stock, timeframe, previousData];
}

class StockDetailLoaded extends StockDetailState {
  final StockModel stock;
  final StockDetailData detailData;
  final String selectedTimeframe;

  const StockDetailLoaded({
    required this.stock,
    required this.detailData,
    required this.selectedTimeframe,
  });

  @override
  List<Object?> get props => [stock, detailData, selectedTimeframe];

  StockDetailLoaded copyWith({
    StockModel? stock,
    StockDetailData? detailData,
    String? selectedTimeframe,
  }) {
    return StockDetailLoaded(
      stock: stock ?? this.stock,
      detailData: detailData ?? this.detailData,
      selectedTimeframe: selectedTimeframe ?? this.selectedTimeframe,
    );
  }
}

class StockDetailError extends StockDetailState {
  final StockModel stock;
  final String message;
  final String timeframe;

  const StockDetailError({
    required this.stock,
    required this.message,
    this.timeframe = '1D',
  });

  @override
  List<Object?> get props => [stock, message, timeframe];
}
