import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class DhanAuthResult {
  final bool isSuccess;
  final String? accessToken;
  final String? clientName;
  final String? clientUcc;
  final String? expiryTime;
  final String? errorTitle;
  final String? errorMessage;
  final String? errorType;
  final int? statusCode;

  DhanAuthResult({
    required this.isSuccess,
    this.accessToken,
    this.clientName,
    this.clientUcc,
    this.expiryTime,
    this.errorTitle,
    this.errorMessage,
    this.errorType,
    this.statusCode,
  });
}

class DhanTokenManager {
  static const String keyClientId = 'dhan_client_id';
  static const String keyPin = 'dhan_pin';
  static const String keyTotpSecret = 'dhan_totp_secret';
  static const String keyAccessToken = 'dhan_access_token';
  static const String keyClientName = 'dhan_client_name';
  static const String keyClientUcc = 'dhan_client_ucc';
  static const String keyTokenExpiry = 'dhan_token_expiry';
  static const String keyTokenCreatedAt = 'dhan_token_created_at';

  // Backend URL (port 5000)
  static const String defaultBackendUrl = 'http://10.236.238.9:5000';

  /// Check if token is expired based on Dhan's daily 6:00 AM cutoff
  static bool isTokenExpired({
    required String? token,
    required String? createdAtIso,
    required String? serverExpiryIso,
  }) {
    if (token == null || token.trim().isEmpty) {
      return true;
    }

    final now = DateTime.now();

    // 1. If backend gave an explicit expiryTime (e.g. 2026-10-23T16:17:25), check it
    if (serverExpiryIso != null && serverExpiryIso.isNotEmpty) {
      final serverExpiry = DateTime.tryParse(serverExpiryIso);
      if (serverExpiry != null && now.isAfter(serverExpiry)) {
        return true;
      }
    }

    // 2. Dhan tokens expire daily at 6:00 AM IST.
    if (createdAtIso != null && createdAtIso.isNotEmpty) {
      final createdAt = DateTime.tryParse(createdAtIso);
      if (createdAt != null) {
        DateTime nextSixAm = DateTime(
          createdAt.year,
          createdAt.month,
          createdAt.day,
          6,
          0,
          0,
        );

        if (createdAt.isAfter(nextSixAm) || createdAt.isAtSameMomentAs(nextSixAm)) {
          // Token created on or after 6:00 AM expires next day at 6:00 AM
          nextSixAm = nextSixAm.add(const Duration(days: 1));
        }

        if (now.isAfter(nextSixAm) || now.isAtSameMomentAs(nextSixAm)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Automatically inspects and purges token from SharedPreferences if 6:00 AM expiry has passed.
  static Future<bool> checkAndPurgeExpiredToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(keyAccessToken);
    if (token == null || token.isEmpty) {
      return true;
    }

    final createdAt = prefs.getString(keyTokenCreatedAt);
    final serverExpiry = prefs.getString(keyTokenExpiry);

    final expired = isTokenExpired(
      token: token,
      createdAtIso: createdAt,
      serverExpiryIso: serverExpiry,
    );

    if (expired) {
      debugPrint('[DHAN AUTH] ⚠️ Daily 6:00 AM token expiry triggered. Clearing stored token session.');
      await clearTokenOnly();
      return true;
    }

    return false;
  }

  /// Delete only token session (disconnect / 6 AM expiry), preserving client credentials
  static Future<void> clearTokenOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyAccessToken);
    await prefs.remove(keyTokenExpiry);
    await prefs.remove(keyTokenCreatedAt);
  }

  /// Complete disconnect
  static Future<void> disconnect() async {
    await clearTokenOnly();
  }

  /// Call backend API: POST {AppConfig.baseUrl}/app/generateAccessToken
  static Future<DhanAuthResult> connectDhan({
    required String clientId,
    required String pin,
    required String totpSecret,
    String? backendUrl,
  }) async {
    final cleanBaseUrl = (backendUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$cleanBaseUrl/app/generateAccessToken');

    debugPrint('====================================================');
    debugPrint('[DHAN AUTH REQUEST] Connecting to Dhan Broker:');
    debugPrint('  Target URL: $uri');
    debugPrint('  Client ID : $clientId');
    debugPrint('  PIN       : ****** (${pin.length} digits)');
    debugPrint('  Secret    : ${totpSecret.length > 6 ? '${totpSecret.substring(0, 4)}...${totpSecret.substring(totpSecret.length - 2)}' : '***'}');
    debugPrint('====================================================');

    try {
      final body = jsonEncode({
        'dhanClientId': clientId.trim(),
        'pin': pin.trim(),
        'totpSecret': totpSecret.trim(),
      });

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[DHAN AUTH RESPONSE] Status Code: ${response.statusCode}');
      debugPrint('[DHAN AUTH RESPONSE] Body: ${response.body}');

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (parseErr) {
        debugPrint('[DHAN AUTH ERROR] JSON Decode Failed: $parseErr');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final token = data['accessToken']?.toString();
        if (token != null && token.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();

          // Save credentials
          await prefs.setString(keyClientId, clientId.trim());
          await prefs.setString(keyPin, pin.trim());
          await prefs.setString(keyTotpSecret, totpSecret.trim());

          // Save token info
          await prefs.setString(keyAccessToken, token);
          final clientName = data['dhanClientName']?.toString() ?? '';
          final clientUcc = data['dhanClientUcc']?.toString() ?? '';
          final expiryTime = data['expiryTime']?.toString() ?? '';
          final nowIso = DateTime.now().toIso8601String();

          await prefs.setString(keyClientName, clientName);
          await prefs.setString(keyClientUcc, clientUcc);
          await prefs.setString(keyTokenExpiry, expiryTime);
          await prefs.setString(keyTokenCreatedAt, nowIso);

          debugPrint('====================================================');
          debugPrint('[DHAN AUTH SUCCESS] Access Token obtained and saved!');
          debugPrint('  Client Name: $clientName');
          debugPrint('  Client UCC : $clientUcc');
          debugPrint('  Expiry Time: $expiryTime');
          debugPrint('====================================================');

          return DhanAuthResult(
            isSuccess: true,
            accessToken: token,
            clientName: clientName,
            clientUcc: clientUcc,
            expiryTime: expiryTime,
          );
        } else {
          final errorMsg = data['errorMessage']?.toString() ??
              data['message']?.toString() ??
              'Dhan server responded without an Access Token.';
          final errorType = data['errorType']?.toString() ?? 'TokenMissing';

          debugPrint('[DHAN AUTH ERROR] $errorType: $errorMsg');

          return DhanAuthResult(
            isSuccess: false,
            errorTitle: 'Dhan Broker Error',
            errorType: errorType,
            errorMessage: errorMsg,
            statusCode: response.statusCode,
          );
        }
      } else {
        // HTTP 400 / 401 / 500 etc.
        final errorType = data['errorType']?.toString() ?? 'HttpError';
        final errorMsg = data['errorMessage']?.toString() ??
            data['message']?.toString() ??
            'Server responded with HTTP code ${response.statusCode}: ${response.reasonPhrase ?? ''}';

        debugPrint('====================================================');
        debugPrint('[DHAN BROKER/SERVER ERROR]');
        debugPrint('  HTTP Status: ${response.statusCode}');
        debugPrint('  Error Type : $errorType');
        debugPrint('  Error Msg  : $errorMsg');
        debugPrint('====================================================');

        return DhanAuthResult(
          isSuccess: false,
          errorTitle: response.statusCode >= 500 ? 'Backend Server Error' : 'Dhan Broker Error',
          errorType: errorType,
          errorMessage: errorMsg,
          statusCode: response.statusCode,
        );
      }
    } catch (e, stack) {
      debugPrint('====================================================');
      debugPrint('[DHAN AUTH EXCEPTION] Exception occurred during connection:');
      debugPrint('  Exception : $e');
      debugPrint('  Stacktrace: $stack');
      debugPrint('====================================================');

      String readableMsg = e.toString();
      String title = 'Network / Server Error';

      if (e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('SocketException')) {
        title = 'Backend Server Unreachable';
        readableMsg =
            'Backend server (http://localhost:5000) se connection establish nahi ho paya.\n\n'
            'Kripya check karein ki Dhan Backend terminal me "npm run dev" command ke sath run ho raha hai ya nahi.';
      } else if (e.toString().contains('TimeoutException')) {
        title = 'Request Timeout';
        readableMsg = 'Backend ya Dhan server ne 15 seconds me response nahi diya. Kripya thodi der baad dobara koshish karein.';
      }

      return DhanAuthResult(
        isSuccess: false,
        errorTitle: title,
        errorType: 'NetworkException',
        errorMessage: readableMsg,
      );
    }
  }
}
