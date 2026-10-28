import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Load saved settings from SharedPreferences & check expiry
class LoadSettingsEvent extends SettingsEvent {
  const LoadSettingsEvent();
}

/// Periodic or silent token expiry check
class CheckExpirySilentEvent extends SettingsEvent {
  const CheckExpirySilentEvent();
}

/// Clear one-shot notification messages
class ClearMessagesEvent extends SettingsEvent {
  const ClearMessagesEvent();
}

/// Connect to Dhan Broker using credentials
class ConnectDhanEvent extends SettingsEvent {
  final String clientId;
  final String pin;
  final String totpSecret;

  const ConnectDhanEvent({
    required this.clientId,
    required this.pin,
    required this.totpSecret,
  });

  @override
  List<Object?> get props => [clientId, pin, totpSecret];
}

/// Disconnect Dhan Broker session & clear token
class DisconnectDhanEvent extends SettingsEvent {
  const DisconnectDhanEvent();
}

/// Toggle obscuring of PIN field
class TogglePinVisibilityEvent extends SettingsEvent {
  const TogglePinVisibilityEvent();
}

/// Toggle obscuring of TOTP Secret field
class ToggleSecretVisibilityEvent extends SettingsEvent {
  const ToggleSecretVisibilityEvent();
}

/// Refresh EC2 server machine status
class RefreshEc2StatusEvent extends SettingsEvent {
  final bool silent;
  const RefreshEc2StatusEvent({this.silent = false});

  @override
  List<Object?> get props => [silent];
}

/// Start EC2 Machine
class StartEc2MachineEvent extends SettingsEvent {
  const StartEc2MachineEvent();
}

/// Stop EC2 Machine
class StopEc2MachineEvent extends SettingsEvent {
  const StopEc2MachineEvent();
}

/// Save custom AWS & EC2 configuration
class SaveAwsConfigEvent extends SettingsEvent {
  final String instanceId;
  final String region;
  final String? awsAccessKey;
  final String? awsSecretKey;

  const SaveAwsConfigEvent({
    required this.instanceId,
    required this.region,
    this.awsAccessKey,
    this.awsSecretKey,
  });

  @override
  List<Object?> get props => [instanceId, region, awsAccessKey, awsSecretKey];
}
