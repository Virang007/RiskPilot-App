import 'package:equatable/equatable.dart';
import '../../models/stock_model.dart';

abstract class RiskManagementEvent extends Equatable {
  const RiskManagementEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the screen opens.
///
/// For BUY orders:  [swingLow] and [prevLow] are the SL anchors (below entry).
/// For SELL orders: [swingHigh] and [prevHigh] are the SL anchors (above entry).
/// All four are optional. When null, the bloc marks them as unavailable
/// and does NOT fabricate fake market data.
class InitRiskManagementEvent extends RiskManagementEvent {
  final StockModel stock;
  final bool isBuy;
  final double currentPrice;

  // BUY SL anchors — price levels BELOW entry for long trades
  final double? swingLow;
  final double? prevLow;

  // SELL SL anchors — price levels ABOVE entry for short trades
  final double? swingHigh;
  final double? prevHigh;

  final bool isSwingEstimated;
  final String priceSource;
  final bool isLive;

  const InitRiskManagementEvent({
    required this.stock,
    required this.isBuy,
    required this.currentPrice,
    this.priceSource = 'UNKNOWN',
    this.isLive = false,
    this.swingLow,
    this.prevLow,
    this.swingHigh,
    this.prevHigh,
    this.isSwingEstimated = false,
  });

  @override
  List<Object?> get props => [
        stock,
        isBuy,
        currentPrice,
        priceSource,
        isLive,
        swingLow,
        prevLow,
        swingHigh,
        prevHigh,
        isSwingEstimated,
      ];
}

class ChangeProductTypeEvent extends RiskManagementEvent {
  final String productType; // 'INTRADAY' or 'CNC'

  const ChangeProductTypeEvent(this.productType);

  @override
  List<Object?> get props => [productType];
}

class ChangeQuantityEvent extends RiskManagementEvent {
  final int quantity;

  const ChangeQuantityEvent(this.quantity);

  @override
  List<Object?> get props => [quantity];
}

class ChangeEntryPriceEvent extends RiskManagementEvent {
  final double entryPrice;

  const ChangeEntryPriceEvent(this.entryPrice);

  @override
  List<Object?> get props => [entryPrice];
}

class SelectRiskMethodEvent extends RiskManagementEvent {
  final String method; // '1:1', '1:2', '1:3', 'SWING_LOW', 'PREV_LOW', 'CUSTOM'

  const SelectRiskMethodEvent(this.method);

  @override
  List<Object?> get props => [method];
}

class SetRewardRatioEvent extends RiskManagementEvent {
  final double rewardRatio; // 1.0, 2.0, 3.0

  const SetRewardRatioEvent(this.rewardRatio);

  @override
  List<Object?> get props => [rewardRatio];
}

class UpdateStopLossEvent extends RiskManagementEvent {
  final double stopLoss;

  const UpdateStopLossEvent(this.stopLoss);

  @override
  List<Object?> get props => [stopLoss];
}

class UpdateTargetPriceEvent extends RiskManagementEvent {
  final double targetPrice;

  const UpdateTargetPriceEvent(this.targetPrice);

  @override
  List<Object?> get props => [targetPrice];
}

class FetchFundLimitEvent extends RiskManagementEvent {
  const FetchFundLimitEvent();
}

class CalculateMarginEvent extends RiskManagementEvent {
  const CalculateMarginEvent();
}

class SubmitOrderEvent extends RiskManagementEvent {
  const SubmitOrderEvent();
}
