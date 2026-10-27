import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/scan_stock/scan_stock_bloc.dart';
import '../../blocs/scan_stock/scan_stock_event.dart';
import '../../blocs/scan_stock/scan_stock_state.dart';
import '../../blocs/stock/stock_bloc.dart';
import '../../blocs/stock/stock_event.dart';
import '../../models/stock_model.dart';
import '../views/stock_detail_screen.dart';

class StockScanBottomSheet extends StatelessWidget {
  final TextEditingController searchController;

  const StockScanBottomSheet({
    super.key,
    required this.searchController,
  });

  static Future<void> show(
    BuildContext context, {
    required TextEditingController searchController,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StockScanBottomSheet(
        searchController: searchController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: const Color(0xFF475569),
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Stock / Share Name',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'AI OCR extracts symbols from photos & charts',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    context.read<ScanStockBloc>().add(const ResetScanStockEvent());
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF334155), height: 1),

          // Main Dynamic Content
          Flexible(
            child: BlocBuilder<ScanStockBloc, ScanStockState>(
              builder: (context, state) {
                if (state is ScanStockProcessing) {
                  return _buildProcessingView(state.imagePath);
                } else if (state is ScanStockSuccess) {
                  return _buildSuccessView(context, state);
                } else if (state is ScanStockNoMatchFound) {
                  return _buildNoMatchView(context, state);
                } else if (state is ScanStockFailure) {
                  return _buildFailureView(context, state.errorMessage);
                }

                // Initial / Capturing prompt
                return _buildCapturePromptView(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapturePromptView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              size: 48,
              color: Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Capture or Upload Stock Image',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Point your camera at a stock chart, newspaper, trading screen, or broker advice to auto-detect stock name.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<ScanStockBloc>().add(const CaptureStockWithCameraEvent());
                  },
                  icon: const Icon(Icons.camera_rounded, color: Colors.white, size: 20),
                  label: const Text('Open Camera', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<ScanStockBloc>().add(const PickStockFromGalleryEvent());
                  },
                  icon: const Icon(Icons.photo_library_outlined, color: Color(0xFF38BDF8), size: 20),
                  label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingView(String? imagePath) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imagePath != null && File(imagePath).existsSync())
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981), width: 2),
                image: DecorationImage(
                  image: FileImage(File(imagePath)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const CircularProgressIndicator(
            color: Color(0xFF10B981),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          const Text(
            'Analyzing Image with OCR...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Extracting text & matching against 2,700+ NSE stocks',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context, ScanStockSuccess state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Detected Tokens Chips
          if (state.rawDetectedTokens.isNotEmpty) ...[
            const Text(
              'DETECTED KEYWORDS',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: state.rawDetectedTokens.take(8).map((token) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Text(
                    token,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Matched Stocks Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MATCHED STOCKS (${state.matchedStocks.length})',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  context.read<ScanStockBloc>().add(const CaptureStockWithCameraEvent());
                },
                icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF94A3B8)),
                label: const Text('Rescan', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Stocks List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.matchedStocks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (ctx, index) {
              final stock = state.matchedStocks[index];
              final isPositive = stock.change >= 0;

              return InkWell(
                onTap: () {
                  _selectStock(context, stock);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      // Stock Symbol Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Text(
                            stock.symbol.isNotEmpty ? stock.symbol[0] : 'S',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Symbol & Name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stock.symbol,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stock.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Price & Action
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${stock.lastPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${isPositive ? '+' : ''}${stock.changePercent.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNoMatchView(BuildContext context, ScanStockNoMatchFound state) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, color: Color(0xFFEF4444), size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Stock Names Matched',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We could not identify any NSE stock symbols from this image. Please make sure the stock symbol or company name is clearly visible.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          if (state.rawDetectedTokens.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Read: ${state.rawDetectedTokens.take(5).join(", ")}',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<ScanStockBloc>().add(const CaptureStockWithCameraEvent());
                  },
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('Retake Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<ScanStockBloc>().add(const PickStockFromGalleryEvent());
                  },
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Pick Image'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFailureView(BuildContext context, String errorMessage) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 44),
          const SizedBox(height: 12),
          const Text(
            'Scan Error',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              context.read<ScanStockBloc>().add(const CaptureStockWithCameraEvent());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _selectStock(BuildContext context, StockModel stock) {
    // 1. Auto-fill the search controller and dispatch search event
    searchController.text = stock.symbol;
    context.read<StockBloc>().add(SearchStocksEvent(stock.symbol));

    // 2. Reset scanner
    context.read<ScanStockBloc>().add(const ResetScanStockEvent());

    // 3. Dismiss bottom sheet
    Navigator.pop(context);

    // 4. Open StockDetailScreen directly for instant seamless continuation
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockDetailScreen(stock: stock),
      ),
    );
  }
}
