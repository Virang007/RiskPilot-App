import 'package:equatable/equatable.dart';
import '../../models/stock_model.dart';

abstract class RiskManagementState extends Equatable {
  const RiskManagementState();

  @override
  List<Object?> get props => [];
}

class RiskManagementInitial extends RiskManagementState {
  const RiskManagementInitial();
}

class RiskManagementLoaded extends RiskManagementState {
  final StockModel stock;
  final bool isBuy;
  final String productType; // 'INTRADAY' or 'CNC'
  final double entryPrice;
  final int quantity;
  final String selectedRiskMethod; // '1:1', '1:2', '1:3', 'SWING_LOW', 'PREV_LOW', 'CUSTOM'
  final double stopLoss;
  final double targetPrice;
  // BUY SL anchors (below entry)
  final double swingLow;
  final double prevLow;
  // SELL SL anchors (above entry)
  final double swingHigh;
  final double prevHigh;
  /// True when swing/prev anchors are estimated fallbacks, not real market data.
  final bool isSwingEstimated;
  final bool isSubmitting;
  final String? submissionSuccessMsg;
  final String? submissionErrorMsg;

  const RiskManagementLoaded({
    required this.stock,
    required this.isBuy,
    this.productType = 'INTRADAY',
    required this.entryPrice,
    this.quantity = 10,
    this.selectedRiskMethod = '1:2',
    required this.stopLoss,
    required this.targetPrice,
    required this.swingLow,
    required this.prevLow,
    required this.swingHigh,
    required this.prevHigh,
    this.isSwingEstimated = false,
    this.isSubmitting = false,
    this.submissionSuccessMsg,
    this.submissionErrorMsg,
  });

  // Derived financial computations
  double get riskPerShare => (entryPrice - stopLoss).abs();

  double get totalRisk => riskPerShare * quantity;

  double get potentialProfit => (targetPrice - entryPrice).abs() * quantity;

  double get estimatedOrderValue => entryPrice * quantity;

  String get riskRewardRatioText {
    if (riskPerShare <= 0.001) return '1 : 1.0';
    final rewardPerShare = (targetPrice - entryPrice).abs();
    final ratio = rewardPerShare / riskPerShare;
    return '1 : ${ratio.toStringAsFixed(1)}';
  }

  RiskManagementLoaded copyWith({
    StockModel? stock,
    bool? isBuy,
    String? productType,
    double? entryPrice,
    int? quantity,
    String? selectedRiskMethod,
    double? stopLoss,
    double? targetPrice,
    double? swingLow,
    double? prevLow,
    double? swingHigh,
    double? prevHigh,
    bool? isSwingEstimated,
    bool? isSubmitting,
    String? submissionSuccessMsg,
    String? submissionErrorMsg,
  }) {
    return RiskManagementLoaded(
      stock: stock ?? this.stock,
      isBuy: isBuy ?? this.isBuy,
      productType: productType ?? this.productType,
      entryPrice: entryPrice ?? this.entryPrice,
      quantity: quantity ?? this.quantity,
      selectedRiskMethod: selectedRiskMethod ?? this.selectedRiskMethod,
      stopLoss: stopLoss ?? this.stopLoss,
      targetPrice: targetPrice ?? this.targetPrice,
      swingLow: swingLow ?? this.swingLow,
      prevLow: prevLow ?? this.prevLow,
      swingHigh: swingHigh ?? this.swingHigh,
      prevHigh: prevHigh ?? this.prevHigh,
      isSwingEstimated: isSwingEstimated ?? this.isSwingEstimated,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionSuccessMsg: submissionSuccessMsg,
      submissionErrorMsg: submissionErrorMsg,
    );
  }

  @override
  List<Object?> get props => [
        stock,
        isBuy,
        productType,
        entryPrice,
        quantity,
        selectedRiskMethod,
        stopLoss,
        targetPrice,
        swingLow,
        prevLow,
        swingHigh,
        prevHigh,
        isSwingEstimated,
        isSubmitting,
        submissionSuccessMsg,
        submissionErrorMsg,
      ];
}
