import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_event.dart';
import '../blocs/settings/settings_state.dart';
import '../config/app_config.dart';
import '../repositories/dhan_token_manager.dart';

class BrokerSettingsScreen extends StatefulWidget {
  const BrokerSettingsScreen({super.key});

  @override
  State<BrokerSettingsScreen> createState() => _BrokerSettingsScreenState();
}

class _BrokerSettingsScreenState extends State<BrokerSettingsScreen> {
  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _totpSecretController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 1. Immediately populate from BLoC state
    final state = context.read<SettingsBloc>().state;
    if (state.clientId.isNotEmpty) {
      _clientIdController.text = state.clientId;
    }
    if (state.pin.isNotEmpty) {
      _pinController.text = state.pin;
    }
    if (state.totpSecret.isNotEmpty) {
      _totpSecretController.text = state.totpSecret;
    }

    // 2. Also fetch from SharedPreferences as safe fallback
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final savedId = prefs.getString(DhanTokenManager.keyClientId);
      final savedPin = prefs.getString(DhanTokenManager.keyPin);
      final savedSecret = prefs.getString(DhanTokenManager.keyTotpSecret);

      if (_clientIdController.text.isEmpty && savedId != null && savedId.isNotEmpty) {
        setState(() {
          _clientIdController.text = savedId;
        });
      }
      if (_pinController.text.isEmpty && savedPin != null && savedPin.isNotEmpty) {
        setState(() {
          _pinController.text = savedPin;
        });
      }
      if (_totpSecretController.text.isEmpty && savedSecret != null && savedSecret.isNotEmpty) {
        setState(() {
          _totpSecretController.text = savedSecret;
        });
      }
    } catch (_) {}
  }

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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsBloc, SettingsState>(
      listener: (context, state) {
        // Sync text controllers whenever state loads or updates credentials
        if (_clientIdController.text.isEmpty && state.clientId.isNotEmpty) {
          _clientIdController.text = state.clientId;
        }
        if (_pinController.text.isEmpty && state.pin.isNotEmpty) {
          _pinController.text = state.pin;
        }
        if (_totpSecretController.text.isEmpty && state.totpSecret.isNotEmpty) {
          _totpSecretController.text = state.totpSecret;
        }

        // Dhan connection success feedback
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

        // Dhan error feedback
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
      },
      builder: (context, state) {
        final isConnected = state.isConnected;

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E293B),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Row(
              children: [
                Icon(Icons.account_balance_rounded, color: Color(0xFF10B981), size: 22),
                SizedBox(width: 8),
                Text(
                  'Broker Settings',
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
                      // Disconnect Button
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

              // Configuration Card
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

                    // Save & Connect Dhan Button
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
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
