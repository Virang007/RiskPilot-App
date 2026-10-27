import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/stock_repository.dart';
import 'splash_event.dart';
import 'splash_state.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  final StockRepository _stockRepository;

  SplashBloc({required StockRepository stockRepository})
      : _stockRepository = stockRepository,
        super(const SplashInitial()) {
    on<StartSplashEvent>(_onStartSplash);
  }

  Future<void> _onStartSplash(
    StartSplashEvent event,
    Emitter<SplashState> emit,
  ) async {
    emit(const SplashLoading(statusMessage: 'Starting RiskPilot Engine...'));

    // Parallel execution: Pre-warm stock repository cache while holding minimum display duration
    final Future<void> minTimer = Future.delayed(const Duration(milliseconds: 2300));
    final Future<void> preWarmData = _stockRepository.loadInstruments();

    await Future.wait([minTimer, preWarmData]);

    emit(const SplashCompleted());
  }
}
