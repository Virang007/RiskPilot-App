import 'package:equatable/equatable.dart';
import '../../models/stock_model.dart';

abstract class ScanStockState extends Equatable {
  const ScanStockState();

  @override
  List<Object?> get props => [];
}

/// Initial idle state
class ScanStockInitial extends ScanStockState {
  const ScanStockInitial();
}

/// Image picker or camera active
class ScanStockCapturing extends ScanStockState {
  const ScanStockCapturing();
}

/// Processing OCR & Stock Matching
class ScanStockProcessing extends ScanStockState {
  final String? imagePath;

  const ScanStockProcessing({this.imagePath});

  @override
  List<Object?> get props => [imagePath];
}

/// Successful extraction and stock identification
class ScanStockSuccess extends ScanStockState {
  final String imagePath;
  final List<String> rawDetectedTokens;
  final List<StockModel> matchedStocks;

  const ScanStockSuccess({
    required this.imagePath,
    required this.rawDetectedTokens,
    required this.matchedStocks,
  });

  @override
  List<Object?> get props => [imagePath, rawDetectedTokens, matchedStocks];
}

/// Image scanned but no matching stock found in Dhan database
class ScanStockNoMatchFound extends ScanStockState {
  final String imagePath;
  final List<String> rawDetectedTokens;

  const ScanStockNoMatchFound({
    required this.imagePath,
    required this.rawDetectedTokens,
  });

  @override
  List<Object?> get props => [imagePath, rawDetectedTokens];
}

/// Failure or exception occurred
class ScanStockFailure extends ScanStockState {
  final String errorMessage;

  const ScanStockFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
