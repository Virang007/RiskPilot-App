import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_event.dart';
import '../blocs/settings/settings_state.dart';
import '../repositories/ec2_control_service.dart';

class Ec2MachineScreen extends StatelessWidget {
  const Ec2MachineScreen({super.key});

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
          constraints: const BoxConstraints(maxHeight: 340),
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
        final ec2State = state.ec2Status?.state.toLowerCase() ?? 'checking';
        final isRunning = ec2State == 'running';
        final isStopped = ec2State == 'stopped';
        final isPending = ec2State == 'pending';
        final isStopping = ec2State == 'stopping';
        final isTransitioning = isPending || isStopping;
        final isProcessing = state.isControllingEc2 || state.isLoadingEc2 || isTransitioning;

        Color badgeBg;
        Color badgeText;
        String badgeLabel;

        if (state.isLoadingEc2) {
          badgeBg = const Color(0xFF334155);
          badgeText = const Color(0xFF94A3B8);
          badgeLabel = 'CHECKING...';
        } else if (isStopping) {
          badgeBg = const Color(0xFF7C2D12);
          badgeText = const Color(0xFFFB923C);
          badgeLabel = 'STOPPING...';
        } else if (isPending) {
          badgeBg = const Color(0xFF78350F);
          badgeText = const Color(0xFFF59E0B);
          badgeLabel = 'STARTING...';
        } else if (isRunning) {
          badgeBg = const Color(0xFF064E3B);
          badgeText = const Color(0xFF10B981);
          badgeLabel = 'RUNNING';
        } else if (isStopped) {
          badgeBg = const Color(0xFF7F1D1D);
          badgeText = const Color(0xFFEF4444);
          badgeLabel = 'STOPPED';
        } else {
          badgeBg = const Color(0xFF334155);
          badgeText = const Color(0xFF94A3B8);
          badgeLabel = ec2State.toUpperCase();
        }

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
                Icon(Icons.dns_rounded, color: Color(0xFF38BDF8), size: 22),
                SizedBox(width: 8),
                Text(
                  'EC2 Server Machine',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: state.isLoadingEc2
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                      )
                    : const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8)),
                tooltip: 'Refresh Status',
                onPressed: state.isLoadingEc2
                    ? null
                    : () => context.read<SettingsBloc>().add(const RefreshEc2StatusEvent()),
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: Color(0xFF94A3B8)),
                tooltip: 'AWS Configuration',
                onPressed: () => _showAwsConfigDialog(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Main Server Status Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isRunning
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : const Color(0xFF334155),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: const Icon(Icons.cloud_circle_rounded, color: Color(0xFF38BDF8), size: 26),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'AWS EC2 Instance',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${state.ec2Status?.instanceId ?? Ec2ControlService.defaultInstanceId} • ${state.ec2Status?.region ?? Ec2ControlService.defaultRegion}',
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontFamily: 'monospace'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Badge Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: badgeText.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isProcessing)
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
                                  width: 8,
                                  height: 8,
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
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(color: Color(0xFF334155), height: 26),

                    // Server Details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Public IP', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        Text(
                          state.ec2Status?.publicIp ?? '3.105.33.175',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Backend Health Ping', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 6),
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
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'MACHINE POWER CONTROL',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),

              // Prominent Start / Stop Power Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (isProcessing || isStopping || isPending)
                      ? null
                      : () => _onToggleEc2Machine(context, isRunning),
                  icon: (state.isControllingEc2 || isStopping || isPending)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          isRunning ? Icons.power_settings_new_rounded : Icons.play_arrow_rounded,
                          size: 22,
                        ),
                  label: Text(
                    state.isControllingEc2
                        ? 'Sending Command...'
                        : isStopping
                            ? 'Stopping Machine...'
                            : isPending
                                ? 'Starting Machine...'
                                : isRunning
                                    ? 'Stop EC2 Machine'
                                    : 'Start EC2 Machine',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRunning ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: (isRunning ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Bar (Refresh, Console Log, AWS Config)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.isLoadingEc2
                          ? null
                          : () => context.read<SettingsBloc>().add(const RefreshEc2StatusEvent()),
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF38BDF8)),
                      label: const Text('Refresh', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF334155)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showOutputDialog(
                        context,
                        title: 'EC2 Command Output Log',
                        content: state.ec2LastOutput ?? state.ec2Status?.rawOutput ?? 'No output log recorded yet.',
                      ),
                      icon: const Icon(Icons.terminal_rounded, size: 16, color: Color(0xFF38BDF8)),
                      label: const Text('Console Log', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF334155)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAwsConfigDialog(context),
                      icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF94A3B8)),
                      label: const Text('AWS Keys', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF334155)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Text(
                'LIVE EXECUTION OUTPUT',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),

              // Console Terminal Display Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.terminal_rounded, color: Color(0xFF38BDF8), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'CLI Output Buffer',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF1E293B), height: 16),
                    Text(
                      state.ec2LastOutput?.trim().isNotEmpty == true
                          ? state.ec2LastOutput!
                          : (state.ec2Status?.rawOutput.trim().isNotEmpty == true
                              ? state.ec2Status!.rawOutput
                              : 'No command output recorded yet. Use Start/Stop or Refresh.'),
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
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
