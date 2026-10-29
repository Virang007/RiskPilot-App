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
  static const _sentinel = Object();

  final StockModel stock;
  final bool isBuy;
  final String productType; // 'INTRADAY' or 'CNC'
  final double entryPrice;
  final int quantity;
  final String selectedRiskMethod; // '1:1', '1:2', '1:3', 'SWING_LOW', 'PREV_LOW', 'CUSTOM'
  final double rewardRatio; // Configurable ratio for anchors (1.0, 2.0, 3.0)
  final double stopLoss;
  final double targetPrice;

  // Real market anchors (null if unavailable)
  final double? swingLow;
  final double? prevLow;
  final double? swingHigh;
  final double? prevHigh;

  /// True when swing/prev anchors are estimated fallbacks, not real market data.
  final bool isSwingEstimated;
  final bool isSubmitting;
  final String? submissionSuccessMsg;
  final String? submissionErrorMsg;
  final String? validationError;
  final String priceSource;
  final bool isLive;

  const RiskManagementLoaded({
    required this.stock,
    required this.isBuy,
    this.productType = 'INTRADAY',
    required this.entryPrice,
    this.quantity = 10,
    this.selectedRiskMethod = '1:2',
    this.rewardRatio = 2.0,
    required this.stopLoss,
    required this.targetPrice,
    this.swingLow,
    this.prevLow,
    this.swingHigh,
    this.prevHigh,
    this.isSwingEstimated = false,
    this.isSubmitting = false,
    this.submissionSuccessMsg,
    this.submissionErrorMsg,
    this.validationError,
    this.priceSource = 'UNKNOWN',
    this.isLive = false,
  });

  // Derived financial computations rounded to 2 decimals
  double get riskPerShare => _round((entryPrice - stopLoss).abs());

  double get rewardPerShare => _round((targetPrice - entryPrice).abs());

  double get totalRisk => _round(riskPerShare * quantity);

  double get potentialProfit => _round(rewardPerShare * quantity);

  double get estimatedOrderValue => _round(entryPrice * quantity);

  bool get isStandardRatio {
    if (riskPerShare <= 0.001) return false;
    final ratio = rewardPerShare / riskPerShare;
    return (ratio - 1.0).abs() < 0.05 ||
        (ratio - 2.0).abs() < 0.05 ||
        (ratio - 3.0).abs() < 0.05;
  }

  String get riskRewardRatioText {
    if (riskPerShare <= 0.001) return 'Invalid (Risk = 0)';
    if (isBuy && (stopLoss >= entryPrice || targetPrice <= entryPrice)) {
      return 'Invalid Direction';
    }
    if (!isBuy && (stopLoss <= entryPrice || targetPrice >= entryPrice)) {
      return 'Invalid Direction';
    }

    final ratio = rewardPerShare / riskPerShare;
    final ratioStr = ratio.toStringAsFixed(ratio % 1 == 0 ? 1 : 2);

    if (selectedRiskMethod == 'CUSTOM' && !isStandardRatio) {
      return '1 : $ratioStr (Non-standard)';
    }
    return '1 : ${ratio.toStringAsFixed(1)}';
  }

  static double _round(double val) => double.parse(val.toStringAsFixed(2));

  RiskManagementLoaded copyWith({
    StockModel? stock,
    bool? isBuy,
    String? productType,
    double? entryPrice,
    int? quantity,
    String? selectedRiskMethod,
    double? rewardRatio,
    double? stopLoss,
    double? targetPrice,
    double? swingLow,
    double? prevLow,
    double? swingHigh,
    double? prevHigh,
    bool? isSwingEstimated,
    bool? isSubmitting,
    String? priceSource,
    bool? isLive,
    Object? submissionSuccessMsg = _sentinel,
    Object? submissionErrorMsg = _sentinel,
    Object? validationError = _sentinel,
  }) {
    return RiskManagementLoaded(
      stock: stock ?? this.stock,
      isBuy: isBuy ?? this.isBuy,
      productType: productType ?? this.productType,
      entryPrice: entryPrice ?? this.entryPrice,
      quantity: quantity ?? this.quantity,
      selectedRiskMethod: selectedRiskMethod ?? this.selectedRiskMethod,
      rewardRatio: rewardRatio ?? this.rewardRatio,
      stopLoss: stopLoss ?? this.stopLoss,
      targetPrice: targetPrice ?? this.targetPrice,
      swingLow: swingLow ?? this.swingLow,
      prevLow: prevLow ?? this.prevLow,
      swingHigh: swingHigh ?? this.swingHigh,
      prevHigh: prevHigh ?? this.prevHigh,
      isSwingEstimated: isSwingEstimated ?? this.isSwingEstimated,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      priceSource: priceSource ?? this.priceSource,
      isLive: isLive ?? this.isLive,
      submissionSuccessMsg: identical(submissionSuccessMsg, _sentinel)
          ? this.submissionSuccessMsg
          : submissionSuccessMsg as String?,
      submissionErrorMsg: identical(submissionErrorMsg, _sentinel)
          ? this.submissionErrorMsg
          : submissionErrorMsg as String?,
      validationError: identical(validationError, _sentinel)
          ? this.validationError
          : validationError as String?,
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
        rewardRatio,
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
        validationError,
        priceSource,
        isLive,
      ];
}
