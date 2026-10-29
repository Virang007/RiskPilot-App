class StockDetailData {
  final String symbol;
  final String companyName;
  final String exchange;
  final double currentPrice;
  final double change;
  final double changePercent;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? fiftyTwoWeekHigh;
  final double? fiftyTwoWeekLow;
  final String marketCapFormatted;
  final String peRatioFormatted;
  final String volumeFormatted;
  final List<double> chartPoints;
  final String timeframe;
  final bool isLive;
  final String priceSource; // 'DHAN_LIVE', 'YAHOO_FINANCE', 'YAHOO_CANDLE_CLOSE', 'CACHED', 'UNAVAILABLE'

  const StockDetailData({
    required this.symbol,
    required this.companyName,
    required this.exchange,
    required this.currentPrice,
    required this.change,
    required this.changePercent,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.fiftyTwoWeekHigh,
    this.fiftyTwoWeekLow,
    required this.marketCapFormatted,
    required this.peRatioFormatted,
    required this.volumeFormatted,
    required this.chartPoints,
    required this.timeframe,
    this.isLive = false,
    this.priceSource = 'UNKNOWN',
  });
}
