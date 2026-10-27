import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/stock_repository.dart';
import 'watchlist_event.dart';
import 'watchlist_state.dart';

class WatchlistBloc extends Bloc<WatchlistEvent, WatchlistState> {
  final StockRepository repository;

  WatchlistBloc({required this.repository}) : super(const WatchlistInitial()) {
    on<LoadWatchlistEvent>(_onLoadWatchlist);
    on<ToggleWatchlistStockEvent>(_onToggleWatchlistStock);
  }

  Future<void> _onLoadWatchlist(
    LoadWatchlistEvent event,
    Emitter<WatchlistState> emit,
  ) async {
    emit(const WatchlistLoading());
    try {
      final ids = await repository.getWatchlistIds();
      final stocks = await repository.getWatchlistStocks();
      emit(WatchlistLoaded(
        watchlistStocks: stocks,
        watchlistIds: ids.toSet(),
      ));
    } catch (e) {
      emit(WatchlistError('Failed to load watchlist: $e'));
    }
  }

  Future<void> _onToggleWatchlistStock(
    ToggleWatchlistStockEvent event,
    Emitter<WatchlistState> emit,
  ) async {
    try {
      final updatedList = await repository.toggleWatchlist(event.stock);
      final ids = await repository.getWatchlistIds();
      emit(WatchlistLoaded(
        watchlistStocks: updatedList,
        watchlistIds: ids.toSet(),
      ));
    } catch (e) {
      emit(WatchlistError('Failed to update watchlist: $e'));
    }
  }
}
