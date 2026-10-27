import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/super_order_service.dart';
import 'risk_management_event.dart';
import 'risk_management_state.dart';

class RiskManagementBloc extends Bloc<RiskManagementEvent, RiskManagementState> {
  RiskManagementBloc() : super(const RiskManagementInitial()) {
    on<InitRiskManagementEvent>(_onInit);
    on<ChangeProductTypeEvent>(_onChangeProductType);
    on<ChangeQuantityEvent>(_onChangeQuantity);
    on<ChangeEntryPriceEvent>(_onChangeEntryPrice);
    on<SelectRiskMethodEvent>(_onSelectRiskMethod);
    on<UpdateStopLossEvent>(_onUpdateStopLoss);
    on<UpdateTargetPriceEvent>(_onUpdateTargetPrice);
    on<SubmitOrderEvent>(_onSubmitOrder);
  }

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------
  void _onInit(
    InitRiskManagementEvent event,
    Emitter<RiskManagementState> emit,
  ) {
    final entry = event.currentPrice > 0 ? event.currentPrice : 2545.50;
    final isBuy = event.isBuy;
    final baseRisk = entry * 0.02;

    // ── BUY SL anchors (below entry) ─────────────────────────────────────────
    // If real data is provided use it; otherwise fall back to an estimate.
    final bool buyAnchorsEstimated = event.swingLow == null && event.prevLow == null;
    final double swingLow = event.swingLow ?? _round(entry * 0.9855); // ~1.45% below
    final double prevLow  = event.prevLow  ?? _round(entry * 0.9955); // ~0.45% below

    // ── SELL SL anchors (above entry) ────────────────────────────────────────
    final bool sellAnchorsEstimated = event.swingHigh == null && event.prevHigh == null;
    final double swingHigh = event.swingHigh ?? _round(entry * 1.0145); // ~1.45% above
    final double prevHigh  = event.prevHigh  ?? _round(entry * 1.0045); // ~0.45% above

    final bool isEstimated = isBuy ? buyAnchorsEstimated : sellAnchorsEstimated;

    // Default method: 1:2
    final double stopLoss    = isBuy ? (entry - baseRisk) : (entry + baseRisk);
    final double targetPrice = isBuy ? (entry + baseRisk * 2) : (entry - baseRisk * 2);

    debugPrint('[RiskManagementBloc] Init ${isBuy ? "BUY" : "SELL"} | '
        'entry=₹$entry | SL=₹${_round(stopLoss)} | TP=₹${_round(targetPrice)} | '
        'swingLow=₹$swingLow | prevLow=₹$prevLow | '
        'swingHigh=₹$swingHigh | prevHigh=₹$prevHigh | '
        'anchorsEstimated=$isEstimated');

    emit(RiskManagementLoaded(
      stock: event.stock,
      isBuy: isBuy,
      entryPrice: entry,
      quantity: 10,
      productType: 'INTRADAY',
      selectedRiskMethod: '1:2',
      stopLoss: _round(stopLoss),
      targetPrice: _round(targetPrice),
      swingLow: swingLow,
      prevLow: prevLow,
      swingHigh: swingHigh,
      prevHigh: prevHigh,
      isSwingEstimated: isEstimated,
    ));
  }

  // ---------------------------------------------------------------------------
  // Product type
  // ---------------------------------------------------------------------------
  void _onChangeProductType(
    ChangeProductTypeEvent event,
    Emitter<RiskManagementState> emit,
  ) {
    if (state is RiskManagementLoaded) {
      final current = state as RiskManagementLoaded;
      emit(current.copyWith(productType: event.productType));
    }
  }

  // ---------------------------------------------------------------------------
  // Quantity
  // ---------------------------------------------------------------------------
  void _onChangeQuantity(
    ChangeQuantityEvent event,
    Emitter<RiskManagementState> emit,
  ) {
    if (state is RiskManagementLoaded) {
      final current = state as RiskManagementLoaded;
      final q = event.quantity < 1 ? 1 : event.quantity;
      emit(current.copyWith(quantity: q));
    }
  }

  // ---------------------------------------------------------------------------
  // Entry price change
  // Recalculate SL/TP for the current method. For CUSTOM, preserve values.
  // ---------------------------------------------------------------------------
  void _onChangeEntryPrice(
    ChangeEntryPriceEvent event,
    Emitter<RiskManagementState> emit,
  ) {
    if (state is RiskManagementLoaded) {
      final current = state as RiskManagementLoaded;
      final newEntry = event.entryPrice <= 0 ? 1.0 : event.entryPrice;

      final updated = _calculateSlTp(
        entry: newEntry,
        isBuy: current.isBuy,
        method: current.selectedRiskMethod,
        currentSl: current.stopLoss,
        currentTp: current.targetPrice,
        swingLow: current.swingLow,
        prevLow: current.prevLow,
        swingHigh: current.swingHigh,
        prevHigh: current.prevHigh,
      );

      emit(current.copyWith(
        entryPrice: newEntry,
        stopLoss: updated.sl,
        targetPrice: updated.tp,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Risk method selection
  // ---------------------------------------------------------------------------
  void _onSelectRiskMethod(
    SelectRiskMethodEvent event,
    Emitter<RiskManagementState> emit,
  ) {
    if (state is RiskManagementLoaded) {
      final current = state as RiskManagementLoaded;

      final updated = _calculateSlTp(
        entry: current.entryPrice,
        isBuy: current.isBuy,
        method: event.method,
        currentSl: current.stopLoss,
        currentTp: current.targetPrice,
        swingLow: current.swingLow,
        prevLow: current.prevLow,
        swingHigh: current.swingHigh,
        prevHigh: current.prevHigh,
      );

      emit(current.copyWith(
        selectedRiskMethod: event.method,
        stopLoss: updated.sl,
        targetPrice: updated.tp,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Manual SL update
  //
  // Behaviour:
  //   • If the active method is CUSTOM → preserve the existing TP (user set it).
  //   • If the active method is 1:1/1:2/1:3 → recalculate TP at that same ratio.
  //   • If SWING_LOW / PREV_LOW → switch to CUSTOM (user is overriding the anchor).
  //
  // Also validates that the new SL is on the correct side of entry.
  // ---------------------------------------------------------------------------
  void _onUpdateStopLoss(
    UpdateStopLossEvent event,
    Emitter<RiskManagementState> emit,
  ) {
    if (state is RiskManagementLoaded) {
      final current = state as RiskManagementLoaded;
      final newSl = _round(event.stopLoss);

      // Validation: BUY SL must be below entry; SELL SL must be above entry.
      final bool slValid = current.isBuy
          ? newSl < current.entryPrice
          : newSl > current.entryPrice;

      if (!slValid) {
        final direction = current.isBuy ? 'below' : 'above';
        final errMsg = 'Stop Loss must be $direction the entry price ₹${current.entryPrice}.';
        debugPrint('[RiskManagementBloc] ⚠️ Invalid SL: $errMsg');
        emit(current.copyWith(submissionErrorMsg: errMsg));
        return;
      }

      final newRisk = (current.entryPrice - newSl).abs();
      double newTp;
      String newMethod;

      switch (current.selectedRiskMethod) {
        case 'CUSTOM':
          // Keep the user's existing TP — do not overwrite it.
          newTp = current.targetPrice;
          newMethod = 'CUSTOM';
          break;
        case '1:1':
          newTp = current.isBuy
              ? _round(current.entryPrice + newRisk * 1)
              : _round(current.entryPrice - newRisk * 1);
          newMethod = 'CUSTOM'; // SL changed manually → switch to CUSTOM
          break;
        case '1:2':
          newTp = current.isBuy
              ? _round(current.entryPrice + newRisk * 2)
              : _round(current.entryPrice - newRisk * 2);
          newMethod = 'CUSTOM';
          break;
        case '1:3':
          newTp = current.isBuy
              ? _round(current.entryPrice + newRisk * 3)
              : _round(current.entryPrice - newRisk * 3);
          newMethod = 'CUSTOM';
          break;
        default:
          // SWING_LOW / PREV_LOW — user is manually overriding the anchor.
          newTp = current.targetPrice;
          newMethod = 'CUSTOM';
          break;
      }

      emit(current.copyWith(
        selectedRiskMethod: newMethod,
        stopLoss: newSl,
        targetPrice: newTp,
        submissionErrorMsg: null,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Manual TP update — always CUSTOM, preserve SL.
  // ---------------------------------------------------------------------------
  void _onUpdateTargetPrice(
    UpdateTargetPriceEvent event,
    Emitter<RiskManagementState> emit,
  ) {
    if (state is RiskManagementLoaded) {
      final current = state as RiskManagementLoaded;
      emit(current.copyWith(
        selectedRiskMethod: 'CUSTOM',
        targetPrice: _round(event.targetPrice),
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Submit order — validate before sending to Dhan API.
  // ---------------------------------------------------------------------------
  Future<void> _onSubmitOrder(
    SubmitOrderEvent event,
    Emitter<RiskManagementState> emit,
  ) async {
    if (state is! RiskManagementLoaded) return;
    final current = state as RiskManagementLoaded;

    // ── Pre-submission validation ─────────────────────────────────────────────
    final String? validationError = _validateOrder(current);
    if (validationError != null) {
      debugPrint('[RiskManagementBloc] ❌ Validation failed: $validationError');
      emit(current.copyWith(
        submissionErrorMsg: validationError,
        submissionSuccessMsg: null,
      ));
      return;
    }

    emit(current.copyWith(
      isSubmitting: true,
      submissionSuccessMsg: null,
      submissionErrorMsg: null,
    ));

    final result = await SuperOrderService.placeSuperOrder(
      securityId: current.stock.securityId,
      transactionType: current.isBuy ? 'BUY' : 'SELL',
      productType: current.productType,
      quantity: current.quantity,
      price: current.entryPrice,
      targetPrice: current.targetPrice,
      stopLossPrice: current.stopLoss,
    );

    if (result.isSuccess) {
      debugPrint('[RiskManagementBloc] ✅ Order #${result.orderId} placed | '
          'SL=₹${current.stopLoss} | TP=₹${current.targetPrice}');
      emit(current.copyWith(
        isSubmitting: false,
        submissionSuccessMsg:
            'Order #${result.orderId} placed at market price.\n'
            'Stop Loss: ₹${current.stopLoss}  |  Target: ₹${current.targetPrice}',
        submissionErrorMsg: null,
      ));
    } else {
      final realErr =
          result.errorMessage ?? 'Order rejected by Dhan broker. Check logs.';
      debugPrint('[RiskManagementBloc] ❌ Order failed: $realErr');
      emit(current.copyWith(
        isSubmitting: false,
        submissionErrorMsg: realErr,
        submissionSuccessMsg: null,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------
  String? _validateOrder(RiskManagementLoaded s) {
    if (s.entryPrice <= 0) return 'Entry price must be greater than zero.';
    if (s.stopLoss <= 0) return 'Stop Loss must be greater than zero.';
    if (s.targetPrice <= 0) return 'Target Price must be greater than zero.';
    if (s.quantity < 1) return 'Quantity must be at least 1.';

    if (s.isBuy) {
      if (s.stopLoss >= s.entryPrice) {
        return 'BUY Stop Loss (₹${s.stopLoss}) must be below Entry (₹${s.entryPrice}).';
      }
      if (s.targetPrice <= s.entryPrice) {
        return 'BUY Target Price (₹${s.targetPrice}) must be above Entry (₹${s.entryPrice}).';
      }
    } else {
      if (s.stopLoss <= s.entryPrice) {
        return 'SELL Stop Loss (₹${s.stopLoss}) must be above Entry (₹${s.entryPrice}).';
      }
      if (s.targetPrice >= s.entryPrice) {
        return 'SELL Target Price (₹${s.targetPrice}) must be below Entry (₹${s.entryPrice}).';
      }
    }
    return null; // valid
  }

  // ---------------------------------------------------------------------------
  // SL/TP calculator
  //
  // swingLow / prevLow  → BUY SL anchors (below entry)
  // swingHigh / prevHigh → SELL SL anchors (above entry)
  // CUSTOM              → preserve currentSl and currentTp exactly.
  // ---------------------------------------------------------------------------
  ({double sl, double tp}) _calculateSlTp({
    required double entry,
    required bool isBuy,
    required String method,
    required double currentSl,
    required double currentTp,
    required double swingLow,
    required double prevLow,
    required double swingHigh,
    required double prevHigh,
  }) {
    final baseRisk = entry * 0.02; // 2% of entry

    switch (method) {
      case '1:1':
        final sl = isBuy ? (entry - baseRisk) : (entry + baseRisk);
        final tp = isBuy ? (entry + baseRisk) : (entry - baseRisk);
        return (sl: _round(sl), tp: _round(tp));

      case '1:2':
        final sl = isBuy ? (entry - baseRisk) : (entry + baseRisk);
        final tp = isBuy ? (entry + baseRisk * 2) : (entry - baseRisk * 2);
        return (sl: _round(sl), tp: _round(tp));

      case '1:3':
        final sl = isBuy ? (entry - baseRisk) : (entry + baseRisk);
        final tp = isBuy ? (entry + baseRisk * 3) : (entry - baseRisk * 3);
        return (sl: _round(sl), tp: _round(tp));

      case 'SWING_LOW':
        if (isBuy) {
          // BUY: SL = swing low (below entry)
          final risk = (entry - swingLow).abs();
          return (sl: _round(swingLow), tp: _round(entry + risk * 2));
        } else {
          // SELL: SL = swing high (above entry)
          final risk = (swingHigh - entry).abs();
          return (sl: _round(swingHigh), tp: _round(entry - risk * 2));
        }

      case 'PREV_LOW':
        if (isBuy) {
          // BUY: SL = previous low (below entry)
          final risk = (entry - prevLow).abs();
          return (sl: _round(prevLow), tp: _round(entry + risk * 2));
        } else {
          // SELL: SL = previous high (above entry)
          final risk = (prevHigh - entry).abs();
          return (sl: _round(prevHigh), tp: _round(entry - risk * 2));
        }

      case 'CUSTOM':
      default:
        // Preserve both values exactly as the user configured them.
        return (sl: currentSl, tp: currentTp);
    }
  }

  double _round(double val) => double.parse(val.toStringAsFixed(2));
}
