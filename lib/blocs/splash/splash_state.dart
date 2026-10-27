import 'package:equatable/equatable.dart';

abstract class SplashState extends Equatable {
  const SplashState();

  @override
  List<Object?> get props => [];
}

/// Initial resting state
class SplashInitial extends SplashState {
  const SplashInitial();
}

/// Splash animations and startup pre-warming in progress
class SplashLoading extends SplashState {
  final String statusMessage;

  const SplashLoading({this.statusMessage = 'Initializing Terminal...'});

  @override
  List<Object?> get props => [statusMessage];
}

/// Splash sequence and warm-up completed -> Ready to navigate to Home
class SplashCompleted extends SplashState {
  const SplashCompleted();
}
