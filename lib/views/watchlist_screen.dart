import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/watchlist/watchlist_bloc.dart';
import '../../blocs/watchlist/watchlist_event.dart';
import '../../blocs/watchlist/watchlist_state.dart';
import '../../widgets/stock_card.dart';
import '../../widgets/empty_view.dart';

class WatchlistScreen extends StatelessWidget {
  final VoidCallback onNavigateToHome;

  const WatchlistScreen({
    super.key,
    required this.onNavigateToHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.bookmark_rounded, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text(
              'My Watchlist',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          BlocBuilder<WatchlistBloc, WatchlistState>(
            builder: (context, state) {
              final count = (state is WatchlistLoaded)
                  ? state.watchlistStocks.length
                  : 0;

              return Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count Stocks',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<WatchlistBloc, WatchlistState>(
        builder: (context, state) {
          if (state is WatchlistLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            );
          }

          if (state is WatchlistError) {
            return EmptyView(
              icon: Icons.error_outline_rounded,
              title: 'Error Loading Watchlist',
              subtitle: state.message,
              buttonText: 'Retry',
              onButtonPressed: () {
                context.read<WatchlistBloc>().add(const LoadWatchlistEvent());
              },
            );
          }

          if (state is WatchlistLoaded) {
            final stocks = state.watchlistStocks;

            if (stocks.isEmpty) {
              return EmptyView(
                icon: Icons.bookmark_add_outlined,
                title: 'Watchlist is Empty',
                subtitle: 'Search and save your favorite NSE stocks from the Home tab to track them here.',
                buttonText: 'Explore Stocks',
                onButtonPressed: onNavigateToHome,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: stocks.length,
              itemBuilder: (context, index) {
                final stock = stocks[index];
                return StockCard(
                  stock: stock,
                  isSaved: true,
                  onToggleWatchlist: () {
                    context.read<WatchlistBloc>().add(
                          ToggleWatchlistStockEvent(stock),
                        );
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 1),
                        backgroundColor: const Color(0xFF1E293B),
                        content: Text(
                          '${stock.symbol} removed from Watchlist',
                          style: const TextStyle(
                            color: Color(0xFFF87171),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
