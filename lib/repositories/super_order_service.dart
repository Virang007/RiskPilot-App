import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'dhan_token_manager.dart';

class OrderPlacementResult {
  final bool isSuccess;
  final String? orderId;
  final String? orderStatus;
  final String? errorMessage;

  OrderPlacementResult({
    required this.isSuccess,
    this.orderId,
    this.orderStatus,
    this.errorMessage,
  });
}

class SuperOrderService {
  static final http.Client _client = http.Client();

  /// Place Super Order with Entry + Target (TP) + Stop Loss (SL)
  static Future<OrderPlacementResult> placeSuperOrder({
    required String securityId,
    required String transactionType, // 'BUY' or 'SELL'
    required String productType, // 'INTRADAY' or 'CNC'
    required int quantity,
    required double price,
    required double targetPrice,
    required double stopLossPrice,
    double trailingJump = 0.0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(DhanTokenManager.keyAccessToken);
    final clientId = prefs.getString(DhanTokenManager.keyClientId);

    if (token == null || token.isEmpty) {
      return OrderPlacementResult(
        isSuccess: false,
        errorMessage: 'Dhan Broker session expired or not connected. Please connect from Settings.',
      );
    }

    final correlationId = 'ord_${DateTime.now().millisecondsSinceEpoch}';
    final payload = {
      'dhanClientId': clientId ?? '',
      'correlationId': correlationId,
      'transactionType': transactionType,
      'exchangeSegment': 'NSE_EQ',
      'productType': productType == 'INTRADAY' ? 'INTRADAY' : 'CNC',
      'orderType': 'MARKET', // Instant execution at current market price without waiting in queue
      'securityId': securityId,
      'quantity': quantity,
      'price': 0.0, // DhanHQ requires price: 0 for MARKET orders
      'targetPrice': targetPrice,
      'stopLossPrice': stopLossPrice,
      'trailingJump': trailingJump,
    };

    final baseUrl = AppConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseUrl/v2/super/orders');

    debugPrint('[SUPER ORDER REQUEST] Placing order via backend: $uri');
    debugPrint('[SUPER ORDER PAYLOAD] ${jsonEncode(payload)}');

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'access-token': token,
          'dhanClientId': clientId ?? '',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 12));

      debugPrint('====================================================');
      debugPrint('[SUPER ORDER RESPONSE STATUS] ${response.statusCode}');
      debugPrint('[SUPER ORDER RESPONSE BODY] ${response.body}');
      debugPrint('====================================================');

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (parseErr) {
        debugPrint('[SUPER ORDER JSON PARSE ERROR] $parseErr');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final orderId = data['orderId']?.toString() ?? correlationId;
        final orderStatus = data['orderStatus']?.toString() ?? 'TRANSIT';
        debugPrint('[SUPER ORDER SUCCESS] Order ID: $orderId, Status: $orderStatus');
        return OrderPlacementResult(
          isSuccess: true,
          orderId: orderId,
          orderStatus: orderStatus,
        );
      } else {
        // Extract exact real error from DhanHQ / Backend response
        String realError = '';
        if (data.containsKey('errorMessage') && data['errorMessage'] != null && data['errorMessage'].toString().isNotEmpty) {
          realError = data['errorMessage'].toString();
        } else if (data.containsKey('message') && data['message'] != null && data['message'].toString().isNotEmpty) {
          realError = data['message'].toString();
        } else if (data.containsKey('error') && data['error'] != null && data['error'].toString().isNotEmpty) {
          realError = data['error'].toString();
        } else if (data.containsKey('data') && data['data'] is Map && data['data']['errorMessage'] != null) {
          realError = data['data']['errorMessage'].toString();
        } else if (response.body.isNotEmpty) {
          realError = response.body;
        } else {
          realError = 'Server returned HTTP ${response.statusCode}: ${response.reasonPhrase ?? "Order Rejected"}';
        }

        final errorType = data['errorType']?.toString() ?? 'OrderError';
        debugPrint('====================================================');
        debugPrint('[SUPER ORDER REAL ERROR OCCURRED]');
        debugPrint('  Error Type   : $errorType');
        debugPrint('  HTTP Code    : ${response.statusCode}');
        debugPrint('  Real Message : $realError');
        debugPrint('====================================================');

        return OrderPlacementResult(
          isSuccess: false,
          errorMessage: realError,
        );
      }
    } catch (e, stack) {
      debugPrint('====================================================');
      debugPrint('[SUPER ORDER NETWORK/SYSTEM EXCEPTION]');
      debugPrint('  Exception : $e');
      debugPrint('  Stacktrace: $stack');
      debugPrint('====================================================');
      return OrderPlacementResult(
        isSuccess: false,
        errorMessage: 'Network exception: $e',
      );
    }
  }
}
