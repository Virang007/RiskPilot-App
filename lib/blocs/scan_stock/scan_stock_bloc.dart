import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../repositories/ocr_service.dart';
import '../../repositories/stock_matching_engine.dart';
import '../../repositories/stock_repository.dart';
import 'scan_stock_event.dart';
import 'scan_stock_state.dart';

class ScanStockBloc extends Bloc<ScanStockEvent, ScanStockState> {
  final OcrTextService _ocrService;
  final StockMatchingEngine _matchingEngine;
  final StockRepository _stockRepository;
  final ImagePicker _imagePicker;

  ScanStockBloc({
    required OcrTextService ocrService,
    required StockMatchingEngine matchingEngine,
    required StockRepository stockRepository,
    ImagePicker? imagePicker,
  })  : _ocrService = ocrService,
        _matchingEngine = matchingEngine,
        _stockRepository = stockRepository,
        _imagePicker = imagePicker ?? ImagePicker(),
        super(const ScanStockInitial()) {
    on<CaptureStockWithCameraEvent>(_onCaptureStockWithCamera);
    on<PickStockFromGalleryEvent>(_onPickStockFromGallery);
    on<ProcessImageForStockEvent>(_onProcessImageForStock);
    on<ResetScanStockEvent>(_onResetScanStock);
  }

  Future<void> _onCaptureStockWithCamera(
    CaptureStockWithCameraEvent event,
    Emitter<ScanStockState> emit,
  ) async {
    try {
      emit(const ScanStockCapturing());
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );

      if (image != null) {
        add(ProcessImageForStockEvent(image.path));
      } else {
        emit(const ScanStockInitial());
      }
    } catch (e) {
      emit(ScanStockFailure('Could not open camera: ${e.toString()}'));
    }
  }

  Future<void> _onPickStockFromGallery(
    PickStockFromGalleryEvent event,
    Emitter<ScanStockState> emit,
  ) async {
    try {
      emit(const ScanStockCapturing());
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image != null) {
        add(ProcessImageForStockEvent(image.path));
      } else {
        emit(const ScanStockInitial());
      }
    } catch (e) {
      emit(ScanStockFailure('Could not select image: ${e.toString()}'));
    }
  }

  Future<void> _onProcessImageForStock(
    ProcessImageForStockEvent event,
    Emitter<ScanStockState> emit,
  ) async {
    emit(ScanStockProcessing(imagePath: event.imagePath));

    try {
      // 1. Run OCR on image
      final List<String> rawLines = await _ocrService.extractTextLines(event.imagePath);

      // 2. Fetch all NSE instruments
      final allStocks = await _stockRepository.loadInstruments();

      // 3. Match recognized text with NSE stocks
      final matchResult = _matchingEngine.matchStocks(
        rawLines: rawLines,
        allStocks: allStocks,
      );

      if (matchResult.matchedStocks.isNotEmpty) {
        emit(ScanStockSuccess(
          imagePath: event.imagePath,
          rawDetectedTokens: matchResult.detectedTokens,
          matchedStocks: matchResult.matchedStocks,
        ));
      } else {
        emit(ScanStockNoMatchFound(
          imagePath: event.imagePath,
          rawDetectedTokens: matchResult.detectedTokens,
        ));
      }
    } catch (e) {
      emit(ScanStockFailure('OCR scanning failed: ${e.toString()}'));
    }
  }

  void _onResetScanStock(
    ResetScanStockEvent event,
    Emitter<ScanStockState> emit,
  ) {
    emit(const ScanStockInitial());
  }

  @override
  Future<void> close() {
    _ocrService.dispose();
    return super.close();
  }
}
