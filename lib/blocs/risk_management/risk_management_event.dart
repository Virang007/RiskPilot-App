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
/// All four are optional. When null the bloc uses a clearly-labelled estimated
/// fallback (±1.45% / ±0.45% of entry) and does NOT treat it as real market data.
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

  const InitRiskManagementEvent({
    required this.stock,
    required this.isBuy,
    required this.currentPrice,
    this.swingLow,
    this.prevLow,
    this.swingHigh,
    this.prevHigh,
  });

  @override
  List<Object?> get props => [stock, isBuy, currentPrice, swingLow, prevLow, swingHigh, prevHigh];
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

class SubmitOrderEvent extends RiskManagementEvent {
  const SubmitOrderEvent();
}
