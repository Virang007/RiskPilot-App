import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/stock/stock_bloc.dart';
import '../../blocs/stock/stock_event.dart';
import '../../blocs/stock/stock_state.dart';
import '../../blocs/watchlist/watchlist_bloc.dart';
import '../../blocs/watchlist/watchlist_event.dart';
import '../../blocs/watchlist/watchlist_state.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/stock_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/stock_scan_bottom_sheet.dart';
import '../../blocs/scan_stock/scan_stock_bloc.dart';
import '../../blocs/scan_stock/scan_stock_event.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCameraScanner() {
    StockScanBottomSheet.show(context, searchController: _searchController);
    context.read<ScanStockBloc>().add(const CaptureStockWithCameraEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'RiskPilot',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              // 'NSE Equity Market',
              'Market',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          // IconButton(
          //   icon: Container(
          //     padding: const EdgeInsets.all(6),
          //     decoration: BoxDecoration(
          //       color: const Color(0xFF10B981).withValues(alpha: 0.15),
          //       borderRadius: BorderRadius.circular(8),
          //       border: Border.all(
          //         color: const Color(0xFF10B981).withValues(alpha: 0.4),
          //       ),
          //     ),
          //     child: const Icon(
          //       Icons.camera_alt_rounded,
          //       color: Color(0xFF10B981),
          //       size: 18,
          //     ),
          //   ),
          //   tooltip: 'Scan Stock / Share Name',
          //   onPressed: _openCameraScanner,
          // ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF10B981)),
                SizedBox(width: 5),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Search Bar with Camera Scan Trigger
          SearchBarWidget(
            controller: _searchController,
            onChanged: (query) {
              context.read<StockBloc>().add(SearchStocksEvent(query));
            },
            onClear: () {
              context.read<StockBloc>().add(const ClearSearchEvent());
            },
            onCameraTap: _openCameraScanner,
          ),

          // Stock List Content (Top 10 or Search Results)
          Expanded(
            child: BlocBuilder<StockBloc, StockState>(
              builder: (context, stockState) {
                if (stockState is StockLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF10B981)),
                  );
                }

                if (stockState is StockError) {
                  return EmptyView(
                    icon: Icons.error_outline_rounded,
                    title: 'Unable to Load Stocks',
                    subtitle: stockState.message,
                    buttonText: 'Retry',
                    onButtonPressed: () {
                      context.read<StockBloc>().add(const LoadTopStocksEvent());
                    },
                  );
                }

                if (stockState is StockLoaded) {
                  final isSearching = stockState.isSearching;
                  final displayList = isSearching
                      ? stockState.searchResults
                      : stockState.top10Stocks;

                  return BlocBuilder<WatchlistBloc, WatchlistState>(
                    builder: (context, watchlistState) {
                      final Set<String> savedIds =
                          (watchlistState is WatchlistLoaded)
                          ? watchlistState.watchlistIds
                          : {};

                      return CustomScrollView(
                        slivers: [
                          // Section Title
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isSearching
                                            ? Icons.search_rounded
                                            : Icons.trending_up_rounded,
                                        color: const Color(0xFF38BDF8),
                                        size: 19,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isSearching
                                            ? 'Search Results'
                                            : 'Top 10 Stocks',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isSearching
                                          ? '${displayList.length} found'
                                          : 'NSE Equity',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Empty Search Results
                          if (isSearching && displayList.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: EmptyView(
                                icon: Icons.search_off_rounded,
                                title: 'No Stocks Found',
                                subtitle:
                                    'No Dhan NSE Equity stock matching "${stockState.query}"',
                              ),
                            )
                          else
                            // Stock Cards
                            SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final stock = displayList[index];
                                final isSaved = savedIds.contains(
                                  stock.securityId,
                                );

                                return StockCard(
                                  stock: stock,
                                  isSaved: isSaved,
                                  onToggleWatchlist: () {
                                    context.read<WatchlistBloc>().add(
                                      ToggleWatchlistStockEvent(stock),
                                    );
                                    ScaffoldMessenger.of(
                                      context,
                                    ).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        duration: const Duration(seconds: 1),
                                        backgroundColor: const Color(
                                          0xFF1E293B,
                                        ),
                                        content: Text(
                                          isSaved
                                              ? '${stock.symbol} removed from Watchlist'
                                              : '${stock.symbol} added to Watchlist',
                                          style: TextStyle(
                                            color: isSaved
                                                ? const Color(0xFFF87171)
                                                : const Color(0xFF10B981),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }, childCount: displayList.length),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        ],
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}
