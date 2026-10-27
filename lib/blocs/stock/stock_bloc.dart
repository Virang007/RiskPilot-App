import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/stock_repository.dart';
import 'stock_event.dart';
import 'stock_state.dart';

class StockBloc extends Bloc<StockEvent, StockState> {
  final StockRepository repository;

  StockBloc({required this.repository}) : super(const StockInitial()) {
    on<LoadTopStocksEvent>(_onLoadTopStocks);
    on<SearchStocksEvent>(_onSearchStocks);
    on<ClearSearchEvent>(_onClearSearch);
  }

  Future<void> _onLoadTopStocks(
    LoadTopStocksEvent event,
    Emitter<StockState> emit,
  ) async {
    emit(const StockLoading());
    try {
      final all = await repository.loadInstruments();
      final top10 = await repository.getTop10Stocks();
      emit(StockLoaded(
        top10Stocks: top10,
        searchResults: const [],
        query: '',
        totalInstruments: all.length,
      ));
    } catch (e) {
      emit(StockError('Failed to load Dhan NSE Equity stocks: $e'));
    }
  }

  Future<void> _onSearchStocks(
    SearchStocksEvent event,
    Emitter<StockState> emit,
  ) async {
    final query = event.query.trim();
    if (state is StockLoaded) {
      final current = state as StockLoaded;
      if (query.isEmpty) {
        emit(current.copyWith(query: '', searchResults: []));
        return;
      }

      final results = await repository.searchStocks(query);
      emit(current.copyWith(
        query: query,
        searchResults: results,
      ));
    } else {
      emit(const StockLoading());
      try {
        final all = await repository.loadInstruments();
        final top10 = await repository.getTop10Stocks();
        final results = await repository.searchStocks(query);
        emit(StockLoaded(
          top10Stocks: top10,
          searchResults: results,
          query: query,
          totalInstruments: all.length,
        ));
      } catch (e) {
        emit(StockError('Search failed: $e'));
      }
    }
  }

  Future<void> _onClearSearch(
    ClearSearchEvent event,
    Emitter<StockState> emit,
  ) async {
    if (state is StockLoaded) {
      final current = state as StockLoaded;
      emit(current.copyWith(query: '', searchResults: []));
    }
  }
}
