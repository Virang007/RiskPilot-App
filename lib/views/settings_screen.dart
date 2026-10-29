import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_state.dart';
import '../config/app_config.dart';
import '../repositories/ec2_control_service.dart';
import 'broker_settings_screen.dart';
import 'ec2_machine_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final isBrokerConnected = state.isConnected;

        // EC2 Status calculations
        final ec2State = state.ec2Status?.state.toLowerCase() ?? 'checking';
        final isEc2Running = ec2State == 'running';
        final isEc2Stopped = ec2State == 'stopped';
        final isEc2Pending = ec2State == 'pending';
        final isEc2Stopping = ec2State == 'stopping';

        Color ec2BadgeBg;
        Color ec2BadgeText;
        String ec2BadgeLabel;

        if (state.isLoadingEc2) {
          ec2BadgeBg = const Color(0xFF334155);
          ec2BadgeText = const Color(0xFF94A3B8);
          ec2BadgeLabel = 'CHECKING...';
        } else if (isEc2Stopping) {
          ec2BadgeBg = const Color(0xFF7C2D12);
          ec2BadgeText = const Color(0xFFFB923C);
          ec2BadgeLabel = 'STOPPING...';
        } else if (isEc2Pending) {
          ec2BadgeBg = const Color(0xFF78350F);
          ec2BadgeText = const Color(0xFFF59E0B);
          ec2BadgeLabel = 'STARTING...';
        } else if (isEc2Running) {
          ec2BadgeBg = const Color(0xFF064E3B);
          ec2BadgeText = const Color(0xFF10B981);
          ec2BadgeLabel = 'RUNNING';
        } else if (isEc2Stopped) {
          ec2BadgeBg = const Color(0xFF7F1D1D);
          ec2BadgeText = const Color(0xFFEF4444);
          ec2BadgeLabel = 'STOPPED';
        } else {
          ec2BadgeBg = const Color(0xFF334155);
          ec2BadgeText = const Color(0xFF94A3B8);
          ec2BadgeLabel = ec2State.toUpperCase();
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E293B),
            elevation: 0,
            title: const Row(
              children: [
                Icon(Icons.tune_rounded, color: Color(0xFF38BDF8), size: 22),
                SizedBox(width: 10),
                Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            children: [
              // Intro Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF131E31)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.dashboard_customize_rounded,
                        color: Color(0xFF38BDF8),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Control Center',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Select an option below to manage Broker authentication or EC2 Cloud Machine.',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Section Header
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'SELECT CONFIGURATION',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),

              // ================= OPTION 1: BROKER =================
              _buildPrimaryOptionCard(
                context: context,
                icon: Icons.account_balance_rounded,
                iconColor: const Color(0xFF10B981),
                iconBg: const Color(0xFF064E3B).withValues(alpha: 0.4),
                title: 'Broker',
                subtitle: 'DhanHQ Trading Account & Authentication',
                statusLabel: isBrokerConnected ? 'CONNECTED' : 'NOT CONNECTED',
                statusBg: isBrokerConnected ? const Color(0xFF064E3B) : const Color(0xFF334155),
                statusColor: isBrokerConnected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                extraInfo: isBrokerConnected
                    ? (state.clientName != null && state.clientName!.isNotEmpty
                        ? 'Account: ${state.clientName}'
                        : (state.clientUcc != null ? 'UCC: ${state.clientUcc}' : 'Live Session Active'))
                    : 'Tap to configure PIN & TOTP Secret',
                borderColor: isBrokerConnected
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : const Color(0xFF334155),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BrokerSettingsScreen()),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ================= OPTION 2: EC2 MACHINE =================
              _buildPrimaryOptionCard(
                context: context,
                icon: Icons.dns_rounded,
                iconColor: const Color(0xFF38BDF8),
                iconBg: const Color(0xFF0C4A6E).withValues(alpha: 0.4),
                title: 'EC2 Machine',
                subtitle: 'AWS Cloud Server Machine & Power Controls',
                statusLabel: ec2BadgeLabel,
                statusBg: ec2BadgeBg,
                statusColor: ec2BadgeText,
                isLoading: state.isLoadingEc2 || isEc2Pending || isEc2Stopping,
                extraInfo:
                    '${state.ec2Status?.instanceId ?? Ec2ControlService.defaultInstanceId} • IP: ${state.ec2Status?.publicIp ?? '3.105.33.175'}',
                borderColor: isEc2Running
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
                    : const Color(0xFF334155),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const Ec2MachineScreen()),
                  );
                },
              ),

              const SizedBox(height: 32),

              // System Overview Footer Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'SYSTEM INFORMATION',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Backend Host', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        Text(
                          AppConfig.baseUrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF334155), height: 20),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Token Expiry Schedule', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        Text(
                          'Daily at 06:00 AM IST',
                          style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF334155), height: 20),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Application Version', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        Text(
                          'RiskPilot v1.0.0',
                          style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w600, fontSize: 13),
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

  Widget _buildPrimaryOptionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String statusLabel,
    required Color statusBg,
    required Color statusColor,
    required String extraInfo,
    required Color borderColor,
    bool isLoading = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: iconColor.withValues(alpha: 0.1),
        highlightColor: iconColor.withValues(alpha: 0.05),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Prominent Leading Icon Container
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                    ),
                    child: Icon(icon, color: iconColor, size: 26),
                  ),

                  const SizedBox(width: 16),

                  // Main Title & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Circular Chevron Button
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFFCBD5E1),
                      size: 14,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(color: Color(0xFF334155), height: 1),
              const SizedBox(height: 12),

              // Bottom status bar inside card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Live Status Pill Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLoading)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: statusColor,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Detail string
                  Flexible(
                    child: Text(
                      extraInfo,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
