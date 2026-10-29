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

class SuperOrderLegStatus {
  final String orderId;
  final String orderStatus;
  final String? slLegStatus;
  final String? tpLegStatus;

  const SuperOrderLegStatus({
    required this.orderId,
    required this.orderStatus,
    this.slLegStatus,
    this.tpLegStatus,
  });

  /// True only if both SL and TP legs are confirmed active by Dhan.
  bool get areBothLegsActive {
    const active = {'TRANSIT', 'PENDING', 'OPEN'};
    final sl = slLegStatus?.toUpperCase();
    final tp = tpLegStatus?.toUpperCase();
    return sl != null && active.contains(sl) && tp != null && active.contains(tp);
  }

  String get legSummary {
    return 'SL: ${slLegStatus ?? "?"} | TP: ${tpLegStatus ?? "?"}';
  }
}

class SuperOrderService {
  static final http.Client _client = http.Client();

  /// Fetch Super Order protective leg statuses from Dhan.
  ///
  /// Dhan does not expose GET /v2/super/orders/{id} via most backend proxies.
  /// Strategy:
  ///   1. Try GET /v2/orders/{orderId}  (regular order detail endpoint)
  ///   2. Try GET /v2/super/orders/{orderId}  (super-order specific, if backend supports it)
  ///   3. Return null on 404 / error — caller must tell user to verify in Dhan app.
  ///
  /// In Dhan UI "0/1 Active" means the leg EXISTS but is WAITING for the entry
  /// order to execute before becoming live. This is NORMAL for TRANSIT orders.
  static Future<SuperOrderLegStatus?> fetchSuperOrderStatus({
    required String orderId,
  }) async {
    if (orderId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(DhanTokenManager.keyAccessToken);
    final clientId = prefs.getString(DhanTokenManager.keyClientId);
    if (token == null || token.isEmpty) return null;

    final baseUrl = AppConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final headers = {
      'Content-Type': 'application/json',
      'access-token': token,
      'dhanClientId': clientId ?? '',
    };

    // Endpoint priority list — try each until one returns 200.
    final endpoints = [
      Uri.parse('$baseUrl/v2/orders/$orderId'),
      Uri.parse('$baseUrl/v2/super/orders/$orderId'),
    ];

    for (final uri in endpoints) {
      debugPrint('[SUPER ORDER STATUS] Trying: $uri');
      try {
        final response = await _client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 8));

        debugPrint('[SUPER ORDER STATUS] ${response.statusCode}: ${response.body}');

        if (response.statusCode == 404) {
          // This endpoint not available on backend — try next
          continue;
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          Map<String, dynamic> data = {};
          try {
            data = jsonDecode(response.body);
          } catch (_) {}

          final orderStatus = data['orderStatus']?.toString() ?? 'UNKNOWN';
          String? slStatus;
          String? tpStatus;

          // Dhan field names (observed from API responses)
          if (data.containsKey('stopLossOrderStatus')) {
            slStatus = data['stopLossOrderStatus']?.toString();
          }
          if (data.containsKey('targetOrderStatus')) {
            tpStatus = data['targetOrderStatus']?.toString();
          }

          // Alternative layout: legs array
          if ((slStatus == null || tpStatus == null) && data.containsKey('legs')) {
            final legs = data['legs'];
            if (legs is List) {
              for (final leg in legs) {
                if (leg is Map) {
                  final legType = (leg['legName']?.toString() ??
                      leg['orderType']?.toString() ?? '').toUpperCase();
                  final legSt = leg['orderStatus']?.toString();
                  if (legType.contains('SL') || legType.contains('STOP')) {
                    slStatus ??= legSt;
                  } else if (legType.contains('TARGET') || legType.contains('TP')) {
                    tpStatus ??= legSt;
                  }
                }
              }
            }
          }

          debugPrint('[SUPER ORDER STATUS] ✅ Order=$orderStatus SL=$slStatus TP=$tpStatus');
          return SuperOrderLegStatus(
            orderId: orderId,
            orderStatus: orderStatus,
            slLegStatus: slStatus,
            tpLegStatus: tpStatus,
          );
        }
        // Non-200, non-404 → break and return null
        break;
      } catch (e) {
        debugPrint('[SUPER ORDER STATUS] Exception on $uri: $e');
      }
    }

    debugPrint('[SUPER ORDER STATUS] Could not fetch leg status for order $orderId');
    return null;
  }

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
