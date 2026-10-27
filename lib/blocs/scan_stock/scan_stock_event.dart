import 'package:equatable/equatable.dart';

abstract class ScanStockEvent extends Equatable {
  const ScanStockEvent();

  @override
  List<Object?> get props => [];
}

/// Trigger camera capture via ImagePicker
class CaptureStockWithCameraEvent extends ScanStockEvent {
  const CaptureStockWithCameraEvent();
}

/// Trigger gallery selection via ImagePicker
class PickStockFromGalleryEvent extends ScanStockEvent {
  const PickStockFromGalleryEvent();
}

/// Process image path directly through OCR & Matching
class ProcessImageForStockEvent extends ScanStockEvent {
  final String imagePath;

  const ProcessImageForStockEvent(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

/// Reset scanner state back to initial
class ResetScanStockEvent extends ScanStockEvent {
  const ResetScanStockEvent();
}
