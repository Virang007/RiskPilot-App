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
    // Only sync when the method is NOT CUSTOM (auto-calculated values).
    // While user is typing in CUSTOM mode, don't overwrite.
    if (state.selectedRiskMethod != 'CUSTOM') {
      if (state.stopLoss != _lastSl) {
        _slController.text = state.stopLoss.toStringAsFixed(2);
        _lastSl = state.stopLoss;
      }
      if (state.targetPrice != _lastTp) {
        _tpController.text = state.targetPrice.toStringAsFixed(2);
        _lastTp = state.targetPrice;
      }
    } else {
      // When switching TO custom for the first time, pre-fill with current values.
      if (_lastSl != state.stopLoss && _slController.text.isEmpty) {
        _slController.text = state.stopLoss.toStringAsFixed(2);
        _lastSl = state.stopLoss;
      }
      if (_lastTp != state.targetPrice && _tpController.text.isEmpty) {
        _tpController.text = state.targetPrice.toStringAsFixed(2);
        _lastTp = state.targetPrice;
      }
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
                const SizedBox(height: 28),
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
        // Row 1: 1:1, 1:2 (Recommended), 1:3, Swing Low
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
              label: state.isBuy
                  ? 'Swing Low (₹${state.swingLow.toStringAsFixed(2)})'
                  : 'Swing High (₹${state.swingHigh.toStringAsFixed(2)})',
              isSelected: state.selectedRiskMethod == 'SWING_LOW',
              onTap: () => context.read<RiskManagementBloc>().add(const SelectRiskMethodEvent('SWING_LOW')),
            ),
            _buildMethodChip(
              context,
              label: state.isBuy
                  ? 'Prev Low (₹${state.prevLow.toStringAsFixed(2)})'
                  : 'Prev High (₹${state.prevHigh.toStringAsFixed(2)})',
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
      ],
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
        if (isCustom)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 14),
                const SizedBox(width: 6),
                Text(
                  'Custom mode — enter your own SL & TP below',
                  style: TextStyle(
                    color: const Color(0xFF2563EB),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
                  Text(
                    'Stop Loss (₹)',
                    style: TextStyle(
                      color: isCustom
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF94A3B8),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isCustom)
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFEF4444)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFEF4444), width: 1.8),
                        ),
                        hintText: '0.00',
                        hintStyle: const TextStyle(color: Color(0xFF4B5563)),
                      ),
                      onSubmitted: (val) {
                        final parsed = double.tryParse(val);
                        if (parsed != null && parsed > 0) {
                          context
                              .read<RiskManagementBloc>()
                              .add(UpdateStopLossEvent(parsed));
                        }
                      },
                      onChanged: (val) {
                        // Fire event on each change so preview updates live
                        final parsed = double.tryParse(val);
                        if (parsed != null && parsed > 0) {
                          _lastSl = parsed;
                          context
                              .read<RiskManagementBloc>()
                              .add(UpdateStopLossEvent(parsed));
                        }
                      },
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181D28),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: const Color(0xFF262E3E)),
                      ),
                      child: Text(
                        state.stopLoss.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
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
                  Text(
                    'Target Price (₹)',
                    style: TextStyle(
                      color: isCustom
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isCustom)
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFF10B981)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFF10B981), width: 1.8),
                        ),
                        hintText: '0.00',
                        hintStyle: const TextStyle(color: Color(0xFF4B5563)),
                      ),
                      onSubmitted: (val) {
                        final parsed = double.tryParse(val);
                        if (parsed != null && parsed > 0) {
                          context
                              .read<RiskManagementBloc>()
                              .add(UpdateTargetPriceEvent(parsed));
                        }
                      },
                      onChanged: (val) {
                        final parsed = double.tryParse(val);
                        if (parsed != null && parsed > 0) {
                          _lastTp = parsed;
                          context
                              .read<RiskManagementBloc>()
                              .add(UpdateTargetPriceEvent(parsed));
                        }
                      },
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181D28),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: const Color(0xFF262E3E)),
                      ),
                      child: Text(
                        state.targetPrice.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
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
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF101726),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF1E3A8A).withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RISK / REWARD PREVIEW',
            style: TextStyle(
              color: Color(0xFF38BDF8),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          _buildPreviewRow('Risk Per Share', '₹${state.riskPerShare.toStringAsFixed(2)}', Colors.white),
          const SizedBox(height: 10),
          _buildPreviewRow('Total Risk', '₹${state.totalRisk.toStringAsFixed(2)}', const Color(0xFFEF4444)),
          const SizedBox(height: 10),
          _buildPreviewRow('Potential Profit', '₹${state.potentialProfit.toStringAsFixed(2)}', const Color(0xFF10B981)),
          const SizedBox(height: 10),
          _buildPreviewRow('Risk : Reward Ratio', state.riskRewardRatioText, const Color(0xFF38BDF8)),
          const SizedBox(height: 10),
          _buildPreviewRow('Est. Order Value', '₹${state.estimatedOrderValue.toStringAsFixed(2)}', Colors.white),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton(BuildContext context, RiskManagementLoaded state) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981), // Vibrant green
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: state.isSubmitting
            ? null
            : () {
                context.read<RiskManagementBloc>().add(const SubmitOrderEvent());
              },
        child: state.isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Text(
                'CONFIRM & PLACE ORDER WITH SL/TP',
                style: TextStyle(
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

