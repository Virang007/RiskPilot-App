import 'package:equatable/equatable.dart';
import '../../repositories/ec2_control_service.dart';

enum SettingsStatus { initial, loading, loaded, failure }
enum Ec2ActionStatus { idle, starting, stopping, success, failure }

class SettingsState extends Equatable {
  // Dhan Broker state
  final SettingsStatus status;
  final bool isConnecting;
  final String clientId;
  final String pin;
  final String totpSecret;
  final String? accessToken;
  final String? clientName;
  final String? clientUcc;
  final String? tokenExpiry;
  final bool isPinObscured;
  final bool isSecretObscured;
  final String? dhanErrorTitle;
  final String? dhanErrorMessage;
  final String? dhanErrorType;
  final int? dhanStatusCode;
  final String? dhanSuccessMessage;

  // EC2 Machine Control state
  final bool isLoadingEc2;
  final Ec2ActionStatus ec2ActionStatus;
  final Ec2Status? ec2Status;
  final String? ec2LastOutput;
  final String? ec2FeedbackMessage;
  final bool isEc2Success;

  const SettingsState({
    this.status = SettingsStatus.initial,
    this.isConnecting = false,
    this.clientId = '',
    this.pin = '',
    this.totpSecret = '',
    this.accessToken,
    this.clientName,
    this.clientUcc,
    this.tokenExpiry,
    this.isPinObscured = true,
    this.isSecretObscured = true,
    this.dhanErrorTitle,
    this.dhanErrorMessage,
    this.dhanErrorType,
    this.dhanStatusCode,
    this.dhanSuccessMessage,
    this.isLoadingEc2 = false,
    this.ec2ActionStatus = Ec2ActionStatus.idle,
    this.ec2Status,
    this.ec2LastOutput,
    this.ec2FeedbackMessage,
    this.isEc2Success = false,
  });

  bool get isConnected => accessToken != null && accessToken!.isNotEmpty;
  bool get isControllingEc2 =>
      ec2ActionStatus == Ec2ActionStatus.starting ||
      ec2ActionStatus == Ec2ActionStatus.stopping;

  SettingsState copyWith({
    SettingsStatus? status,
    bool? isConnecting,
    String? clientId,
    String? pin,
    String? totpSecret,
    String? accessToken,
    bool clearAccessToken = false,
    String? clientName,
    bool clearClientName = false,
    String? clientUcc,
    bool clearClientUcc = false,
    String? tokenExpiry,
    bool clearTokenExpiry = false,
    bool? isPinObscured,
    bool? isSecretObscured,
    String? dhanErrorTitle,
    String? dhanErrorMessage,
    String? dhanErrorType,
    int? dhanStatusCode,
    bool clearDhanError = false,
    String? dhanSuccessMessage,
    bool clearDhanSuccess = false,
    bool? isLoadingEc2,
    Ec2ActionStatus? ec2ActionStatus,
    Ec2Status? ec2Status,
    String? ec2LastOutput,
    String? ec2FeedbackMessage,
    bool clearEc2Feedback = false,
    bool? isEc2Success,
  }) {
    return SettingsState(
      status: status ?? this.status,
      isConnecting: isConnecting ?? this.isConnecting,
      clientId: clientId ?? this.clientId,
      pin: pin ?? this.pin,
      totpSecret: totpSecret ?? this.totpSecret,
      accessToken: clearAccessToken ? null : (accessToken ?? this.accessToken),
      clientName: clearClientName ? null : (clientName ?? this.clientName),
      clientUcc: clearClientUcc ? null : (clientUcc ?? this.clientUcc),
      tokenExpiry: clearTokenExpiry ? null : (tokenExpiry ?? this.tokenExpiry),
      isPinObscured: isPinObscured ?? this.isPinObscured,
      isSecretObscured: isSecretObscured ?? this.isSecretObscured,
      dhanErrorTitle: clearDhanError ? null : (dhanErrorTitle ?? this.dhanErrorTitle),
      dhanErrorMessage: clearDhanError ? null : (dhanErrorMessage ?? this.dhanErrorMessage),
      dhanErrorType: clearDhanError ? null : (dhanErrorType ?? this.dhanErrorType),
      dhanStatusCode: clearDhanError ? null : (dhanStatusCode ?? this.dhanStatusCode),
      dhanSuccessMessage: clearDhanSuccess ? null : (dhanSuccessMessage ?? this.dhanSuccessMessage),
      isLoadingEc2: isLoadingEc2 ?? this.isLoadingEc2,
      ec2ActionStatus: ec2ActionStatus ?? this.ec2ActionStatus,
      ec2Status: ec2Status ?? this.ec2Status,
      ec2LastOutput: ec2LastOutput ?? this.ec2LastOutput,
      ec2FeedbackMessage: clearEc2Feedback ? null : (ec2FeedbackMessage ?? this.ec2FeedbackMessage),
      isEc2Success: isEc2Success ?? this.isEc2Success,
    );
  }

  @override
  List<Object?> get props => [
        status,
        isConnecting,
        clientId,
        pin,
        totpSecret,
        accessToken,
        clientName,
        clientUcc,
        tokenExpiry,
        isPinObscured,
        isSecretObscured,
        dhanErrorTitle,
        dhanErrorMessage,
        dhanErrorType,
        dhanStatusCode,
        dhanSuccessMessage,
        isLoadingEc2,
        ec2ActionStatus,
        ec2Status,
        ec2LastOutput,
        ec2FeedbackMessage,
        isEc2Success,
      ];
}
