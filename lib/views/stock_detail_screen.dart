import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/stock_detail/stock_detail_bloc.dart';
import '../blocs/stock_detail/stock_detail_event.dart';
import '../blocs/stock_detail/stock_detail_state.dart';
import '../blocs/watchlist/watchlist_bloc.dart';
import '../blocs/watchlist/watchlist_event.dart';
import '../blocs/watchlist/watchlist_state.dart';
import '../models/stock_detail_data.dart';
import '../models/stock_model.dart';
import '../widgets/interactive_stock_chart.dart';
import 'risk_management_screen.dart';

class StockDetailScreen extends StatelessWidget {
  final StockModel stock;

  const StockDetailScreen({
    super.key,
    required this.stock,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StockDetailBloc()
        ..add(LoadStockDetailEvent(stock: stock, timeframe: '1D')),
      child: _StockDetailView(stock: stock),
    );
  }
}

class _StockDetailView extends StatelessWidget {
  final StockModel stock;
  static const List<String> _timeframes = ['1D', '1W', '1M', '1Y', 'ALL'];

  const _StockDetailView({required this.stock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117), // Deep dark sleek theme matching screenshot
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          stock.symbol,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          BlocBuilder<WatchlistBloc, WatchlistState>(
            builder: (context, watchlistState) {
              final Set<String> savedIds = (watchlistState is WatchlistLoaded)
                  ? watchlistState.watchlistIds
                  : {};
              final isSaved = savedIds.contains(stock.securityId);

              return IconButton(
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border_rounded,
                  color: isSaved ? const Color(0xFF10B981) : Colors.white,
                  size: 24,
                ),
                tooltip: isSaved ? 'Remove from Watchlist' : 'Save to Watchlist',
                onPressed: () {
                  context.read<WatchlistBloc>().add(
                        ToggleWatchlistStockEvent(stock),
                      );
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 1),
                      backgroundColor: const Color(0xFF1E222D),
                      content: Text(
                        isSaved
                            ? '${stock.symbol} removed from Watchlist'
                            : '${stock.symbol} saved to Watchlist',
                        style: TextStyle(
                          color: isSaved ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<StockDetailBloc, StockDetailState>(
        builder: (context, state) {
          if (state is StockDetailLoading && state.previousData == null) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2563EB),
              ),
            );
          }

          if (state is StockDetailError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load market data',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                      ),
                      onPressed: () {
                        context.read<StockDetailBloc>().add(
                              LoadStockDetailEvent(stock: stock, timeframe: state.timeframe),
                            );
                      },
                      child: const Text('Retry', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          }

          StockDetailData? detailData;
          String selectedTimeframe = '1D';
          bool isChartLoading = false;

          if (state is StockDetailLoaded) {
            detailData = state.detailData;
            selectedTimeframe = state.selectedTimeframe;
          } else if (state is StockDetailLoading) {
            detailData = state.previousData;
            selectedTimeframe = state.timeframe;
            isChartLoading = true;
          }

          final isNegative = detailData != null ? detailData.change < 0 : stock.change < 0;
          final badgeColor = isNegative ? const Color(0xFFEF4444) : const Color(0xFF10B981);
          final badgeBgColor = badgeColor.withValues(alpha: 0.16);

          return RefreshIndicator(
            onRefresh: () async {
              context.read<StockDetailBloc>().add(const RefreshStockDetailEvent());
            },
            color: const Color(0xFF2563EB),
            backgroundColor: const Color(0xFF1E222D),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stock Header (Logo badge, Symbol, NSE tag, Full name)
                  _buildStockHeader(detailData),

                  const SizedBox(height: 18),

                  // Price and Percentage change badge
                  _buildPriceSection(detailData, badgeColor, badgeBgColor, isNegative),

                  const SizedBox(height: 20),

                  // Timeframe Selector Buttons (1D, 1W, 1M, 1Y, ALL)
                  _buildTimeframeSelector(context, selectedTimeframe),

                  const SizedBox(height: 16),

                  // Real Stock Line Chart
                  _buildChartSection(detailData, !isNegative, isChartLoading),

                  const SizedBox(height: 24),

                  // Key Statistics Title
                  const Text(
                    'Key Statistics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 6 Key Statistics Grid Cards matching design
                  _buildKeyStatisticsGrid(detailData),

                  const SizedBox(height: 32),

                  // Bottom BUY (LONG) and SELL (SHORT) buttons
                  _buildTradingActionButtons(context, detailData),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStockHeader(StockDetailData? detailData) {
    final avatarLetter = stock.symbol.length >= 3
        ? stock.symbol.substring(0, 3)
        : stock.symbol;

    return Row(
      children: [
        // Rounded Square Avatar Badge like screenshot
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2E384D),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              avatarLetter,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Symbol and NSE badge + Company Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    stock.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'NSE',
                      style: TextStyle(
                        color: Color(0xFF60A5FA),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (detailData != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: detailData.isLive
                            ? const Color(0xFF10B981).withValues(alpha: 0.18)
                            : const Color(0xFF64748B).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: detailData.isLive
                              ? const Color(0xFF10B981).withValues(alpha: 0.5)
                              : const Color(0xFF64748B).withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: detailData.isLive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            detailData.isLive ? 'LIVE' : (detailData.priceSource == 'YAHOO_FINANCE' ? 'YAHOO' : 'DELAYED'),
                            style: TextStyle(
                              color: detailData.isLive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                detailData?.companyName ?? stock.name,
                style: const TextStyle(
                  color: Color(0xFF8F9CAE),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection(
    StockDetailData? data,
    Color badgeColor,
    Color badgeBgColor,
    bool isNegative,
  ) {
    final price = data?.currentPrice ?? (stock.lastPrice > 0 ? stock.lastPrice : 0.0);
    final change = data?.change ?? stock.change;
    final changePct = data?.changePercent ?? stock.changePercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Price in Rupee
        Text(
          price > 0 ? '₹${price.toStringAsFixed(2)}' : '₹--',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),

        const SizedBox(height: 10),

        // Rounded pill badge with arrow, amount change, and percentage
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: badgeBgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNegative ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                color: badgeColor,
                size: 18,
              ),
              Text(
                '${isNegative ? '-' : '+'}₹${change.abs().toStringAsFixed(2)} (${isNegative ? '-' : '+'}${changePct.abs().toStringAsFixed(2)}%)',
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeframeSelector(BuildContext context, String selectedTimeframe) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF181C26),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _timeframes.map((tf) {
          final isSelected = selectedTimeframe == tf;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isSelected) {
                  context.read<StockDetailBloc>().add(ChangeTimeframeEvent(tf));
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    tf,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF8F9CAE),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartSection(StockDetailData? data, bool isPositive, bool isChartLoading) {
    if (isChartLoading && data == null) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          color: Color(0xFF2563EB),
          strokeWidth: 2.5,
        ),
      );
    }

    final points = data?.chartPoints ?? [];

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: InteractiveStockChart(
            points: points,
            isPositive: isPositive,
            baselinePrice: data?.open,
          ),
        ),
        if (isChartLoading)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF38BDF8),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKeyStatisticsGrid(StockDetailData? data) {
    final openVal = (data?.open != null && data!.open > 0)
        ? '₹${data.open.toStringAsFixed(2)}'
        : (stock.lastPrice > 0 ? '₹${stock.lastPrice.toStringAsFixed(2)}' : '-');
    final highVal = (data?.high != null && data!.high > 0)
        ? '₹${data.high.toStringAsFixed(2)}'
        : (stock.lastPrice > 0 ? '₹${stock.lastPrice.toStringAsFixed(2)}' : '-');
    final lowVal = (data?.low != null && data!.low > 0)
        ? '₹${data.low.toStringAsFixed(2)}'
        : (stock.lastPrice > 0 ? '₹${stock.lastPrice.toStringAsFixed(2)}' : '-');
    final marketCapVal = data?.marketCapFormatted ?? '-';
    final peRatioVal = data?.peRatioFormatted ?? '-';
    final volumeVal = data?.volumeFormatted ?? '-';

    return Column(
      children: [
        // Row 1: Open, High, Low
        Row(
          children: [
            Expanded(child: _buildStatCard('Open', openVal)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard('High', highVal)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard('Low', lowVal)),
          ],
        ),

        const SizedBox(height: 10),

        // Row 2: Market Cap, P/E Ratio, Volume
        Row(
          children: [
            Expanded(child: _buildStatCard('Market Cap', marketCapVal)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard('P/E Ratio', peRatioVal)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard('Volume', volumeVal)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181D28), // Dark slate tile matching screenshot
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF262E3E),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7F8FA4),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTradingActionButtons(BuildContext context, StockDetailData? detailData) {
    return Row(
      children: [
        // BUY (LONG) Button
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981), // Vibrant green matching screenshot
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RiskManagementScreen(
                    stock: stock,
                    isBuy: true,
                    initialPrice: detailData?.currentPrice ?? stock.lastPrice,
                    priceSource: detailData?.priceSource ?? 'CACHED',
                    isLive: detailData?.isLive ?? false,
                    // BUY SL anchors: levels below entry price
                    swingLow: detailData != null && detailData.low > 0
                        ? detailData.low * 0.99  // ~1% below today's low
                        : null,
                    prevLow: detailData?.low,    // today's session low
                  ),
                ),
              );
            },
            child: const Text(
              'BUY (LONG)',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),

        const SizedBox(width: 14),

        // SELL (SHORT) Button
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444), // Vibrant red matching screenshot
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RiskManagementScreen(
                    stock: stock,
                    isBuy: false,
                    initialPrice: detailData?.currentPrice ?? stock.lastPrice,
                    priceSource: detailData?.priceSource ?? 'CACHED',
                    isLive: detailData?.isLive ?? false,
                    // SELL SL anchors: levels ABOVE entry price (resistance zones)
                    swingHigh: detailData != null && detailData.high > 0
                        ? detailData.high * 1.01  // ~1% above today's high
                        : null,
                    prevHigh: detailData?.high,   // today's session high
                  ),
                ),
              );
            },
            child: const Text(
              'SELL (SHORT)',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

