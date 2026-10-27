import 'package:equatable/equatable.dart';

abstract class SplashEvent extends Equatable {
  const SplashEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the splash screen is first presented
class StartSplashEvent extends SplashEvent {
  const StartSplashEvent();
}
