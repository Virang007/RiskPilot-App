import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/stock_detail_service.dart';
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
    on<SetRewardRatioEvent>(_onSetRewardRatio);
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
    final entry = event.currentPrice > 0 ? _round(event.currentPrice) : 2545.50;
    final isBuy = event.isBuy;

    // Real anchors only — do NOT fabricate fake market structure values
    final double? swingLow = (event.swingLow != null && event.swingLow! > 0)
        ? _round(event.swingLow!)
        : null;
    final double? prevLow = (event.prevLow != null && event.prevLow! > 0)
        ? _round(event.prevLow!)
        : null;
    final double? swingHigh = (event.swingHigh != null && event.swingHigh! > 0)
        ? _round(event.swingHigh!)
        : null;
    final double? prevHigh = (event.prevHigh != null && event.prevHigh! > 0)
        ? _round(event.prevHigh!)
        : null;

    final baseRisk = _round(entry * 0.02 > 0.05 ? entry * 0.02 : 0.05);

    // Default method: 1:2
    final double stopLoss = isBuy ? _round(entry - baseRisk) : _round(entry + baseRisk);
    final double actualRisk = _round((entry - stopLoss).abs());
    final double targetPrice = isBuy
        ? _round(entry + actualRisk * 2.0)
        : _round(entry - actualRisk * 2.0);

    debugPrint('[RiskManagementBloc] Init ${isBuy ? "BUY" : "SELL"} | '
        'entry=₹$entry | SL=₹$stopLoss | TP=₹$targetPrice | '
        'swingLow=$swingLow | prevLow=$prevLow | '
        'swingHigh=$swingHigh | prevHigh=$prevHigh | '
        'anchorsEstimated=${event.isSwingEstimated}');

    emit(RiskManagementLoaded(
      stock: event.stock,
      isBuy: isBuy,
      entryPrice: entry,
      quantity: 10,
      productType: 'INTRADAY',
      selectedRiskMethod: '1:2',
      rewardRatio: 2.0,
      stopLoss: stopLoss,
      targetPrice: targetPrice,
      swingLow: swingLow,
      prevLow: prevLow,
      swingHigh: swingHigh,
      prevHigh: prevHigh,
      isSwingEstimated: event.isSwingEstimated,
      priceSource: event.priceSource,
      isLive: event.isLive,
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
  // ---------------------------------------------------------------------------
  void _onChangeEntryPrice(
    ChangeEntryPriceEvent event,
    Emitter<RiskManagementState> emit,
  ) {
    if (state is! RiskManagementLoaded) return;
    final current = state as RiskManagementLoaded;
    final newEntry = _round(event.entryPrice);

    if (!newEntry.isFinite || newEntry <= 0) {
      emit(current.copyWith(
        entryPrice: newEntry,
        validationError: 'Entry price must be greater than zero.',
      ));
      return;
    }

    if (current.selectedRiskMethod == 'CUSTOM') {
      // Preserve manual SL and TP, and validate them against updated Entry
      final isBuy = current.isBuy;
      String? err;
      if (isBuy) {
        if (current.stopLoss >= newEntry) {
          err = 'BUY Stop Loss (₹${current.stopLoss.toStringAsFixed(2)}) must be below Entry (₹${newEntry.toStringAsFixed(2)}).';
        } else if (current.targetPrice <= newEntry) {
          err = 'BUY Target Price (₹${current.targetPrice.toStringAsFixed(2)}) must be above Entry (₹${newEntry.toStringAsFixed(2)}).';
        }
      } else {
        if (current.stopLoss <= newEntry) {
          err = 'SELL Stop Loss (₹${current.stopLoss.toStringAsFixed(2)}) must be above Entry (₹${newEntry.toStringAsFixed(2)}).';
        } else if (current.targetPrice >= newEntry) {
          err = 'SELL Target Price (₹${current.targetPrice.toStringAsFixed(2)}) must be below Entry (₹${newEntry.toStringAsFixed(2)}).';
        }
      }
      emit(current.copyWith(
        entryPrice: newEntry,
        validationError: err,
        submissionErrorMsg: null,
      ));
      return;
    }

    // For fixed and swing methods, recalculate
    // Entry changed → always recompute SL from fresh baseline (do NOT preserve old SL)
    final updated = _calculateSlTp(
      entry: newEntry,
      isBuy: current.isBuy,
      method: current.selectedRiskMethod,
      currentSl: 0, // Force fresh 2% baseline; old SL is relative to old entry
      currentTp: current.targetPrice,
      swingLow: current.swingLow,
      prevLow: current.prevLow,
      swingHigh: current.swingHigh,
      prevHigh: current.prevHigh,
      rewardRatio: current.rewardRatio,
      preserveExistingSl: false,
    );

    emit(current.copyWith(
      entryPrice: newEntry,
      stopLoss: updated.sl,
      targetPrice: updated.tp,
      validationError: updated.error,
      submissionErrorMsg: null,
    ));
  }

  // ---------------------------------------------------------------------------
  // Risk method selection
  // ---------------------------------------------------------------------------
  void _onSelectRiskMethod(
    SelectRiskMethodEvent event,
    Emitter<RiskManagementState> emit,
  ) {
    if (state is! RiskManagementLoaded) return;
    final current = state as RiskManagementLoaded;

    double newRewardRatio = current.rewardRatio;
    if (event.method == '1:1') newRewardRatio = 1.0;
    if (event.method == '1:2') newRewardRatio = 2.0;
    if (event.method == '1:3') newRewardRatio = 3.0;

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
      rewardRatio: newRewardRatio,
      // Preserve user's existing SL when switching between ratio methods
      preserveExistingSl: true,
    );

    emit(current.copyWith(
      selectedRiskMethod: event.method,
      rewardRatio: newRewardRatio,
      stopLoss: updated.sl,
      targetPrice: updated.tp,
      validationError: updated.error,
      submissionErrorMsg: null,
    ));
  }

  // ---------------------------------------------------------------------------
  // Set reward ratio (for SWING_LOW and PREV_LOW)
  // ---------------------------------------------------------------------------
  void _onSetRewardRatio(
    SetRewardRatioEvent event,
    Emitter<RiskManagementState> emit,
  ) {
    if (state is! RiskManagementLoaded) return;
    final current = state as RiskManagementLoaded;
    final ratio = event.rewardRatio;

    if (current.selectedRiskMethod == 'SWING_LOW' || current.selectedRiskMethod == 'PREV_LOW') {
      final updated = _calculateSlTp(
        entry: current.entryPrice,
        isBuy: current.isBuy,
        method: current.selectedRiskMethod,
        currentSl: current.stopLoss,
        currentTp: current.targetPrice,
        swingLow: current.swingLow,
        prevLow: current.prevLow,
        swingHigh: current.swingHigh,
        prevHigh: current.prevHigh,
        rewardRatio: ratio,
        preserveExistingSl: true,
      );
      emit(current.copyWith(
        rewardRatio: ratio,
        stopLoss: updated.sl,
        targetPrice: updated.tp,
        validationError: updated.error,
      ));
    } else {
      emit(current.copyWith(rewardRatio: ratio));
    }
  }

  // ---------------------------------------------------------------------------
  // Manual SL update
  //
  // Behaviour:
  //   • Fixed ratio methods (1:1/1:2/1:3) → recalculate TP using that ratio, PRESERVE method.
  //   • CUSTOM → preserve user's existing TP, remain CUSTOM.
  //   • SWING_LOW / PREV_LOW → user overrides anchor, transition to CUSTOM.
  // ---------------------------------------------------------------------------
  void _onUpdateStopLoss(
    UpdateStopLossEvent event,
    Emitter<RiskManagementState> emit,
  ) {
    if (state is! RiskManagementLoaded) return;
    final current = state as RiskManagementLoaded;
    final newSl = _round(event.stopLoss);
    final isBuy = current.isBuy;

    // Validation: BUY SL must be below entry; SELL SL must be above entry.
    final bool slValid = isBuy ? (newSl < current.entryPrice) : (newSl > current.entryPrice);
    if (!slValid) {
      final direction = isBuy ? 'below' : 'above';
      final errMsg = 'Stop Loss must be $direction the entry price ₹${current.entryPrice.toStringAsFixed(2)}.';
      emit(current.copyWith(
        stopLoss: newSl,
        validationError: errMsg,
      ));
      return;
    }

    final newRisk = _round((current.entryPrice - newSl).abs());
    if (newRisk < 0.01) {
      emit(current.copyWith(
        stopLoss: newSl,
        validationError: 'Risk distance must be greater than zero.',
      ));
      return;
    }

    double newTp;
    String newMethod = current.selectedRiskMethod;

    switch (current.selectedRiskMethod) {
      case '1:1':
        newTp = isBuy ? _round(current.entryPrice + newRisk * 1.0) : _round(current.entryPrice - newRisk * 1.0);
        newMethod = '1:1'; // Preserve selected method
        break;
      case '1:2':
        newTp = isBuy ? _round(current.entryPrice + newRisk * 2.0) : _round(current.entryPrice - newRisk * 2.0);
        newMethod = '1:2'; // Preserve selected method
        break;
      case '1:3':
        newTp = isBuy ? _round(current.entryPrice + newRisk * 3.0) : _round(current.entryPrice - newRisk * 3.0);
        newMethod = '1:3'; // Preserve selected method
        break;
      case 'CUSTOM':
        newTp = current.targetPrice;
        newMethod = 'CUSTOM';
        break;
      default:
        // SWING_LOW / PREV_LOW — overriding anchor transitions to CUSTOM
        newTp = current.targetPrice;
        newMethod = 'CUSTOM';
        break;
    }

    // Verify TP direction is still valid
    String? valErr;
    final bool tpValid = isBuy ? (newTp > current.entryPrice) : (newTp < current.entryPrice);
    if (!tpValid) {
      final dir = isBuy ? 'above' : 'below';
      valErr = 'Target Price must be $dir the entry price ₹${current.entryPrice.toStringAsFixed(2)}.';
    }

    emit(current.copyWith(
      selectedRiskMethod: newMethod,
      stopLoss: newSl,
      targetPrice: newTp,
      validationError: valErr,
      submissionErrorMsg: null,
    ));
  }

  // ---------------------------------------------------------------------------
  // Manual TP update — always CUSTOM, preserve SL.
  // ---------------------------------------------------------------------------
  void _onUpdateTargetPrice(
    UpdateTargetPriceEvent event,
    Emitter<RiskManagementState> emit,
  ) {
    if (state is! RiskManagementLoaded) return;
    final current = state as RiskManagementLoaded;
    final newTp = _round(event.targetPrice);
    final isBuy = current.isBuy;

    final bool tpValid = isBuy ? (newTp > current.entryPrice) : (newTp < current.entryPrice);
    if (!tpValid) {
      final direction = isBuy ? 'above' : 'below';
      final errMsg = 'Target Price must be $direction the entry price ₹${current.entryPrice.toStringAsFixed(2)}.';
      emit(current.copyWith(
        selectedRiskMethod: 'CUSTOM',
        targetPrice: newTp,
        validationError: errMsg,
      ));
      return;
    }

    final targetDist = _round((newTp - current.entryPrice).abs());
    if (targetDist < 0.01) {
      emit(current.copyWith(
        selectedRiskMethod: 'CUSTOM',
        targetPrice: newTp,
        validationError: 'Target distance must be greater than zero.',
      ));
      return;
    }

    emit(current.copyWith(
      selectedRiskMethod: 'CUSTOM',
      targetPrice: newTp,
      validationError: null,
      submissionErrorMsg: null,
    ));
  }

  // ---------------------------------------------------------------------------
  // Submit order — validate thoroughly before sending to Dhan API.
  // ---------------------------------------------------------------------------
  Future<void> _onSubmitOrder(
    SubmitOrderEvent event,
    Emitter<RiskManagementState> emit,
  ) async {
    if (state is! RiskManagementLoaded) return;
    final current = state as RiskManagementLoaded;

    // Prevent duplicate orders from rapid multi-clicks
    if (current.isSubmitting) {
      debugPrint('[RiskManagementBloc] ⚠️ Ignoring duplicate SubmitOrderEvent (already submitting)');
      return;
    }

    // ── Pre-submission validation ─────────────────────────────────────────────
    final String? validationError = _validateOrder(current);
    if (validationError != null) {
      debugPrint('[RiskManagementBloc] ❌ Validation failed: $validationError');
      emit(current.copyWith(
        validationError: validationError,
        submissionErrorMsg: validationError,
        submissionSuccessMsg: null,
      ));
      return;
    }

    // Lock submission immediately to block any subsequent taps
    emit(current.copyWith(
      isSubmitting: true,
      submissionSuccessMsg: null,
      submissionErrorMsg: null,
      validationError: null,
    ));

    // ── Pre-order market price verification & real-time recalculation ─────────
    double submissionEntry = current.entryPrice;
    double submissionSl = current.stopLoss;
    double submissionTp = current.targetPrice;

    try {
      final latestData = await StockDetailService.fetchRealStockDetail(stock: current.stock);
      if (latestData.currentPrice <= 0 || latestData.priceSource == 'UNAVAILABLE') {
        final err = 'Latest market price is unavailable. Cannot verify price for order execution.';
        debugPrint('[RiskManagementBloc] ❌ Price verification failed: $err');
        emit(current.copyWith(
          isSubmitting: false,
          validationError: err,
          submissionErrorMsg: err,
        ));
        return;
      }

      final driftPct = ((latestData.currentPrice - current.entryPrice).abs() / current.entryPrice) * 100;
      if (driftPct > 3.0) {
        final err = 'Market price shifted to ₹${latestData.currentPrice.toStringAsFixed(2)} '
            '(${driftPct.toStringAsFixed(1)}% drift from ₹${current.entryPrice.toStringAsFixed(2)}). '
            'Please review SL/TP before placing order.';
        debugPrint('[RiskManagementBloc] ⚠️ High price drift detected: $err');
        emit(current.copyWith(
          isSubmitting: false,
          validationError: err,
          submissionErrorMsg: err,
        ));
        return;
      }

      // Re-align entry and recalculate SL/TP to latest market price for 1:1, 1:2, 1:3
      // This ensures profit is NEVER smaller than loss even if price drifted slightly
      // between opening the screen and clicking submit.
      submissionEntry = _round(latestData.currentPrice);
      final isBuy = current.isBuy;

      if (current.selectedRiskMethod == '1:1' ||
          current.selectedRiskMethod == '1:2' ||
          current.selectedRiskMethod == '1:3') {
        final ratio = current.selectedRiskMethod == '1:1'
            ? 1.0
            : (current.selectedRiskMethod == '1:2' ? 2.0 : 3.0);

        final slValid = isBuy
            ? (current.stopLoss < submissionEntry)
            : (current.stopLoss > submissionEntry);

        if (slValid && (submissionEntry - current.stopLoss).abs() >= 0.01) {
          // User customized or preserved SL: keep SL fixed and recalculate TP from latest entry
          submissionSl = current.stopLoss;
          final risk = _round((submissionEntry - submissionSl).abs());
          submissionTp = isBuy
              ? _round(submissionEntry + (risk * ratio))
              : _round(submissionEntry - (risk * ratio));
        } else {
          // Fresh 2% baseline from latest entry
          final baseRisk = _round(submissionEntry * 0.02 > 0.05 ? submissionEntry * 0.02 : 0.05);
          submissionSl = isBuy ? _round(submissionEntry - baseRisk) : _round(submissionEntry + baseRisk);
          final actualRisk = _round((submissionEntry - submissionSl).abs());
          submissionTp = isBuy
              ? _round(submissionEntry + (actualRisk * ratio))
              : _round(submissionEntry - (actualRisk * ratio));
        }
      } else if (current.selectedRiskMethod == 'SWING_LOW' || current.selectedRiskMethod == 'PREV_LOW') {
        final anchor = isBuy
            ? (current.selectedRiskMethod == 'SWING_LOW' ? current.swingLow : current.prevLow)
            : (current.selectedRiskMethod == 'SWING_LOW' ? current.swingHigh : current.prevHigh);
        if (anchor != null) {
          submissionSl = _round(anchor);
          final risk = _round((submissionEntry - submissionSl).abs());
          submissionTp = isBuy
              ? _round(submissionEntry + (risk * current.rewardRatio))
              : _round(submissionEntry - (risk * current.rewardRatio));
        }
      } else {
        // CUSTOM: preserve user's exact SL and TP
        submissionSl = current.stopLoss;
        submissionTp = current.targetPrice;
      }
    } catch (verifyErr) {
      debugPrint('[RiskManagementBloc] Price verification warning: $verifyErr');
    }

    final result = await SuperOrderService.placeSuperOrder(
      securityId: current.stock.securityId,
      transactionType: current.isBuy ? 'BUY' : 'SELL',
      productType: current.productType,
      quantity: current.quantity,
      price: submissionEntry,
      targetPrice: submissionTp,
      stopLossPrice: submissionSl,
    );

    if (result.isSuccess) {
      final orderId = result.orderId ?? '';
      debugPrint('[RiskManagementBloc] ✅ Order #$orderId placed | '
          'Entry=₹$submissionEntry | SL=₹$submissionSl | TP=₹$submissionTp');

      // ── Post-order: verify protective leg statuses ────────────────────────
      // Dhan creates 3 legs for a Super Order: entry + SL + TP.
      // IMPORTANT: In Dhan app, "0/1 Active" on SL/TP legs is NORMAL when the
      // entry order is in TRANSIT/PENDING. Legs become "Active" only AFTER the
      // entry order executes at market price. "0/1 Active" does NOT mean legs
      // are rejected or missing — it means they are waiting for the entry fill.
      String legWarning = '';
      String legStatusSummary = 'Leg status: checking...';
      try {
        await Future.delayed(const Duration(milliseconds: 600));
        final legStatus = await SuperOrderService.fetchSuperOrderStatus(orderId: orderId);
        if (legStatus != null) {
          legStatusSummary = legStatus.legSummary;
          debugPrint('[RiskManagementBloc] Order leg status: $legStatusSummary');
          if (!legStatus.areBothLegsActive) {
            // If SL/TP status is null/unknown, legs may simply be WAITING for entry fill
            final hasUnknownLegs = legStatus.slLegStatus == null || legStatus.tpLegStatus == null;
            legWarning = hasUnknownLegs
                ? '\n📋 SL/TP legs created. In Dhan app "0/1 Active" = legs are WAITING for entry fill (normal).'
                : '\n⚠️ ${legStatus.legSummary} — verify SL/TP legs in Dhan app.';
          } else {
            legWarning = '\n✅ Both SL and TP legs confirmed active.';
          }
        } else {
          // 404 or unavailable — this is expected if backend doesn't proxy the status endpoint
          legStatusSummary = 'Leg status: verify in Dhan app';
          legWarning = '\n📋 SL/TP legs submitted. In Dhan app:\n'
              '  • "0/1 Active" = leg WAITING for entry fill (normal for TRANSIT orders)\n'
              '  • Legs activate automatically once entry executes at market price.';
          debugPrint('[RiskManagementBloc] Leg status unavailable (404 or endpoint not proxied)');
        }
      } catch (legErr) {
        legStatusSummary = 'Leg status: verify in Dhan app';
        legWarning = '\n📋 Verify SL/TP legs in Dhan app. "0/1 Active" = WAITING for entry fill.';
        debugPrint('[RiskManagementBloc] Leg status exception: $legErr');
      }

      // IMPORTANT: For MARKET orders, Dhan executes at the live market price,
      // which differs from the Yahoo/cached reference price used to compute SL/TP.
      // SL and TP are absolute prices. The actual ratio depends on the fill price.
      // With a 0.1–0.3% fill variation, the realized ratio may differ slightly
      // from the selected ratio (e.g., 1:0.98 vs 1:1.00). This is inherent to
      // MARKET orders and cannot be eliminated without using LIMIT order type.
      final priceNote = current.isLive
          ? ''
          : '\n📌 Ref price: ${current.priceSource} (delayed). '
            'Fill at live Dhan price — ratio accurate to ~±0.3%.';

      final riskAtFill = (submissionEntry - submissionSl).abs();
      final rewardAtFill = (submissionTp - submissionEntry).abs();
      final ratioDisplay = riskAtFill > 0
          ? '1:${(rewardAtFill / riskAtFill).toStringAsFixed(2)}'
          : 'N/A';

      emit(current.copyWith(
        entryPrice: submissionEntry,
        stopLoss: submissionSl,
        targetPrice: submissionTp,
        isSubmitting: false,
        submissionSuccessMsg:
            'Order #$orderId → ${result.orderStatus ?? "TRANSIT"}\n'
            'Entry ₹${submissionEntry.toStringAsFixed(2)} | '
            'SL ₹${submissionSl.toStringAsFixed(2)} | '
            'TP ₹${submissionTp.toStringAsFixed(2)} | '
            'Ratio $ratioDisplay\n'
            '$legStatusSummary'
            '$priceNote'
            '$legWarning',
        submissionErrorMsg: null,
        validationError: null,
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
  // Complete Order Validation
  // ---------------------------------------------------------------------------
  String? _validateOrder(RiskManagementLoaded s) {
    if (!s.entryPrice.isFinite || s.entryPrice <= 0) {
      return 'Entry price must be a positive finite number.';
    }
    if (!s.stopLoss.isFinite || s.stopLoss <= 0) {
      return 'Stop Loss must be a positive finite number.';
    }
    if (!s.targetPrice.isFinite || s.targetPrice <= 0) {
      return 'Target Price must be a positive finite number.';
    }
    if (s.quantity < 1) {
      return 'Quantity must be at least 1.';
    }

    final risk = (s.entryPrice - s.stopLoss).abs();
    if (risk < 0.01) {
      return 'Risk distance must be greater than zero.';
    }

    final targetDist = (s.targetPrice - s.entryPrice).abs();
    if (targetDist < 0.01) {
      return 'Target distance must be greater than zero.';
    }

    if (s.isBuy) {
      if (s.stopLoss >= s.entryPrice) {
        return 'BUY Stop Loss (₹${s.stopLoss.toStringAsFixed(2)}) must be below Entry (₹${s.entryPrice.toStringAsFixed(2)}).';
      }
      if (s.targetPrice <= s.entryPrice) {
        return 'BUY Target Price (₹${s.targetPrice.toStringAsFixed(2)}) must be above Entry (₹${s.entryPrice.toStringAsFixed(2)}).';
      }
    } else {
      if (s.stopLoss <= s.entryPrice) {
        return 'SELL Stop Loss (₹${s.stopLoss.toStringAsFixed(2)}) must be above Entry (₹${s.entryPrice.toStringAsFixed(2)}).';
      }
      if (s.targetPrice >= s.entryPrice) {
        return 'SELL Target Price (₹${s.targetPrice.toStringAsFixed(2)}) must be below Entry (₹${s.entryPrice.toStringAsFixed(2)}).';
      }
    }

    // Fixed risk-reward ratio validation.
    //
    // IMPORTANT: For MARKET orders, the actual fill price from Dhan may differ
    // from the reference price (Yahoo Finance / cached). SL and TP are absolute
    // prices — the realized ratio depends on fill price, not this reference.
    //
    // Tolerance: 0.05 for live Dhan quotes; 0.10 for delayed/cached prices.
    // This means: for 1:1 with Yahoo price, we allow ratio between 0.90 and 1.10.
    // A 0.79:1 ratio (like the production bug) is REJECTED. A 0.98:1 is allowed
    // (inherent ~0.1–0.3% market slippage on MARKET orders is unavoidable).
    final actualRatio = targetDist / risk;
    final tolerance = s.isLive ? 0.05 : 0.10;

    if (s.selectedRiskMethod == '1:1') {
      if ((actualRatio - 1.0).abs() > tolerance || targetDist < risk - 0.02) {
        final expectedTp = s.isBuy
            ? _round(s.entryPrice + (risk * 1.0))
            : _round(s.entryPrice - (risk * 1.0));
        return 'Risk-Reward is 1:${actualRatio.toStringAsFixed(2)} — does not match 1:1 (Profit must not be less than Loss). '
            'SL ₹${s.stopLoss.toStringAsFixed(2)} → '
            'correct TP should be ₹${expectedTp.toStringAsFixed(2)}. '
            'Update TP or switch to CUSTOM.';
      }
    } else if (s.selectedRiskMethod == '1:2') {
      if ((actualRatio - 2.0).abs() > tolerance || targetDist < (risk * 2.0) - 0.02) {
        final expectedTp = s.isBuy
            ? _round(s.entryPrice + (risk * 2.0))
            : _round(s.entryPrice - (risk * 2.0));
        return 'Risk-Reward is 1:${actualRatio.toStringAsFixed(2)} — does not match 1:2. '
            'SL ₹${s.stopLoss.toStringAsFixed(2)} → '
            'correct TP should be ₹${expectedTp.toStringAsFixed(2)}. '
            'Update TP or switch to CUSTOM.';
      }
    } else if (s.selectedRiskMethod == '1:3') {
      if ((actualRatio - 3.0).abs() > tolerance || targetDist < (risk * 3.0) - 0.02) {
        final expectedTp = s.isBuy
            ? _round(s.entryPrice + (risk * 3.0))
            : _round(s.entryPrice - (risk * 3.0));
        return 'Risk-Reward is 1:${actualRatio.toStringAsFixed(2)} — does not match 1:3. '
            'SL ₹${s.stopLoss.toStringAsFixed(2)} → '
            'correct TP should be ₹${expectedTp.toStringAsFixed(2)}. '
            'Update TP or switch to CUSTOM.';
      }
    } else if (s.selectedRiskMethod == 'SWING_LOW') {
      if (s.isSwingEstimated) {
        return 'Cannot submit order with estimated swing anchor. Real market anchor required.';
      }
      final anchor = s.isBuy ? s.swingLow : s.swingHigh;
      if (anchor == null) {
        return 'Valid market anchor for ${s.isBuy ? "Swing Low" : "Swing High"} is missing.';
      }
      if ((s.stopLoss - anchor).abs() > 0.01) {
        return 'Stop Loss does not match the actual market anchor.';
      }
    } else if (s.selectedRiskMethod == 'PREV_LOW') {
      if (s.isSwingEstimated) {
        return 'Cannot submit order with estimated swing anchor. Real market anchor required.';
      }
      final anchor = s.isBuy ? s.prevLow : s.prevHigh;
      if (anchor == null) {
        return 'Valid market anchor for ${s.isBuy ? "Previous Low" : "Previous High"} is missing.';
      }
      if ((s.stopLoss - anchor).abs() > 0.01) {
        return 'Stop Loss does not match the actual market anchor.';
      }
    }

    return null; // Valid
  }

  // ---------------------------------------------------------------------------
  // SL/TP calculator
  //
  // [preserveExistingSl] — when true and the current SL is valid for the
  // direction, keep it and only recompute TP. Use this when the user switches
  // ratio/method while the entry price is unchanged (so their typed SL is kept).
  // Set to false when entry price itself changes; in that case always recompute
  // SL from the 2% baseline so the existing SL (relative to old entry) is not
  // accidentally carried over to the new price context.
  // ---------------------------------------------------------------------------
  ({double sl, double tp, String? error}) _calculateSlTp({
    required double entry,
    required bool isBuy,
    required String method,
    required double currentSl,
    required double currentTp,
    required double? swingLow,
    required double? prevLow,
    required double? swingHigh,
    required double? prevHigh,
    required double rewardRatio,
    bool preserveExistingSl = false,
  }) {
    final baseRisk = _round(entry * 0.02 > 0.05 ? entry * 0.02 : 0.05);

    // Resolve the SL to use for fixed-ratio methods.
    // When preserveExistingSl is true and the existing SL is on the correct
    // side of entry with a meaningful distance, use it; otherwise fall back
    // to the fresh 2%-based baseline.
    double resolveSl(double fallback) {
      if (!preserveExistingSl) return _round(fallback);
      final slValid = isBuy ? (currentSl > 0 && currentSl < entry)
                             : (currentSl > 0 && currentSl > entry);
      final slDistance = (entry - currentSl).abs();
      if (slValid && slDistance >= 0.01) return _round(currentSl);
      return _round(fallback);
    }

    switch (method) {
      case '1:1': {
        final sl = resolveSl(isBuy ? entry - baseRisk : entry + baseRisk);
        final actualRisk = _round((entry - sl).abs());
        final tp = isBuy ? _round(entry + actualRisk * 1.0) : _round(entry - actualRisk * 1.0);
        return (sl: sl, tp: tp, error: null);
      }

      case '1:2': {
        final sl = resolveSl(isBuy ? entry - baseRisk : entry + baseRisk);
        final actualRisk = _round((entry - sl).abs());
        final tp = isBuy ? _round(entry + actualRisk * 2.0) : _round(entry - actualRisk * 2.0);
        return (sl: sl, tp: tp, error: null);
      }

      case '1:3': {
        final sl = resolveSl(isBuy ? entry - baseRisk : entry + baseRisk);
        final actualRisk = _round((entry - sl).abs());
        final tp = isBuy ? _round(entry + actualRisk * 3.0) : _round(entry - actualRisk * 3.0);
        return (sl: sl, tp: tp, error: null);
      }

      case 'SWING_LOW': {
        final anchor = isBuy ? swingLow : swingHigh;
        final anchorName = isBuy ? 'Swing Low' : 'Swing High';
        if (anchor == null) {
          return (sl: currentSl, tp: currentTp, error: 'Valid market anchor for $anchorName is unavailable.');
        }
        if (isBuy && anchor >= entry) {
          return (sl: anchor, tp: currentTp, error: 'Swing Low (₹$anchor) must be below Entry price (₹$entry).');
        }
        if (!isBuy && anchor <= entry) {
          return (sl: anchor, tp: currentTp, error: 'Swing High (₹$anchor) must be above Entry price (₹$entry).');
        }
        final sl = _round(anchor);
        final risk = _round((entry - sl).abs());
        if (risk < 0.01) {
          return (sl: sl, tp: currentTp, error: 'Risk distance must be greater than zero.');
        }
        final tp = isBuy ? _round(entry + risk * rewardRatio) : _round(entry - risk * rewardRatio);
        return (sl: sl, tp: tp, error: null);
      }

      case 'PREV_LOW': {
        final anchor = isBuy ? prevLow : prevHigh;
        final anchorName = isBuy ? 'Previous Low' : 'Previous High';
        if (anchor == null) {
          return (sl: currentSl, tp: currentTp, error: 'Valid market anchor for $anchorName is unavailable.');
        }
        if (isBuy && anchor >= entry) {
          return (sl: anchor, tp: currentTp, error: 'Previous Low (₹$anchor) must be below Entry price (₹$entry).');
        }
        if (!isBuy && anchor <= entry) {
          return (sl: anchor, tp: currentTp, error: 'Previous High (₹$anchor) must be above Entry price (₹$entry).');
        }
        final sl = _round(anchor);
        final risk = _round((entry - sl).abs());
        if (risk < 0.01) {
          return (sl: sl, tp: currentTp, error: 'Risk distance must be greater than zero.');
        }
        final tp = isBuy ? _round(entry + risk * rewardRatio) : _round(entry - risk * rewardRatio);
        return (sl: sl, tp: tp, error: null);
      }

      case 'CUSTOM':
      default:
        return (sl: _round(currentSl), tp: _round(currentTp), error: null);
    }
  }

  double _round(double val) => double.parse(val.toStringAsFixed(2));
}
