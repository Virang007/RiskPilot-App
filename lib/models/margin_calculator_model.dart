class MarginCalculationRequest {
  final String dhanClientId;
  final String exchangeSegment;
  final String transactionType;
  final int quantity;
  final String productType;
  final String securityId;
  final double price;
  final double triggerPrice;

  const MarginCalculationRequest({
    required this.dhanClientId,
    required this.exchangeSegment,
    required this.transactionType,
    required this.quantity,
    required this.productType,
    required this.securityId,
    required this.price,
    this.triggerPrice = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'dhanClientId': dhanClientId,
    'exchangeSegment': exchangeSegment,
    'transactionType': transactionType,
    'quantity': quantity,
    'productType': productType,
    'securityId': securityId,
    'price': price,
    'triggerPrice': triggerPrice,
  };
}

class MarginCalculationResult {
  final double totalMargin;
  final double spanMargin;
  final double exposureMargin;
  final double availableBalance;
  final double variableMargin;
  final double insufficientBalance;
  final double brokerage;
  final String leverage;

  const MarginCalculationResult({
    required this.totalMargin,
    required this.spanMargin,
    required this.exposureMargin,
    required this.availableBalance,
    required this.variableMargin,
    required this.insufficientBalance,
    required this.brokerage,
    required this.leverage,
  });

  factory MarginCalculationResult.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    // Leverage can be string "4.00" or number 4.0 or "5.00x"
    String levStr = '1.0x';
    if (json['leverage'] != null) {
      final rawLev = json['leverage'].toString().trim();
      if (rawLev.endsWith('x') || rawLev.endsWith('X')) {
        levStr = rawLev;
      } else {
        final parsed = double.tryParse(rawLev);
        if (parsed != null && parsed > 0) {
          levStr = '${parsed.toStringAsFixed(parsed % 1 == 0 ? 0 : 1)}x';
        } else {
          levStr = rawLev;
        }
      }
    }

    return MarginCalculationResult(
      totalMargin: parseNum(json['totalMargin']),
      spanMargin: parseNum(json['spanMargin']),
      exposureMargin: parseNum(json['exposureMargin']),
      availableBalance: parseNum(json['availableBalance'] ?? json['availabelBalance']),
      variableMargin: parseNum(json['variableMargin']),
      insufficientBalance: parseNum(json['insufficientBalance']),
      brokerage: parseNum(json['brokerage']),
      leverage: levStr,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalMargin': totalMargin,
    'spanMargin': spanMargin,
    'exposureMargin': exposureMargin,
    'availableBalance': availableBalance,
    'variableMargin': variableMargin,
    'insufficientBalance': insufficientBalance,
    'brokerage': brokerage,
    'leverage': leverage,
  };
}

