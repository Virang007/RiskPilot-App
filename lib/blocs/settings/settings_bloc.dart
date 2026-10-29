import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../repositories/dhan_token_manager.dart';
import '../../repositories/ec2_control_service.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  Timer? _expiryCheckTimer;
  Timer? _ec2PollingTimer;

  SettingsBloc() : super(const SettingsState()) {
    on<LoadSettingsEvent>(_onLoadSettings);
    on<CheckExpirySilentEvent>(_onCheckExpirySilent);
    on<ConnectDhanEvent>(_onConnectDhan);
    on<DisconnectDhanEvent>(_onDisconnectDhan);
    on<TogglePinVisibilityEvent>(_onTogglePinVisibility);
    on<ToggleSecretVisibilityEvent>(_onToggleSecretVisibility);
    on<RefreshEc2StatusEvent>(_onRefreshEc2Status);
    on<StartEc2MachineEvent>(_onStartEc2Machine);
    on<StopEc2MachineEvent>(_onStopEc2Machine);
    on<SaveAwsConfigEvent>(_onSaveAwsConfig);
    on<ClearMessagesEvent>(_onClearMessages);

    // Periodically check Dhan token expiry (Daily 6 AM rule) every minute
    _expiryCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      add(const CheckExpirySilentEvent());
    });
  }

  Future<void> _onLoadSettings(
    LoadSettingsEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(status: SettingsStatus.loading));

    await DhanTokenManager.checkAndPurgeExpiredToken();
    final prefs = await SharedPreferences.getInstance();

    final clientId = prefs.getString(DhanTokenManager.keyClientId) ?? '';
    final pin = prefs.getString(DhanTokenManager.keyPin) ?? '';
    final totpSecret = prefs.getString(DhanTokenManager.keyTotpSecret) ?? '';

    final accessToken = prefs.getString(DhanTokenManager.keyAccessToken);
    final clientName = prefs.getString(DhanTokenManager.keyClientName);
    final clientUcc = prefs.getString(DhanTokenManager.keyClientUcc);
    final tokenExpiry = prefs.getString(DhanTokenManager.keyTokenExpiry);

    emit(state.copyWith(
      status: SettingsStatus.loaded,
      clientId: clientId,
      pin: pin,
      totpSecret: totpSecret,
      accessToken: accessToken,
      clientName: clientName,
      clientUcc: clientUcc,
      tokenExpiry: tokenExpiry,
      clearDhanError: true,
      clearDhanSuccess: true,
    ));

    // Also trigger initial EC2 status check
    add(const RefreshEc2StatusEvent(silent: true));
  }

  Future<void> _onCheckExpirySilent(
    CheckExpirySilentEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final purged = await DhanTokenManager.checkAndPurgeExpiredToken();
    if (purged && state.accessToken != null) {
      emit(state.copyWith(
        clearAccessToken: true,
        clearClientName: true,
        clearClientUcc: true,
        clearTokenExpiry: true,
        dhanErrorMessage: 'Dhan session expired (Daily 6 AM cycle). Please reconnect.',
      ));
    }
  }

  Future<void> _onConnectDhan(
    ConnectDhanEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final cleanClientId = event.clientId.trim();
    final cleanPin = event.pin.trim();
    final cleanSecret = event.totpSecret.trim();

    // Persist credentials to SharedPreferences immediately so user never has to retype
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(DhanTokenManager.keyClientId, cleanClientId);
      await prefs.setString(DhanTokenManager.keyPin, cleanPin);
      await prefs.setString(DhanTokenManager.keyTotpSecret, cleanSecret);
    } catch (_) {}

    emit(state.copyWith(
      isConnecting: true,
      clientId: cleanClientId,
      pin: cleanPin,
      totpSecret: cleanSecret,
      clearDhanError: true,
      clearDhanSuccess: true,
    ));

    final result = await DhanTokenManager.connectDhan(
      clientId: cleanClientId,
      pin: cleanPin,
      totpSecret: cleanSecret,
    );

    if (result.isSuccess && result.accessToken != null) {
      emit(state.copyWith(
        isConnecting: false,
        accessToken: result.accessToken,
        clientName: result.clientName,
        clientUcc: result.clientUcc,
        tokenExpiry: result.expiryTime,
        clientId: cleanClientId,
        pin: cleanPin,
        totpSecret: cleanSecret,
        dhanSuccessMessage: 'Dhan Broker successfully connected! Token saved.',
        clearDhanError: true,
      ));
    } else {
      emit(state.copyWith(
        isConnecting: false,
        clientId: cleanClientId,
        pin: cleanPin,
        totpSecret: cleanSecret,
        dhanErrorTitle: result.errorTitle ?? 'Authentication Error',
        dhanErrorMessage: result.errorMessage ?? 'Failed to authenticate with Dhan Broker.',
        dhanErrorType: result.errorType,
        dhanStatusCode: result.statusCode,
        clearDhanSuccess: true,
      ));
    }
  }

  Future<void> _onDisconnectDhan(
    DisconnectDhanEvent event,
    Emitter<SettingsState> emit,
  ) async {
    await DhanTokenManager.disconnect();
    emit(state.copyWith(
      clearAccessToken: true,
      clearClientName: true,
      clearClientUcc: true,
      clearTokenExpiry: true,
      dhanSuccessMessage: 'Dhan Broker disconnected. Token removed.',
      clearDhanError: true,
      clearEc2Feedback: true,
    ));
  }

  void _onClearMessages(
    ClearMessagesEvent event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(
      clearDhanError: true,
      clearDhanSuccess: true,
      clearEc2Feedback: true,
    ));
  }

  void _onTogglePinVisibility(
    TogglePinVisibilityEvent event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(isPinObscured: !state.isPinObscured));
  }

  void _onToggleSecretVisibility(
    ToggleSecretVisibilityEvent event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(isSecretObscured: !state.isSecretObscured));
  }

  Future<void> _onRefreshEc2Status(
    RefreshEc2StatusEvent event,
    Emitter<SettingsState> emit,
  ) async {
    if (!event.silent) {
      emit(state.copyWith(isLoadingEc2: true));
    }

    try {
      final status = await Ec2ControlService.getStatus();

      // If status is transitioning (stopping or pending), keep polling active
      if (status.isStopping || status.isPending) {
        if (_ec2PollingTimer == null || !_ec2PollingTimer!.isActive) {
          _startEc2Polling();
        }
      } else if (status.isStopped || status.isRunning) {
        // Reached final stable state: stop transition polling
        _ec2PollingTimer?.cancel();
      }

      emit(state.copyWith(
        isLoadingEc2: false,
        ec2ActionStatus: Ec2ActionStatus.idle,
        ec2Status: status,
        clearEc2Feedback: true,
        clearDhanError: true,
        clearDhanSuccess: true,
        ec2LastOutput: status.rawOutput.isNotEmpty ? status.rawOutput : state.ec2LastOutput,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingEc2: false,
        ec2ActionStatus: Ec2ActionStatus.idle,
        clearEc2Feedback: true,
        clearDhanError: true,
        clearDhanSuccess: true,
        ec2LastOutput: 'Error fetching EC2 status: $e',
      ));
    }
  }

  Future<void> _onStartEc2Machine(
    StartEc2MachineEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(
      ec2ActionStatus: Ec2ActionStatus.starting,
      clearEc2Feedback: true,
    ));

    try {
      final result = await Ec2ControlService.startInstance();
      final timeStr = _getCurrentTimeFormatted();
      final log = '[$timeStr] ${result.message}\n${result.rawOutput}';

      // Immediately reflect "pending" state in ec2Status so UI updates right away
      final pendingStatus = Ec2Status(
        instanceId: state.ec2Status?.instanceId ?? Ec2ControlService.defaultInstanceId,
        region: state.ec2Status?.region ?? Ec2ControlService.defaultRegion,
        state: 'pending',
        publicIp: state.ec2Status?.publicIp,
        isBackendHealthy: false,
        rawOutput: log,
        timestamp: DateTime.now(),
      );

      emit(state.copyWith(
        ec2ActionStatus: Ec2ActionStatus.idle,
        ec2Status: pendingStatus,
        isEc2Success: result.success,
        ec2FeedbackMessage: result.message,
        ec2LastOutput: log,
      ));

      if (result.success) {
        _startEc2Polling();
      }
    } catch (e) {
      emit(state.copyWith(
        ec2ActionStatus: Ec2ActionStatus.idle,
        isEc2Success: false,
        ec2FeedbackMessage: 'Failed to start EC2 machine: $e',
        ec2LastOutput: e.toString(),
      ));
    }
  }

  Future<void> _onStopEc2Machine(
    StopEc2MachineEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(
      ec2ActionStatus: Ec2ActionStatus.stopping,
      clearEc2Feedback: true,
    ));

    try {
      final result = await Ec2ControlService.stopInstance();
      final timeStr = _getCurrentTimeFormatted();
      final log = '[$timeStr] ${result.message}\n${result.rawOutput}';

      // Immediately reflect "stopping" state in ec2Status so UI updates right away
      final stoppingStatus = Ec2Status(
        instanceId: state.ec2Status?.instanceId ?? Ec2ControlService.defaultInstanceId,
        region: state.ec2Status?.region ?? Ec2ControlService.defaultRegion,
        state: 'stopping',
        publicIp: state.ec2Status?.publicIp,
        isBackendHealthy: false,
        rawOutput: log,
        timestamp: DateTime.now(),
      );

      emit(state.copyWith(
        ec2ActionStatus: Ec2ActionStatus.idle,
        ec2Status: stoppingStatus,
        isEc2Success: result.success,
        ec2FeedbackMessage: result.message,
        ec2LastOutput: log,
      ));

      if (result.success) {
        _startEc2Polling();
      }
    } catch (e) {
      emit(state.copyWith(
        ec2ActionStatus: Ec2ActionStatus.idle,
        isEc2Success: false,
        ec2FeedbackMessage: 'Failed to stop EC2 machine: $e',
        ec2LastOutput: e.toString(),
      ));
    }
  }

  Future<void> _onSaveAwsConfig(
    SaveAwsConfigEvent event,
    Emitter<SettingsState> emit,
  ) async {
    await Ec2ControlService.saveConfig(
      instanceId: event.instanceId,
      region: event.region,
      awsAccessKey: event.awsAccessKey,
      awsSecretKey: event.awsSecretKey,
    );
    add(const RefreshEc2StatusEvent());
  }

  void _startEc2Polling() {
    _ec2PollingTimer?.cancel();
    int ticks = 0;
    _ec2PollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      ticks++;
      add(const RefreshEc2StatusEvent(silent: true));
      if (ticks >= 30) {
        timer.cancel();
      }
    });
  }

  String _getCurrentTimeFormatted() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  @override
  Future<void> close() {
    _expiryCheckTimer?.cancel();
    _ec2PollingTimer?.cancel();
    return super.close();
  }
}
