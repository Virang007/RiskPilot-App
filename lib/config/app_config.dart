class AppConfig {
  /// Dhan Broker Backend Base URL
  ///
  /// Ek hi jagah se URL badalne ke liye:
  /// - Localhost: 'http://localhost:5000'
  /// - Network IP: 'http://10.236.238.9:5000'
  /// - Production Domain: 'https://api.yourdomain.com'
  static String baseUrl = 'http://3.105.33.175';

  // API Endpoints
  static String get generateAccessTokenUrl => '$baseUrl/app/generateAccessToken';
  static String get profileUrl => '$baseUrl/v2/profile';
  static String get superOrdersUrl => '$baseUrl/v2/super/orders';
  static String get marginCalculatorUrl => '$baseUrl/v2/margincalculator';
  static String get fundLimitUrl => '$baseUrl/v2/fundlimit';
  static String get healthUrl => '$baseUrl/api/health';
}
