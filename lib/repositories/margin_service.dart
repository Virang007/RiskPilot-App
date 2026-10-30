import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/fund_limit_model.dart';
import '../models/margin_calculator_model.dart';
import 'dhan_token_manager.dart';

class MarginService {
  static final http.Client _client = http.Client();

  /// Retrieve available fund limits for the current Dhan account
  static Future<FundLimitModel?> fetchFundLimits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(DhanTokenManager.keyAccessToken);
      final clientId = prefs.getString(DhanTokenManager.keyClientId);

      if (token == null || token.isEmpty) {
        debugPrint('[MARGIN SERVICE] Cannot fetch fund limit: Access token missing');
        return null;
      }

      final baseUrl = AppConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseUrl/v2/fundlimit');

      debugPrint('[MARGIN SERVICE] Fetching fund limit from $uri');

      final response = await _client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'access-token': token,
          if (clientId != null && clientId.isNotEmpty) 'dhanClientId': clientId,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        debugPrint('[MARGIN SERVICE] Fund limit response: $data');
        return FundLimitModel.fromJson(data);
      } else {
        debugPrint('[MARGIN SERVICE] Failed to fetch fund limit. Code: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[MARGIN SERVICE] Exception while fetching fund limit: $e');
      return null;
    }
  }

  /// Calculate margin requirement for an order
  static Future<MarginCalculationResult?> calculateMargin({
    required String securityId,
    required String exchangeSegment,
    required String transactionType,
    required int quantity,
    required String productType,
    required double price,
    double triggerPrice = 0.0,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(DhanTokenManager.keyAccessToken);
      final clientId = prefs.getString(DhanTokenManager.keyClientId) ?? '';

      if (token == null || token.isEmpty) {
        debugPrint('[MARGIN SERVICE] Margin calculation aborted: Access token missing');
        return _fallbackCalculation(price: price, quantity: quantity, productType: productType);
      }

      final baseUrl = AppConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseUrl/v2/margincalculator');

      final payload = {
        'dhanClientId': clientId,
        'exchangeSegment': exchangeSegment.isNotEmpty ? exchangeSegment : 'NSE_EQ',
        'transactionType': transactionType,
        'quantity': quantity,
        'productType': productType == 'INTRADAY' ? 'INTRADAY' : 'CNC',
        'securityId': securityId,
        'price': price > 0 ? price : 100.0,
        'triggerPrice': triggerPrice,
      };

      debugPrint('[MARGIN SERVICE] Requesting margin calculation: ${jsonEncode(payload)}');

      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'access-token': token,
          if (clientId.isNotEmpty) 'dhanClientId': clientId,
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        debugPrint('[MARGIN SERVICE] Margin calculated successfully: $data');
        return MarginCalculationResult.fromJson(data);
      } else {
        debugPrint('[MARGIN SERVICE] Margin calc API error: ${response.statusCode} - ${response.body}');
        return _fallbackCalculation(price: price, quantity: quantity, productType: productType);
      }
    } catch (e) {
      debugPrint('[MARGIN SERVICE] Exception in calculateMargin: $e');
      return _fallbackCalculation(price: price, quantity: quantity, productType: productType);
    }
  }

  /// Safe local fallback if API times out or is offline (e.g. 5x leverage for Intraday, 1x for Delivery)
  static MarginCalculationResult _fallbackCalculation({
    required double price,
    required int quantity,
    required String productType,
  }) {
    final double orderValue = price * quantity;
    final bool isIntraday = productType.toUpperCase() == 'INTRADAY';
    // Intraday standard equity leverage is ~5x (20% margin)
    final double estimatedMargin = isIntraday ? (orderValue / 5.0) : orderValue;
    final String estimatedLeverage = isIntraday ? '5.0x' : '1.0x';

    return MarginCalculationResult(
      totalMargin: estimatedMargin,
      spanMargin: 0.0,
      exposureMargin: estimatedMargin,
      availableBalance: 0.0,
      variableMargin: 0.0,
      insufficientBalance: 0.0,
      brokerage: 20.0,
      leverage: estimatedLeverage,
    );
  }
}

