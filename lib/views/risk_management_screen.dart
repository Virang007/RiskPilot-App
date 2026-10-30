import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/risk_management/risk_management_bloc.dart';
import '../blocs/risk_management/risk_management_event.dart';
import '../blocs/risk_management/risk_management_state.dart';
import '../models/stock_model.dart';

class RiskManagementScreen extends StatelessWidget {
  final StockModel stock;
  final bool isBuy;
  final double initialPrice;
  final String priceSource;
  final bool isLive;
  // BUY anchors
  final double? swingLow;
  final double? prevLow;
  // SELL anchors
  final double? swingHigh;
  final double? prevHigh;

  const RiskManagementScreen({
    super.key,
    required this.stock,
    required this.isBuy,
    required this.initialPrice,
    this.priceSource = 'UNKNOWN',
    this.isLive = false,
    this.swingLow,
    this.prevLow,
    this.swingHigh,
    this.prevHigh,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RiskManagementBloc()
        ..add(InitRiskManagementEvent(
          stock: stock,
          isBuy: isBuy,
          currentPrice: initialPrice,
          priceSource: priceSource,
          isLive: isLive,
          swingLow: swingLow,
          prevLow: prevLow,
          swingHigh: swingHigh,
          prevHigh: prevHigh,
        )),
      child: _RiskManagementView(stock: stock),
    );
  }
}

class _RiskManagementView extends StatefulWidget {
  final StockModel stock;

  const _RiskManagementView({required this.stock});

  @override
  State<_RiskManagementView> createState() => _RiskManagementViewState();
}

class _RiskManagementViewState extends State<_RiskManagementView> {
  final TextEditingController _slController = TextEditingController();
  final TextEditingController _tpController = TextEditingController();

  // Track last known state values to avoid re-setting controllers while user types
  double? _lastSl;
  double? _lastTp;

  @override
  void dispose() {
    _slController.dispose();
    _tpController.dispose();
    super.dispose();
  }

  void _syncControllers(RiskManagementLoaded state) {
    if (state.stopLoss != _lastSl) {
      _slController.text = state.stopLoss.toStringAsFixed(2);
      _lastSl = state.stopLoss;
    }
    if (state.targetPrice != _lastTp) {
      _tpController.text = state.targetPrice.toStringAsFixed(2);
      _lastTp = state.targetPrice;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Risk Management - ${widget.stock.symbol}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 19,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: BlocConsumer<RiskManagementBloc, RiskManagementState>(
        listener: (context, state) {
          if (state is RiskManagementLoaded) {
            // Sync text controllers with bloc state for non-CUSTOM methods
            _syncControllers(state);
            if (state.submissionSuccessMsg != null) {
              debugPrint('[UI POPUP] Showing Order Success Dialog: ${state.submissionSuccessMsg}');
              _showOrderSuccessDialog(context, state.submissionSuccessMsg!);
            } else if (state.submissionErrorMsg != null) {
              debugPrint('[UI POPUP] Showing Order Failure Dialog with real error: ${state.submissionErrorMsg}');
              _showOrderFailureDialog(context, state.submissionErrorMsg!);
            }
          }
        },
        builder: (context, state) {
          if (state is! RiskManagementLoaded) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            );
          }

          // Sync on first build
          WidgetsBinding.instance.addPostFrameCallback((_) => _syncControllers(state));

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStockHeaderCard(state),
                const SizedBox(height: 20),
                _buildProductTypeSection(context, state),
                const SizedBox(height: 18),
                _buildEntryAndQuantitySection(context, state),
                const SizedBox(height: 20),
                _buildRiskMethodSelector(context, state),
                const SizedBox(height: 18),
                _buildSlAndTpInputs(context, state),
                const SizedBox(height: 24),
                _buildRiskRewardPreviewCard(state),
                const SizedBox(height: 18),
                _buildMarginAndFundCard(context, state),
                const SizedBox(height: 20),
                _buildPriceSourceNotice(state),
                _buildValidationError(state),
                _buildConfirmButton(context, state),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStockHeaderCard(RiskManagementLoaded state) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF1E2838),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // BUY / SELL Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: state.isBuy ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.isBuy ? 'BUY' : 'SELL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        state.stock.symbol,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${state.stock.exchange})',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.stock.name,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
          Text(
            '₹${state.entryPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTypeSection(BuildContext context, RiskManagementLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Product Type',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Intraday (MIS)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  context.read<RiskManagementBloc>().add(const ChangeProductTypeEvent('INTRADAY'));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: state.productType == 'INTRADAY' ? const Color(0xFF2563EB) : const Color(0xFF181D28),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: state.productType == 'INTRADAY' ? const Color(0xFF3B82F6) : const Color(0xFF262E3E),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Intraday (MIS)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Same day square off',
                        style: TextStyle(
                          color: state.productType == 'INTRADAY' ? Colors.white70 : const Color(0xFF7F8FA4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Delivery (CNC)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  context.read<RiskManagementBloc>().add(const ChangeProductTypeEvent('CNC'));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: state.productType == 'CNC' ? const Color(0xFF2563EB) : const Color(0xFF181D28),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: state.productType == 'CNC' ? const Color(0xFF3B82F6) : const Color(0xFF262E3E),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Delivery (CNC)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Hold multi-day',
                        style: TextStyle(
                          color: state.productType == 'CNC' ? Colors.white70 : const Color(0xFF7F8FA4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEntryAndQuantitySection(BuildContext context, RiskManagementLoaded state) {
    return Row(
      children: [
        // Entry Price (Market Order)
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Entry Price (₹)',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'MARKET',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF181D28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF262E3E)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      state.entryPrice.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFFFBBF24),
                      size: 17,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        // Quantity (Shares) with +/- buttons
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quantity (Shares)',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF181D28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF262E3E)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF94A3B8), size: 22),
                      onPressed: () {
                        context.read<RiskManagementBloc>().add(ChangeQuantityEvent(state.quantity - 1));
                      },
                    ),
                    Text(
                      '${state.quantity}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFF94A3B8), size: 22),
                      onPressed: () {
                        context.read<RiskManagementBloc>().add(ChangeQuantityEvent(state.quantity + 1));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRiskMethodSelector(BuildContext context, RiskManagementLoaded state) {
    final String swingText;
    final bool hasSwing = state.isBuy ? (state.swingLow != null) : (state.swingHigh != null);
    if (hasSwing) {
      final val = state.isBuy ? state.swingLow! : state.swingHigh!;
      swingText = state.isBuy ? 'Swing Low (₹${val.toStringAsFixed(2)})' : 'Swing High (₹${val.toStringAsFixed(2)})';
    } else {
      swingText = state.isBuy ? 'Swing Low (N/A)' : 'Swing High (N/A)';
    }

    final String prevText;
    final bool hasPrev = state.isBuy ? (state.prevLow != null) : (state.prevHigh != null);
    if (hasPrev) {
      final val = state.isBuy ? state.prevLow! : state.prevHigh!;
      prevText = state.isBuy ? 'Prev Low (₹${val.toStringAsFixed(2)})' : 'Prev High (₹${val.toStringAsFixed(2)})';
    } else {
      prevText = state.isBuy ? 'Prev Low (N/A)' : 'Prev High (N/A)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Risk Method',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMethodChip(
              context,
              label: '1 : 1',
              isSelected: state.selectedRiskMethod == '1:1',
              onTap: () => context.read<RiskManagementBloc>().add(const SelectRiskMethodEvent('1:1')),
            ),
            _buildMethodChip(
              context,
              label: '1 : 2 (Recommended)',
              isSelected: state.selectedRiskMethod == '1:2',
              onTap: () => context.read<RiskManagementBloc>().add(const SelectRiskMethodEvent('1:2')),
            ),
            _buildMethodChip(
              context,
              label: '1 : 3',
              isSelected: state.selectedRiskMethod == '1:3',
              onTap: () => context.read<RiskManagementBloc>().add(const SelectRiskMethodEvent('1:3')),
            ),
            _buildMethodChip(
              context,
              label: swingText,
              isSelected: state.selectedRiskMethod == 'SWING_LOW',
              onTap: () => context.read<RiskManagementBloc>().add(const SelectRiskMethodEvent('SWING_LOW')),
            ),
            _buildMethodChip(
              context,
              label: prevText,
              isSelected: state.selectedRiskMethod == 'PREV_LOW',
              onTap: () => context.read<RiskManagementBloc>().add(const SelectRiskMethodEvent('PREV_LOW')),
            ),
            _buildMethodChip(
              context,
              label: 'Custom',
              isSelected: state.selectedRiskMethod == 'CUSTOM',
              onTap: () => context.read<RiskManagementBloc>().add(const SelectRiskMethodEvent('CUSTOM')),
            ),
          ],
        ),
        if (state.selectedRiskMethod == 'SWING_LOW' || state.selectedRiskMethod == 'PREV_LOW') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Reward Ratio:',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              _buildRatioSubChip(context, label: '1 : 1', ratio: 1.0, currentRatio: state.rewardRatio),
              const SizedBox(width: 8),
              _buildRatioSubChip(context, label: '1 : 2', ratio: 2.0, currentRatio: state.rewardRatio),
              const SizedBox(width: 8),
              _buildRatioSubChip(context, label: '1 : 3', ratio: 3.0, currentRatio: state.rewardRatio),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRatioSubChip(
    BuildContext context, {
    required String label,
    required double ratio,
    required double currentRatio,
  }) {
    final isSelected = (currentRatio - ratio).abs() < 0.05;
    return GestureDetector(
      onTap: () => context.read<RiskManagementBloc>().add(SetRewardRatioEvent(ratio)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E2838),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildMethodChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF181D28),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF262E3E),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSlAndTpInputs(BuildContext context, RiskManagementLoaded state) {
    final bool isCustom = state.selectedRiskMethod == 'CUSTOM';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(
                isCustom ? Icons.edit_rounded : Icons.info_outline_rounded,
                color: isCustom ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                isCustom
                    ? 'Custom mode — edit SL & TP independently'
                    : (state.selectedRiskMethod.startsWith('1:')
                        ? 'Fixed ${state.selectedRiskMethod} ratio — editing SL auto-adjusts TP'
                        : 'Anchor mode — editing SL switches to Custom'),
                style: TextStyle(
                  color: isCustom ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            // ── Stop Loss ───────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stop Loss (₹)',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _slController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF181D28),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFEF4444)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
                      ),
                      hintText: '0.00',
                      hintStyle: const TextStyle(color: Color(0xFF4B5563)),
                    ),
                    onSubmitted: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        _lastSl = parsed;
                        context.read<RiskManagementBloc>().add(UpdateStopLossEvent(parsed));
                      }
                    },
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        _lastSl = parsed;
                        context.read<RiskManagementBloc>().add(UpdateStopLossEvent(parsed));
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // ── Target Price ────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Target Price (₹)',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF181D28),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF10B981)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
                      ),
                      hintText: '0.00',
                      hintStyle: const TextStyle(color: Color(0xFF4B5563)),
                    ),
                    onSubmitted: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        _lastTp = parsed;
                        context.read<RiskManagementBloc>().add(UpdateTargetPriceEvent(parsed));
                      }
                    },
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        _lastTp = parsed;
                        context.read<RiskManagementBloc>().add(UpdateTargetPriceEvent(parsed));
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRiskRewardPreviewCard(RiskManagementLoaded state) {
    final bool isCustomNonStandard = (state.selectedRiskMethod == 'CUSTOM' && !state.isStandardRatio);
    final Color ratioBg = isCustomNonStandard
        ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
        : const Color(0xFF38BDF8).withValues(alpha: 0.18);
    final Color ratioBorder = isCustomNonStandard ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8);
    final Color ratioTextColor = isCustomNonStandard ? const Color(0xFFFBBF24) : const Color(0xFF38BDF8);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF111726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2A3B58),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Ratio Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.analytics_outlined,
                      color: Color(0xFF38BDF8),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'RISK & REWARD ANALYSIS',
                    style: TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              // R:R Ratio Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ratioBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ratioBorder, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'R:R  ',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      state.riskRewardRatioText,
                      style: TextStyle(
                        color: ratioTextColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Side-by-side Big Highlight Cards: TOTAL RISK vs TOTAL PROFIT
          Row(
            children: [
              // ── TOTAL RISK BOX ─────────────────────────────────────────────
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2C1318),
                        const Color(0xFF1E1015),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL RISK',
                            style: TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_downward_rounded,
                              color: Color(0xFFEF4444),
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '₹${state.totalRisk.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFFFF6B6B),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${state.riskPerShare.toStringAsFixed(2)} / share',
                        style: const TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ── TOTAL PROFIT BOX ───────────────────────────────────────────
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0D2820),
                        const Color(0xFF0F1E1A),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL PROFIT',
                            style: TextStyle(
                              color: Color(0xFF6EE7B7),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              color: Color(0xFF10B981),
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '+₹${state.potentialProfit.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${state.rewardPerShare.toStringAsFixed(2)} / share',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Micro Details Row: Order Value & Method
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF182234),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF26354D), width: 0.8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Color(0xFF94A3B8), size: 15),
                    const SizedBox(width: 6),
                    const Text(
                      'Est. Order Value: ',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₹${state.estimatedOrderValue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Qty: ${state.quantity}',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarginAndFundCard(BuildContext context, RiskManagementLoaded state) {
    final bool isIntraday = state.productType.toUpperCase() == 'INTRADAY';
    final bool hasShortfall = !state.isFundSufficient && state.availableBalance > 0;
    final double displayMargin = state.requiredMargin > 0
        ? state.requiredMargin
        : (state.entryPrice * state.quantity * (isIntraday ? 0.2 : 1.0));

    final double remainingFunds = (state.availableBalance - displayMargin).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF111726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasShortfall
              ? const Color(0xFFEF4444).withValues(alpha: 0.8)
              : const Color(0xFF3B82F6).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: hasShortfall
                ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                : const Color(0xFF2563EB).withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Wallet, Leverage, and Refresh
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFF38BDF8),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'FUNDS & MARGIN CALCULATOR',
                    style: TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Leverage Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: isIntraday
                          ? const Color(0xFF10B981).withValues(alpha: 0.18)
                          : const Color(0xFF64748B).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isIntraday ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          color: isIntraday ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${state.leverage} Lev',
                          style: TextStyle(
                            color: isIntraday ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Sync / Refresh button
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      context.read<RiskManagementBloc>().add(const FetchFundLimitEvent());
                      context.read<RiskManagementBloc>().add(const CalculateMarginEvent());
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155), width: 0.8),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF94A3B8),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Two Prominent Metric Boxes: REQUIRED MARGIN vs AVAILABLE FUNDS
          Row(
            children: [
              // ── REQUIRED MARGIN BOX ────────────────────────────────────────
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF152642),
                        const Color(0xFF0F1B2E),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'REQUIRED MARGIN',
                            style: TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Text(
                            isIntraday ? 'MIS' : 'CNC',
                            style: TextStyle(
                              color: isIntraday ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      state.isMarginLoading
                          ? const SizedBox(
                              height: 28,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF38BDF8)),
                                ),
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '₹${displayMargin.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF60A5FA),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                      const SizedBox(height: 4),
                      Text(
                        isIntraday ? 'Intraday 5x applied' : '100% full margin',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ── AVAILABLE FUNDS BOX ────────────────────────────────────────
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: hasShortfall
                          ? [
                              const Color(0xFF2C1318),
                              const Color(0xFF1E1015),
                            ]
                          : [
                              const Color(0xFF0D2820),
                              const Color(0xFF0F1E1A),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasShortfall
                          ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                          : const Color(0xFF10B981).withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'AVAILABLE FUNDS',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Icon(
                            hasShortfall ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                            color: hasShortfall ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            size: 14,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          state.availableBalance > 0
                              ? '₹${state.availableBalance.toStringAsFixed(2)}'
                              : '₹0.00',
                          style: TextStyle(
                            color: hasShortfall
                                ? const Color(0xFFFF6B6B)
                                : const Color(0xFF34D399),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.availableBalance > 0
                            ? (hasShortfall
                                ? 'Shortfall: -₹${state.shortfall.toStringAsFixed(2)}'
                                : 'Rem: ₹${remainingFunds.toStringAsFixed(2)}')
                            : 'Syncing with Dhan...',
                        style: TextStyle(
                          color: hasShortfall ? const Color(0xFFF87171) : const Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bottom Dynamic Status Banner
          if (hasShortfall) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Insufficient Balance for this Order',
                          style: TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aapko ₹${state.shortfall.toStringAsFixed(2)} aur chahiye. Quantity kam karein ya Dhan account me funds transfer karein.',
                          style: const TextStyle(
                            color: Color(0xFFF87171),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.availableBalance > 0
                          ? 'Funds Sufficient: Order place hone ke baad ₹${remainingFunds.toStringAsFixed(2)} balance bachega.'
                          : 'Order placed at current live market price with protective SL/TP.',
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceSourceNotice(RiskManagementLoaded state) {
    if (state.isLive) return const SizedBox.shrink();
    final sourceLabel = state.priceSource == 'YAHOO_FINANCE'
        ? 'Yahoo Finance (delayed)'
        : (state.priceSource == 'CACHED' ? 'Cached market data' : 'Non-live feed');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF182232),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF263A54), width: 0.9),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Reference price from $sourceLabel. Super order will execute at Dhan live market price.',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationError(RiskManagementLoaded state) {
    if (state.validationError == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.validationError!,
              style: const TextStyle(
                color: Color(0xFFFCA5A5),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context, RiskManagementLoaded state) {
    final bool canSubmit = !state.isSubmitting && state.isFundSufficient;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: state.isFundSufficient
              ? const Color(0xFF10B981) // Vibrant green
              : const Color(0xFF334155), // Muted grey if insufficient
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: canSubmit
            ? () {
                context.read<RiskManagementBloc>().add(const SubmitOrderEvent());
              }
            : null,
        child: state.isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                !state.isFundSufficient
                    ? 'INSUFFICIENT FUNDS (SHORTFALL: ₹${state.shortfall.toStringAsFixed(2)})'
                    : 'CONFIRM & PLACE ORDER WITH SL/TP',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
      ),
    );
  }

  void _showOrderSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF131722),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Order Placed Successfully',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx); // Close dialog
                      Navigator.pop(context); // Return to Stock Detail Screen
                    },
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOrderFailureDialog(BuildContext context, String realError) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF131722),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Order Placement Failed',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1117),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF262E3E)),
                  ),
                  child: Text(
                    realError,
                    style: const TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontSize: 13,
                      height: 1.35,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx); // Close dialog
                    },
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

