import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_event.dart';
import '../blocs/settings/settings_state.dart';
import '../config/app_config.dart';
import '../repositories/ec2_control_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _totpSecretController = TextEditingController();

  @override
  void dispose() {
    _clientIdController.dispose();
    _pinController.dispose();
    _totpSecretController.dispose();
    super.dispose();
  }

  void _onConnectPressed(BuildContext context) {
    final clientId = _clientIdController.text.trim();
    final pin = _pinController.text.trim();
    final secret = _totpSecretController.text.trim();

    if (clientId.isEmpty || pin.isEmpty || secret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text(
            'Kripya Client ID, PIN, aur TOTP Secret teeno enter karein.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    context.read<SettingsBloc>().add(ConnectDhanEvent(
          clientId: clientId,
          pin: pin,
          totpSecret: secret,
        ));
  }

  void _onDisconnectDhan(BuildContext context) {
    context.read<SettingsBloc>().add(const DisconnectDhanEvent());
  }

  void _onToggleEc2Machine(BuildContext context, bool isRunning) {
    if (isRunning) {
      context.read<SettingsBloc>().add(const StopEc2MachineEvent());
    } else {
      context.read<SettingsBloc>().add(const StartEc2MachineEvent());
    }
  }

  void _showOutputDialog(BuildContext context, {required String title, required String content}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.terminal_rounded, color: Color(0xFF38BDF8), size: 22),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 320),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: SingleChildScrollView(
            child: Text(
              content.trim().isEmpty ? 'No output recorded.' : content,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF38BDF8))),
          ),
        ],
      ),
    );
  }

  void _showAwsConfigDialog(BuildContext context) async {
    final config = await Ec2ControlService.getConfig();
    final instanceIdCtrl = TextEditingController(text: config['instanceId']);
    final regionCtrl = TextEditingController(text: config['region']);
    final accessKeyCtrl = TextEditingController(text: config['awsAccessKey']);
    final secretKeyCtrl = TextEditingController(text: config['awsSecretKey']);
    final ValueNotifier<bool> obscureNotifier = ValueNotifier<bool>(true);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: Color(0xFF38BDF8), size: 22),
            SizedBox(width: 8),
            Text('EC2 & AWS Settings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Desktop uses local AWS CLI automatically. Mobile/Android uses saved AWS keys below.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 14),
              const Text('Instance ID', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 4),
              TextField(
                controller: instanceIdCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              const Text('AWS Region', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 4),
              TextField(
                controller: regionCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              const Text('AWS Access Key (Optional for Mobile)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 4),
              TextField(
                controller: accessKeyCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'AKIA...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              const Text('AWS Secret Key (Optional for Mobile)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 4),
              ValueListenableBuilder<bool>(
                valueListenable: obscureNotifier,
                builder: (context, obscure, _) {
                  return TextField(
                    controller: secretKeyCtrl,
                    obscureText: obscure,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'Enter AWS secret key',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18, color: const Color(0xFF94A3B8)),
                        onPressed: () => obscureNotifier.value = !obscureNotifier.value,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<SettingsBloc>().add(SaveAwsConfigEvent(
                    instanceId: instanceIdCtrl.text,
                    region: regionCtrl.text,
                    awsAccessKey: accessKeyCtrl.text,
                    awsSecretKey: secretKeyCtrl.text,
                  ));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
            child: const Text('Save Settings', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsBloc, SettingsState>(
      listener: (context, state) {
        // Sync text controllers once loaded if they are empty
        if (state.status == SettingsStatus.loaded) {
          if (_clientIdController.text.isEmpty && state.clientId.isNotEmpty) {
            _clientIdController.text = state.clientId;
          }
          if (_pinController.text.isEmpty && state.pin.isNotEmpty) {
            _pinController.text = state.pin;
          }
          if (_totpSecretController.text.isEmpty && state.totpSecret.isNotEmpty) {
            _totpSecretController.text = state.totpSecret;
          }
        }

        // Dhan connection success feedback (SnackBar only, no popups)
        if (state.dhanSuccessMessage != null) {
          final msg = state.dhanSuccessMessage!;
          context.read<SettingsBloc>().add(const ClearMessagesEvent());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }

        // Dhan error feedback (SnackBar only, NO blocking dialog!)
        if (state.dhanErrorMessage != null) {
          final msg = state.dhanErrorMessage!;
          context.read<SettingsBloc>().add(const ClearMessagesEvent());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              content: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }

        // EC2 feedback snackbar (SnackBar only, no popups)
        if (state.ec2FeedbackMessage != null) {
          final msg = state.ec2FeedbackMessage!;
          final isSuccess = state.isEc2Success;
          context.read<SettingsBloc>().add(const ClearMessagesEvent());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              content: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.status == SettingsStatus.loading) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            ),
          );
        }

        final isConnected = state.isConnected;

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E293B),
            elevation: 0,
            title: const Row(
              children: [
                Icon(Icons.tune_rounded, color: Color(0xFF38BDF8), size: 22),
                SizedBox(width: 8),
                Text(
                  'Dhan Broker Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Connection Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isConnected
                        ? [const Color(0xFF064E3B), const Color(0xFF0F172A)]
                        : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isConnected ? const Color(0xFF10B981) : const Color(0xFF334155),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isConnected
                                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                : const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isConnected ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
                            color: isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isConnected ? 'Dhan Broker Connected' : 'Broker Disconnected',
                                style: TextStyle(
                                  color: isConnected ? const Color(0xFF10B981) : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isConnected
                                    ? (state.clientName != null && state.clientName!.isNotEmpty
                                        ? state.clientName!
                                        : 'Active Live Session')
                                    : 'Connect your account using PIN & TOTP Secret',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isConnected) ...[
                      const Divider(color: Color(0xFF334155), height: 24),
                      if (state.clientUcc != null && state.clientUcc!.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'UCC / Account ID',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                            Text(
                              state.clientUcc!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Token Expiry Rule',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Daily 6:00 AM (Auto Expire)',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (state.tokenExpiry != null && state.tokenExpiry!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Server Expiry',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                            Text(
                              state.tokenExpiry!,
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Disconnect Button (Direct action, NO popup dialog)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _onDisconnectDhan(context),
                          icon: const Icon(Icons.link_off_rounded, size: 18, color: Color(0xFFEF4444)),
                          label: const Text(
                            'Disconnect Broker',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'DHAN CREDENTIALS',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),

              // Configuration Card (Client ID, PIN, TOTP Secret)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Dhan Client ID
                    const Text(
                      'Dhan Client ID',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _clientIdController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. 1112204999',
                        hintStyle: const TextStyle(color: Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF94A3B8), size: 20),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF10B981)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Dhan PIN
                    const Text(
                      'Dhan Account PIN',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _pinController,
                      obscureText: state.isPinObscured,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '6-digit PIN',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), letterSpacing: 0),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            state.isPinObscured ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          onPressed: () => context.read<SettingsBloc>().add(const TogglePinVisibilityEvent()),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF10B981)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Dhan TOTP Secret
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTP Secret Key',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Auto-generates TOTP via Backend',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _totpSecretController,
                      obscureText: state.isSecretObscured,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter TOTP Secret string',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontFamily: 'sans-serif'),
                        prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF94A3B8), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            state.isSecretObscured ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          onPressed: () => context.read<SettingsBloc>().add(const ToggleSecretVisibilityEvent()),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF10B981)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save & Connect Dhan Button (Direct action, SnackBar notification, NO dialog)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: state.isConnecting ? null : () => _onConnectPressed(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF10B981).withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: state.isConnecting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Connecting to Dhan Broker...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                isConnected ? 'Update & Reconnect Dhan' : 'Save & Connect Dhan Broker',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'SYSTEM & EXPIRY POLICY',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Backend URL', style: TextStyle(color: Color(0xFF94A3B8))),
                        Text(
                          AppConfig.baseUrl,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF334155), height: 20),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Daily Token Reset', style: TextStyle(color: Color(0xFF94A3B8))),
                        Text(
                          'Every day at 06:00 AM IST',
                          style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF334155), height: 20),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Auto-Purge Expired', style: TextStyle(color: Color(0xFF94A3B8))),
                        Text(
                          'Enabled',
                          style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // EC2 Machine Control Card (Small & Simple Bottom Section)
              _buildEc2MachineControlCard(context, state),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEc2MachineControlCard(BuildContext context, SettingsState state) {
    final ec2State = state.ec2Status?.state.toLowerCase() ?? 'checking';
    final isRunning = ec2State == 'running';
    final isStopped = ec2State == 'stopped';
    final isPending = ec2State == 'pending';
    final isStopping = ec2State == 'stopping';
    final isProcessing = state.isControllingEc2 || state.isLoadingEc2;

    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    if (state.isLoadingEc2) {
      badgeBg = const Color(0xFF334155);
      badgeText = const Color(0xFF94A3B8);
      badgeLabel = 'CHECKING...';
    } else if (isRunning) {
      badgeBg = const Color(0xFF064E3B);
      badgeText = const Color(0xFF10B981);
      badgeLabel = 'RUNNING';
    } else if (isStopped) {
      badgeBg = const Color(0xFF7F1D1D);
      badgeText = const Color(0xFFEF4444);
      badgeLabel = 'STOPPED';
    } else if (isPending) {
      badgeBg = const Color(0xFF78350F);
      badgeText = const Color(0xFFF59E0B);
      badgeLabel = 'STARTING...';
    } else if (isStopping) {
      badgeBg = const Color(0xFF7C2D12);
      badgeText = const Color(0xFFFB923C);
      badgeLabel = 'STOPPING...';
    } else {
      badgeBg = const Color(0xFF334155);
      badgeText = const Color(0xFF94A3B8);
      badgeLabel = ec2State.toUpperCase();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EC2 SERVER CONTROL (AWS)',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRunning
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : const Color(0xFF334155),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Machine Title & State Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Icon(Icons.cloud_circle_rounded, color: Color(0xFF38BDF8), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EC2 Machine',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            state.ec2Status?.instanceId ?? Ec2ControlService.defaultInstanceId,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Status Badge Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeText.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isProcessing || isPending || isStopping)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 2, color: badgeText),
                            ),
                          )
                        else
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: badgeText,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeText,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(color: Color(0xFF334155), height: 22),

              // Server Details Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Public IP', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
                  Text(
                    state.ec2Status?.publicIp ?? '3.105.33.175',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5, fontFamily: 'monospace'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Backend Health Ping', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: (state.ec2Status?.isBackendHealthy ?? false) ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        (state.ec2Status?.isBackendHealthy ?? false) ? 'Online (200 OK)' : 'Offline',
                        style: TextStyle(
                          color: (state.ec2Status?.isBackendHealthy ?? false) ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Compact Machine ON / OFF Buttons & Action Row
              Row(
                children: [
                  // Primary Small ON / OFF Button (Direct toggle without dialog)
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: (isProcessing || isStopping || isPending)
                            ? null
                            : () => _onToggleEc2Machine(context, isRunning),
                        icon: (state.isControllingEc2 || isStopping || isPending)
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(
                                isRunning ? Icons.power_settings_new_rounded : Icons.play_arrow_rounded,
                                size: 18,
                              ),
                        label: Text(
                          state.isControllingEc2
                              ? 'Executing...'
                              : isStopping
                                  ? 'Stopping...'
                                  : isPending
                                      ? 'Starting...'
                                      : isRunning
                                          ? 'Stop Machine'
                                          : 'Start Machine',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRunning ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: (isRunning ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          elevation: 1,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Refresh Status Button (Always clickable except when active fetch is in-flight)
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: state.isLoadingEc2
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF94A3B8)),
                            )
                          : const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8), size: 20),
                      tooltip: 'Refresh Status',
                      onPressed: state.isLoadingEc2 ? null : () => context.read<SettingsBloc>().add(const RefreshEc2StatusEvent()),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Output Log Dialog Button
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.terminal_rounded, color: Color(0xFF38BDF8), size: 19),
                      tooltip: 'View Output Logs',
                      onPressed: () => _showOutputDialog(
                        context,
                        title: 'EC2 Command Output Log',
                        content: state.ec2LastOutput ?? state.ec2Status?.rawOutput ?? 'No output log recorded yet.',
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // AWS Config Settings Button
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.tune_rounded, color: Color(0xFF94A3B8), size: 19),
                      tooltip: 'AWS Configuration',
                      onPressed: () => _showAwsConfigDialog(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
