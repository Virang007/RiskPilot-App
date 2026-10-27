import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/stock_model.dart';
import '../../repositories/stock_detail_service.dart';
import 'stock_detail_event.dart';
import 'stock_detail_state.dart';

class StockDetailBloc extends Bloc<StockDetailEvent, StockDetailState> {
  StockModel? _currentStock;
  String _currentTimeframe = '1D';

  StockDetailBloc() : super(const StockDetailInitial()) {
    on<LoadStockDetailEvent>(_onLoadStockDetail);
    on<ChangeTimeframeEvent>(_onChangeTimeframe);
    on<RefreshStockDetailEvent>(_onRefreshStockDetail);
  }

  Future<void> _onLoadStockDetail(
    LoadStockDetailEvent event,
    Emitter<StockDetailState> emit,
  ) async {
    _currentStock = event.stock;
    _currentTimeframe = event.timeframe;

    emit(StockDetailLoading(
      stock: event.stock,
      timeframe: event.timeframe,
    ));

    try {
      final data = await StockDetailService.fetchRealStockDetail(
        stock: event.stock,
        timeframe: event.timeframe,
      );

      emit(StockDetailLoaded(
        stock: event.stock,
        detailData: data,
        selectedTimeframe: event.timeframe,
      ));
    } catch (e) {
      emit(StockDetailError(
        stock: event.stock,
        message: e.toString(),
        timeframe: event.timeframe,
      ));
    }
  }

  Future<void> _onChangeTimeframe(
    ChangeTimeframeEvent event,
    Emitter<StockDetailState> emit,
  ) async {
    if (_currentStock == null) return;
    _currentTimeframe = event.timeframe;

    final previousData = (state is StockDetailLoaded)
        ? (state as StockDetailLoaded).detailData
        : null;

    emit(StockDetailLoading(
      stock: _currentStock!,
      timeframe: event.timeframe,
      previousData: previousData,
    ));

    try {
      final data = await StockDetailService.fetchRealStockDetail(
        stock: _currentStock!,
        timeframe: event.timeframe,
      );

      emit(StockDetailLoaded(
        stock: _currentStock!,
        detailData: data,
        selectedTimeframe: event.timeframe,
      ));
    } catch (e) {
      emit(StockDetailError(
        stock: _currentStock!,
        message: e.toString(),
        timeframe: event.timeframe,
      ));
    }
  }

  Future<void> _onRefreshStockDetail(
    RefreshStockDetailEvent event,
    Emitter<StockDetailState> emit,
  ) async {
    if (_currentStock == null) return;

    try {
      final data = await StockDetailService.fetchRealStockDetail(
        stock: _currentStock!,
        timeframe: _currentTimeframe,
      );

      emit(StockDetailLoaded(
        stock: _currentStock!,
        detailData: data,
        selectedTimeframe: _currentTimeframe,
      ));
    } catch (e) {
      emit(StockDetailError(
        stock: _currentStock!,
        message: e.toString(),
        timeframe: _currentTimeframe,
      ));
    }
  }
}
