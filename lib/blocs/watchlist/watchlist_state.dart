import 'package:equatable/equatable.dart';
import '../../models/stock_model.dart';

abstract class WatchlistState extends Equatable {
  const WatchlistState();

  @override
  List<Object?> get props => [];
}

class WatchlistInitial extends WatchlistState {
  const WatchlistInitial();
}

class WatchlistLoading extends WatchlistState {
  const WatchlistLoading();
}

class WatchlistLoaded extends WatchlistState {
  final List<StockModel> watchlistStocks;
  final Set<String> watchlistIds;

  const WatchlistLoaded({
    required this.watchlistStocks,
    required this.watchlistIds,
  });

  bool isSaved(String securityId) => watchlistIds.contains(securityId);

  @override
  List<Object?> get props => [watchlistStocks, watchlistIds];
}

class WatchlistError extends WatchlistState {
  final String message;

  const WatchlistError(this.message);

  @override
  List<Object?> get props => [message];
}
