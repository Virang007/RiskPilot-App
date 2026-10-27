import 'package:equatable/equatable.dart';

class StockModel extends Equatable {
  final String securityId;
  final String symbol;
  final String name;
  final String exchange;
  final String segment;
  final String lotSize;
  final String tickSize;
  final double lastPrice;
  final double change;
  final double changePercent;

  const StockModel({
    required this.securityId,
    required this.symbol,
    required this.name,
    this.exchange = 'NSE',
    this.segment = 'NSE_EQ',
    this.lotSize = '1',
    this.tickSize = '0.05',
    this.lastPrice = 0.0,
    this.change = 0.0,
    this.changePercent = 0.0,
  });

  factory StockModel.fromJson(Map<String, dynamic> json) {
    return StockModel(
      securityId: json['securityId']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      exchange: json['exchange']?.toString() ?? 'NSE',
      segment: json['segment']?.toString() ?? 'NSE_EQ',
      lotSize: json['lotSize']?.toString() ?? '1',
      tickSize: json['tickSize']?.toString() ?? '0.05',
      lastPrice: (json['lastPrice'] as num?)?.toDouble() ?? 0.0,
      change: (json['change'] as num?)?.toDouble() ?? 0.0,
      changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'securityId': securityId,
      'symbol': symbol,
      'name': name,
      'exchange': exchange,
      'segment': segment,
      'lotSize': lotSize,
      'tickSize': tickSize,
      'lastPrice': lastPrice,
      'change': change,
      'changePercent': changePercent,
    };
  }

  StockModel copyWith({
    String? securityId,
    String? symbol,
    String? name,
    String? exchange,
    String? segment,
    String? lotSize,
    String? tickSize,
    double? lastPrice,
    double? change,
    double? changePercent,
  }) {
    return StockModel(
      securityId: securityId ?? this.securityId,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      exchange: exchange ?? this.exchange,
      segment: segment ?? this.segment,
      lotSize: lotSize ?? this.lotSize,
      tickSize: tickSize ?? this.tickSize,
      lastPrice: lastPrice ?? this.lastPrice,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
    );
  }

  @override
  List<Object?> get props => [securityId, symbol, name, exchange, segment];
}
