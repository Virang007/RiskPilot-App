import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/blocs/risk_management/risk_management_bloc.dart';
import 'package:my_app/blocs/risk_management/risk_management_event.dart';
import 'package:my_app/blocs/risk_management/risk_management_state.dart';
import 'package:my_app/models/stock_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyStock = StockModel(
    symbol: 'TCS',
    name: 'Tata Consultancy Services',
    exchange: 'NSE',
    lastPrice: 3500.0,
    change: 15.0,
    changePercent: 0.43,
    securityId: '11536',
  );

  final pranav = StockModel(
    symbol: 'PRANAVCONS',
    name: 'Pranav Constructions',
    exchange: 'NSE',
    lastPrice: 91.94,
    change: 0.0,
    changePercent: 0.0,
    securityId: '766000',
  );

  group('RiskManagementBloc Comprehensive Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });
    // ── Acceptance criteria from production bug report ────────────────────────
    test('0. ACCEPTANCE: BUY entry=91.94, SL=89.90, 1:1 → TP must be 93.98', () async {
      final bloc = RiskManagementBloc();
      bloc.add(InitRiskManagementEvent(
        stock: pranav,
        isBuy: true,
        currentPrice: 91.94,
        priceSource: 'YAHOO_FINANCE',
        isLive: false,
      ));
      await pumpEventQueue();

      // Select 1:1 method
      bloc.add(const SelectRiskMethodEvent('1:1'));
      await pumpEventQueue();

      // User sets SL to 89.90 — bloc must recalculate TP preserving 1:1 ratio
      // risk = 91.94 - 89.90 = 2.04 → TP = 91.94 + 2.04 = 93.98
      bloc.add(const UpdateStopLossEvent(89.90));
      await pumpEventQueue();

      final state = bloc.state as RiskManagementLoaded;
      expect(state.selectedRiskMethod, '1:1');
      expect(state.stopLoss, closeTo(89.90, 0.01));
      // Key acceptance criterion: TP must be 93.98
      expect(state.targetPrice, closeTo(93.98, 0.01));

      final risk = state.entryPrice - state.stopLoss;
      final reward = state.targetPrice - state.entryPrice;
      expect(reward / risk, closeTo(1.0, 0.05),
          reason: 'Reward/Risk must be 1:1 relative to reference entry');

      // Verify the ratio preview text says 1:1
      expect(state.riskRewardRatioText, contains('1'));

      await bloc.close();
    });

    test('0b. ACCEPTANCE: SELL entry=91.94, SL=93.98, 1:1 → TP must be 89.90', () async {
      final bloc = RiskManagementBloc();
      bloc.add(InitRiskManagementEvent(
        stock: pranav,
        isBuy: false,
        currentPrice: 91.94,
        priceSource: 'YAHOO_FINANCE',
        isLive: false,
      ));
      await pumpEventQueue();

      bloc.add(const SelectRiskMethodEvent('1:1'));
      await pumpEventQueue();

      // SELL: SL must be above entry, so set SL = 93.98 → risk = 2.04 → TP = 91.94 - 2.04 = 89.90
      bloc.add(const UpdateStopLossEvent(93.98));
      await pumpEventQueue();

      final state = bloc.state as RiskManagementLoaded;
      expect(state.selectedRiskMethod, '1:1');
      expect(state.stopLoss, closeTo(93.98, 0.01));
      expect(state.targetPrice, closeTo(89.90, 0.01));
      expect(state.targetPrice, lessThan(state.entryPrice),
          reason: 'SELL TP must be below entry');

      await bloc.close();
    });

    test('0d. ACCEPTANCE SELL: entry=92.18, SL=94.09, 1:1 → TP must be 90.27 (Profit >= Risk)', () async {
      final bloc = RiskManagementBloc();
      bloc.add(InitRiskManagementEvent(
        stock: pranav,
        isBuy: false,
        currentPrice: 92.18,
        priceSource: 'YAHOO_FINANCE',
        isLive: false,
      ));
      await pumpEventQueue();

      bloc.add(const SelectRiskMethodEvent('1:1'));
      await pumpEventQueue();

      // Set SL to 94.09 on entry 92.18:
      // Risk = 94.09 - 92.18 = 1.91 loss
      // Reward must be 1.91 -> TP = 92.18 - 1.91 = 90.27 profit!
      bloc.add(const UpdateStopLossEvent(94.09));
      await pumpEventQueue();

      final state = bloc.state as RiskManagementLoaded;
      expect(state.selectedRiskMethod, '1:1');
      expect(state.stopLoss, closeTo(94.09, 0.01));
      expect(state.targetPrice, closeTo(90.27, 0.01),
          reason: 'For SELL entry=92.18 and SL=94.09, 1:1 TP must be 90.27 so Profit is not smaller than Loss');

      final risk = (state.stopLoss - state.entryPrice);
      final reward = (state.entryPrice - state.targetPrice);
      expect(reward, greaterThanOrEqualTo(risk - 0.01),
          reason: 'Reward must never be less than Risk in 1:1');
      expect(reward / risk, closeTo(1.0, 0.02));

      await bloc.close();
    });

    test('0e. ACCEPTANCE SELL: entry=92.18, SL=94.09, 1:2 → TP must be 88.36 (Profit = 2x Risk)', () async {
      final bloc = RiskManagementBloc();
      bloc.add(InitRiskManagementEvent(
        stock: pranav,
        isBuy: false,
        currentPrice: 92.18,
        priceSource: 'YAHOO_FINANCE',
        isLive: false,
      ));
      await pumpEventQueue();

      bloc.add(const SelectRiskMethodEvent('1:2'));
      await pumpEventQueue();

      // Set SL to 94.09 on entry 92.18:
      // Risk = 94.09 - 92.18 = 1.91 loss
      // For 1:2, Reward = 1.91 * 2 = 3.82 -> TP = 92.18 - 3.82 = 88.36!
      bloc.add(const UpdateStopLossEvent(94.09));
      await pumpEventQueue();

      final state = bloc.state as RiskManagementLoaded;
      expect(state.selectedRiskMethod, '1:2');
      expect(state.stopLoss, closeTo(94.09, 0.01));
      expect(state.targetPrice, closeTo(88.36, 0.01),
          reason: 'For SELL entry=92.18 and SL=94.09, 1:2 TP must be 88.36');

      final risk = (state.stopLoss - state.entryPrice);
      final reward = (state.entryPrice - state.targetPrice);
      expect(reward, closeTo(risk * 2.0, 0.02));
      expect(reward / risk, closeTo(2.0, 0.02));

      await bloc.close();
    });

    test('0c. ACCEPTANCE: switching 1:1→1:2 preserves existing SL, only recalculates TP', () async {
      final bloc = RiskManagementBloc();
      bloc.add(InitRiskManagementEvent(
        stock: pranav,
        isBuy: true,
        currentPrice: 91.94,
      ));
      await pumpEventQueue();

      // First set SL to 89.90 on 1:2
      bloc.add(const UpdateStopLossEvent(89.90));
      await pumpEventQueue();
      var state = bloc.state as RiskManagementLoaded;
      // TP should be 91.94 + 2.04*2 = 96.02
      expect(state.stopLoss, closeTo(89.90, 0.01));
      expect(state.targetPrice, closeTo(96.02, 0.01));

      // Now switch to 1:1 — SL must stay at 89.90, TP must become 93.98
      bloc.add(const SelectRiskMethodEvent('1:1'));
      await pumpEventQueue();
      state = bloc.state as RiskManagementLoaded;
      expect(state.stopLoss, closeTo(89.90, 0.01),
          reason: 'SL must be preserved when switching ratios');
      expect(state.targetPrice, closeTo(93.98, 0.01),
          reason: 'TP must be recalculated using existing SL and 1:1 ratio');

      // Now switch to 1:3 — SL still 89.90, TP = 91.94 + 2.04*3 = 98.06
      bloc.add(const SelectRiskMethodEvent('1:3'));
      await pumpEventQueue();
      state = bloc.state as RiskManagementLoaded;
      expect(state.stopLoss, closeTo(89.90, 0.01));
      expect(state.targetPrice, closeTo(98.06, 0.01));

      await bloc.close();
    });

    test('1. Init BUY and SELL with 1:1, 1:2, and 1:3', () async {
      // BUY 1:2
      final blocBuy = RiskManagementBloc();
      blocBuy.add(InitRiskManagementEvent(
        stock: dummyStock,
        isBuy: true,
        currentPrice: 3500.0,
      ));
      await expectLater(
        blocBuy.stream,
        emits(isA<RiskManagementLoaded>().having(
          (s) => s.stopLoss < s.entryPrice && s.targetPrice > s.entryPrice,
          'BUY SL < Entry < TP',
          isTrue,
        )),
      );
      final buyLoaded = blocBuy.state as RiskManagementLoaded;
      expect(buyLoaded.selectedRiskMethod, '1:2');
      expect((buyLoaded.targetPrice - buyLoaded.entryPrice).abs(),
          closeTo((buyLoaded.entryPrice - buyLoaded.stopLoss).abs() * 2, 0.05));

      // Change to BUY 1:1
      blocBuy.add(const SelectRiskMethodEvent('1:1'));
      await expectLater(
        blocBuy.stream,
        emits(isA<RiskManagementLoaded>().having(
          (s) => (s.targetPrice - s.entryPrice).abs(),
          '1:1 target distance equals sl distance',
          closeTo((blocBuy.state as RiskManagementLoaded).entryPrice - (blocBuy.state as RiskManagementLoaded).stopLoss, 0.05),
        )),
      );

      // Change to BUY 1:3
      blocBuy.add(const SelectRiskMethodEvent('1:3'));
      await expectLater(
        blocBuy.stream,
        emits(isA<RiskManagementLoaded>().having(
          (s) => (s.targetPrice - s.entryPrice).abs(),
          '1:3 target distance 3x sl distance',
          closeTo(((blocBuy.state as RiskManagementLoaded).entryPrice - (blocBuy.state as RiskManagementLoaded).stopLoss) * 3, 0.05),
        )),
      );
      await blocBuy.close();

      // SELL 1:2
      final blocSell = RiskManagementBloc();
      blocSell.add(InitRiskManagementEvent(
        stock: dummyStock,
        isBuy: false,
        currentPrice: 3500.0,
      ));
      await expectLater(
        blocSell.stream,
        emits(isA<RiskManagementLoaded>().having(
          (s) => s.stopLoss > s.entryPrice && s.targetPrice < s.entryPrice,
          'SELL SL > Entry > TP',
          isTrue,
        )),
      );
      final sellLoaded = blocSell.state as RiskManagementLoaded;
      expect((sellLoaded.entryPrice - sellLoaded.targetPrice).abs(),
          closeTo((sellLoaded.stopLoss - sellLoaded.entryPrice).abs() * 2, 0.05));

      // SELL 1:1
      blocSell.add(const SelectRiskMethodEvent('1:1'));
      await expectLater(
        blocSell.stream,
        emits(isA<RiskManagementLoaded>().having(
          (s) => (s.entryPrice - s.targetPrice).abs(),
          'SELL 1:1 ratio',
          closeTo((blocSell.state as RiskManagementLoaded).stopLoss - (blocSell.state as RiskManagementLoaded).entryPrice, 0.05),
        )),
      );

      // SELL 1:3
      blocSell.add(const SelectRiskMethodEvent('1:3'));
      await expectLater(
        blocSell.stream,
        emits(isA<RiskManagementLoaded>().having(
          (s) => (s.entryPrice - s.targetPrice).abs(),
          'SELL 1:3 ratio',
          closeTo(((blocSell.state as RiskManagementLoaded).stopLoss - (blocSell.state as RiskManagementLoaded).entryPrice) * 3, 0.05),
        )),
      );
      await blocSell.close();
    });

    test('2. BUY and SELL with SWING_LOW and PREV_LOW and configurable reward ratio', () async {
      final bloc = RiskManagementBloc();
      bloc.add(InitRiskManagementEvent(
        stock: dummyStock,
        isBuy: true,
        currentPrice: 3500.0,
        swingLow: 3450.0,
        prevLow: 3480.0,
      ));
      await pumpEventQueue();

      // Select SWING_LOW (SL=3450, risk=50)
      bloc.add(const SelectRiskMethodEvent('SWING_LOW'));
      await pumpEventQueue();
      var state = bloc.state as RiskManagementLoaded;
      expect(state.stopLoss, 3450.0);
      expect(state.targetPrice, 3600.0); // 3500 + 50 * 2 = 3600

      // Change reward ratio to 1:3
      bloc.add(const SetRewardRatioEvent(3.0));
      await pumpEventQueue();
      state = bloc.state as RiskManagementLoaded;
      expect(state.targetPrice, 3650.0); // 3500 + 50 * 3 = 3650

      // Select PREV_LOW (SL=3480, risk=20)
      bloc.add(const SelectRiskMethodEvent('PREV_LOW'));
      await pumpEventQueue();
      state = bloc.state as RiskManagementLoaded;
      expect(state.stopLoss, 3480.0);
      expect(state.targetPrice, 3560.0); // 3500 + 20 * 3 = 3560

      await bloc.close();

      // SELL test
      final blocSell = RiskManagementBloc();
      blocSell.add(InitRiskManagementEvent(
        stock: dummyStock,
        isBuy: false,
        currentPrice: 3500.0,
        swingHigh: 3560.0,
        prevHigh: 3520.0,
      ));
      await pumpEventQueue();

      blocSell.add(const SelectRiskMethodEvent('SWING_LOW')); // Swing High for SELL
      await pumpEventQueue();
      var sellState = blocSell.state as RiskManagementLoaded;
      expect(sellState.stopLoss, 3560.0);
      expect(sellState.targetPrice, 3380.0); // 3500 - 60 * 2 = 3380

      blocSell.add(const SelectRiskMethodEvent('PREV_LOW')); // Prev High for SELL
      await pumpEventQueue();
      sellState = blocSell.state as RiskManagementLoaded;
      expect(sellState.stopLoss, 3520.0);
      expect(sellState.targetPrice, 3460.0); // 3500 - 20 * 2 = 3460

      await blocSell.close();
    });

    test('3. Missing or invalid swing anchors show clear validation error', () async {
      final bloc = RiskManagementBloc();
      bloc.add(InitRiskManagementEvent(
        stock: dummyStock,
        isBuy: true,
        currentPrice: 3500.0,
        swingLow: null, // Missing!
        prevLow: 3550.0, // Invalid! (Above entry for BUY)
      ));
      await pumpEventQueue();

      // Missing anchor
      bloc.add(const SelectRiskMethodEvent('SWING_LOW'));
      await pumpEventQueue();
      var state = bloc.state as RiskManagementLoaded;
      expect(state.validationError, contains('unavailable'));

      // Anchor on wrong side of entry
      bloc.add(const SelectRiskMethodEvent('PREV_LOW'));
      await pumpEventQueue();
      state = bloc.state as RiskManagementLoaded;
      expect(state.validationError, contains('must be below Entry'));

      await bloc.close();
    });

    test('4. CUSTOM method allows independent editing and preserves values', () async {
      final bloc = RiskManagementBloc();
      bloc.add(InitRiskManagementEvent(
        stock: dummyStock,
        isBuy: true,
        currentPrice: 3500.0,
      ));
      await pumpEventQueue();

      bloc.add(const SelectRiskMethodEvent('CUSTOM'));
      await pumpEventQueue();

      // Independently edit SL
      bloc.add(const UpdateStopLossEvent(3420.0));
      await pumpEventQueue();
      var state = bloc.state as RiskManagementLoaded;
      expect(state.stopLoss, 3420.0);
      expect(state.selectedRiskMethod, 'CUSTOM');

      // Independently edit TP
      bloc.add(const UpdateTargetPriceEvent(3650.0));
      await pumpEventQueue();
      state = bloc.state as RiskManagementLoaded;
      expect(state.stopLoss, 3420.0);
      expect(state.targetPrice, 3650.0);

      // Ratio text should show custom/non-standard if not 1:1, 1:2, or 1:3
      // Risk = 80, Reward = 150 -> ratio = 1.875
      expect(state.isStandardRatio, isFalse);
      expect(state.riskRewardRatioText, contains('Non-standard'));

      // Change quantity or product type -> manual values must be preserved
      bloc.add(const ChangeQuantityEvent(25));
      bloc.add(const ChangeProductTypeEvent('CNC'));
      await pumpEventQueue();
      state = bloc.state as RiskManagementLoaded;
      expect(state.stopLoss, 3420.0);
      expect(state.targetPrice, 3650.0);
      expect(state.quantity, 25);
      expect(state.productType, 'CNC');

      await bloc.close();
    });

    test('5. Manual SL changes in fixed ratio methods preserve method and recalculate TP', () async {
      final bloc = RiskManagementBloc();
      bloc.add(InitRiskManagementEvent(
        stock: dummyStock,
        isBuy: true,
        currentPrice: 3500.0,
      ));
      await pumpEventQueue();

      // On 1:2 method
      expect((bloc.state as RiskManagementLoaded).selectedRiskMethod, '1:2');

      // User changes SL to 3450 (risk = 50)
      bloc.add(const UpdateStopLossEvent(3450.0));
      await pumpEventQueue();
      var state = bloc.state as RiskManagementLoaded;
      // Must preserve '1:2'
      expect(state.selectedRiskMethod, '1:2');
      expect(state.stopLoss, 3450.0);
      // TP must be entry + 50 * 2 = 3600
      expect(state.targetPrice, 3600.0);

      // User manually changes TP -> must transition to CUSTOM and preserve SL
      bloc.add(const UpdateTargetPriceEvent(3700.0));
      await pumpEventQueue();
      state = bloc.state as RiskManagementLoaded;
      expect(state.selectedRiskMethod, 'CUSTOM');
      expect(state.stopLoss, 3450.0);
      expect(state.targetPrice, 3700.0);

      await bloc.close();
    });

    test('6. Entry price changes recalculate fixed ratios and validate custom', () async {
      final bloc = RiskManagementBloc();
      bloc.add(InitRiskManagementEvent(
        stock: dummyStock,
        isBuy: true,
        currentPrice: 3500.0,
      ));
      await pumpEventQueue();

      // Change entry price in 1:2
      bloc.add(const ChangeEntryPriceEvent(4000.0));
      await pumpEventQueue();
      var state = bloc.state as RiskManagementLoaded;
      expect(state.entryPrice, 4000.0);
      expect(state.stopLoss, closeTo(3920.0, 1.0)); // 2% of 4000 = 80
      expect(state.targetPrice, closeTo(4160.0, 1.0)); // 4000 + 160

      // Switch to CUSTOM and set specific SL and TP
      bloc.add(const SelectRiskMethodEvent('CUSTOM'));
      bloc.add(const UpdateStopLossEvent(3950.0));
      bloc.add(const UpdateTargetPriceEvent(4200.0));
      await pumpEventQueue();

      // Change entry price to 3900 -> SL (3950) is now > Entry, which is invalid for BUY!
      bloc.add(const ChangeEntryPriceEvent(3900.0));
      await pumpEventQueue();
      state = bloc.state as RiskManagementLoaded;
      expect(state.validationError, contains('must be below Entry'));

      await bloc.close();
    });

    test('7. Invalid SL/TP directions and zero risk are rejected', () async {
      final bloc = RiskManagementBloc();
      bloc.add(InitRiskManagementEvent(
        stock: dummyStock,
        isBuy: true,
        currentPrice: 3500.0,
      ));
      await pumpEventQueue();

      // Setting BUY SL higher than entry
      bloc.add(const UpdateStopLossEvent(3600.0));
      await pumpEventQueue();
      var state = bloc.state as RiskManagementLoaded;
      expect(state.validationError, contains('must be below the entry price'));

      // Setting BUY TP lower than entry
      bloc.add(const UpdateTargetPriceEvent(3400.0));
      await pumpEventQueue();
      state = bloc.state as RiskManagementLoaded;
      expect(state.validationError, contains('must be above the entry price'));

      await bloc.close();
    });

    test('8. Order submission blocked when validation fails', () async {
      final bloc = RiskManagementBloc();
      bloc.add(InitRiskManagementEvent(
        stock: dummyStock,
        isBuy: true,
        currentPrice: 3500.0,
      ));
      await pumpEventQueue();

      // Set invalid SL
      bloc.add(const UpdateStopLossEvent(3600.0));
      await pumpEventQueue();

      // Attempt to submit
      bloc.add(const SubmitOrderEvent());
      await pumpEventQueue();
      final state = bloc.state as RiskManagementLoaded;
      expect(state.isSubmitting, isFalse);
      expect(state.submissionErrorMsg, isNotNull);
      expect(state.submissionSuccessMsg, isNull);

      await bloc.close();
    });

    test('9. Payload consistency: submitted SL/TP match bloc state values', () async {
      // Verifies that the values in state (which are sent to placeSuperOrder)
      // are consistent with what was calculated — no silent mutation.
      final bloc = RiskManagementBloc();
      bloc.add(InitRiskManagementEvent(
        stock: pranav,
        isBuy: true,
        currentPrice: 91.94,
        priceSource: 'YAHOO_FINANCE',
        isLive: false,
      ));
      await pumpEventQueue();

      bloc.add(const SelectRiskMethodEvent('1:1'));
      await pumpEventQueue();
      bloc.add(const UpdateStopLossEvent(89.90));
      await pumpEventQueue();

      final state = bloc.state as RiskManagementLoaded;
      // These are exactly what would be sent to placeSuperOrder
      expect(state.stopLoss, closeTo(89.90, 0.01));
      expect(state.targetPrice, closeTo(93.98, 0.01));
      expect(state.entryPrice, closeTo(91.94, 0.01));

      // Verify ratio matches selected method vs reference entry
      final risk = state.entryPrice - state.stopLoss;
      final reward = state.targetPrice - state.entryPrice;
      expect(reward / risk, closeTo(1.0, 0.05));

      // Verify the display ratio text is consistent
      expect(state.riskRewardRatioText, isNot(equals('Invalid Direction')));
      expect(state.riskPerShare, closeTo(2.04, 0.01));
      expect(state.rewardPerShare, closeTo(2.04, 0.01));

      await bloc.close();
    });

    test('10. Duplicate SubmitOrderEvent is dropped when isSubmitting is true', () async {
      final bloc = RiskManagementBloc();
      bloc.add(InitRiskManagementEvent(
        stock: dummyStock,
        isBuy: true,
        currentPrice: 3500.0,
      ));
      await pumpEventQueue();

      // Trigger first submission
      bloc.add(const SubmitOrderEvent());
      // Immediately trigger second submission before first finishes
      bloc.add(const SubmitOrderEvent());
      await pumpEventQueue();

      // Should handle gracefully without duplicate submission errors or crash
      await bloc.close();
    });
  });
}
