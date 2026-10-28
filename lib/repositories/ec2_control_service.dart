import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class Ec2Status {
  final String instanceId;
  final String region;
  final String state; // 'running', 'stopped', 'pending', 'stopping', 'unknown'
  final String? publicIp;
  final bool isBackendHealthy;
  final String rawOutput;
  final DateTime timestamp;

  Ec2Status({
    required this.instanceId,
    required this.region,
    required this.state,
    this.publicIp,
    required this.isBackendHealthy,
    required this.rawOutput,
    required this.timestamp,
  });

  bool get isRunning => state.toLowerCase() == 'running';
  bool get isStopped => state.toLowerCase() == 'stopped';
  bool get isPending => state.toLowerCase() == 'pending';
  bool get isStopping => state.toLowerCase() == 'stopping';
}

class Ec2ActionResult {
  final bool success;
  final String state;
  final String message;
  final String rawOutput;

  Ec2ActionResult({
    required this.success,
    required this.state,
    required this.message,
    required this.rawOutput,
  });
}

class Ec2ControlService {
  static const String defaultRegion = 'ap-southeast-2';
  static const String defaultInstanceId = 'i-07de432d6282de976';

  // SharedPreferences keys
  static const String keyInstanceId = 'ec2_instance_id';
  static const String keyRegion = 'ec2_region';
  static const String keyAwsAccessKey = 'aws_access_key';
  static const String keyAwsSecretKey = 'aws_secret_key';

  /// Load configuration from SharedPreferences or fall back to defaults
  static Future<Map<String, String>> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'instanceId': prefs.getString(keyInstanceId) ?? defaultInstanceId,
      'region': prefs.getString(keyRegion) ?? defaultRegion,
      'awsAccessKey': prefs.getString(keyAwsAccessKey) ?? '',
      'awsSecretKey': prefs.getString(keyAwsSecretKey) ?? '',
    };
  }

  /// Save custom AWS configuration if user inputs them (e.g. on mobile)
  static Future<void> saveConfig({
    required String instanceId,
    required String region,
    String? awsAccessKey,
    String? awsSecretKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyInstanceId, instanceId.trim().isEmpty ? defaultInstanceId : instanceId.trim());
    await prefs.setString(keyRegion, region.trim().isEmpty ? defaultRegion : region.trim());
    if (awsAccessKey != null) {
      await prefs.setString(keyAwsAccessKey, awsAccessKey.trim());
    }
    if (awsSecretKey != null) {
      await prefs.setString(keyAwsSecretKey, awsSecretKey.trim());
    }
  }

  /// Check whether EC2 backend is responding to HTTP ping
  static Future<bool> checkBackendHealth() async {
    try {
      final uri = Uri.parse(AppConfig.healthUrl);
      final response = await http.get(uri).timeout(const Duration(milliseconds: 2500));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get status of the EC2 instance
  static Future<Ec2Status> getStatus() async {
    final config = await getConfig();
    final instanceId = config['instanceId']!;
    final region = config['region']!;
    final accessKey = config['awsAccessKey']!;
    final secretKey = config['awsSecretKey']!;

    // 1. Try local AWS CLI on Desktop (Windows, Mac, Linux)
    if (_canUseCli()) {
      try {
        final result = await _runAwsCli([
          'ec2',
          'describe-instances',
          '--instance-ids',
          instanceId,
          '--region',
          region,
          '--output',
          'json',
          '--no-cli-pager',
        ]);

        if (result.exitCode == 0) {
          final parsed = jsonDecode(result.stdout.toString());
          final instances = parsed['Reservations']?[0]?['Instances'] as List?;
          if (instances != null && instances.isNotEmpty) {
            final inst = instances[0];
            final state = (inst['State']?['Name'] ?? 'unknown').toString();
            final ip = inst['PublicIpAddress']?.toString();
            final healthy = state == 'running' ? await checkBackendHealth() : false;

            return Ec2Status(
              instanceId: instanceId,
              region: region,
              state: state,
              publicIp: ip,
              isBackendHealthy: healthy,
              rawOutput: result.stdout.toString(),
              timestamp: DateTime.now(),
            );
          }
        }
      } catch (e) {
        debugPrint('[Ec2ControlService] CLI describe failed: $e');
      }
    }

    // 2. Try AWS SigV4 REST API if keys are provided (Mobile / Fallback)
    if (accessKey.isNotEmpty && secretKey.isNotEmpty) {
      try {
        final res = await _callAwsRest(
          action: 'DescribeInstances',
          instanceId: instanceId,
          region: region,
          accessKey: accessKey,
          secretKey: secretKey,
        );

        if (res.statusCode == 200) {
          final state = _extractXmlTag(res.body, 'name') ?? 'unknown';
          final ip = _extractXmlTag(res.body, 'ipAddress');
          final healthy = state == 'running' ? await checkBackendHealth() : false;

          return Ec2Status(
            instanceId: instanceId,
            region: region,
            state: state,
            publicIp: ip,
            isBackendHealthy: healthy,
            rawOutput: res.body,
            timestamp: DateTime.now(),
          );
        } else {
          return Ec2Status(
            instanceId: instanceId,
            region: region,
            state: 'error',
            isBackendHealthy: false,
            rawOutput: 'AWS API Error (${res.statusCode}): ${res.body}',
            timestamp: DateTime.now(),
          );
        }
      } catch (e) {
        debugPrint('[Ec2ControlService] REST describe failed: $e');
      }
    }

    // 3. Fallback: Check backend health ping to infer state
    final healthy = await checkBackendHealth();
    return Ec2Status(
      instanceId: instanceId,
      region: region,
      state: healthy ? 'running' : 'stopped',
      publicIp: '3.105.33.175',
      isBackendHealthy: healthy,
      rawOutput: healthy
          ? 'Backend responded on http://3.105.33.175 (Status: 200 OK)'
          : 'Backend unreachable (Machine appears stopped or booting)',
      timestamp: DateTime.now(),
    );
  }

  /// Start the EC2 Instance
  static Future<Ec2ActionResult> startInstance() async {
    final config = await getConfig();
    final instanceId = config['instanceId']!;
    final region = config['region']!;
    final accessKey = config['awsAccessKey']!;
    final secretKey = config['awsSecretKey']!;

    // 1. Try local AWS CLI on Desktop
    if (_canUseCli()) {
      try {
        final result = await _runAwsCli([
          'ec2',
          'start-instances',
          '--instance-ids',
          instanceId,
          '--region',
          region,
          '--output',
          'json',
          '--no-cli-pager',
        ]);

        if (result.exitCode == 0) {
          try {
            final parsed = jsonDecode(result.stdout.toString());
            final starting = parsed['StartingInstances']?[0];
            final state = starting?['CurrentState']?['Name'] ?? 'pending';
            return Ec2ActionResult(
              success: true,
              state: state,
              message: 'EC2 Instance start initiated ($state)',
              rawOutput: result.stdout.toString(),
            );
          } catch (_) {
            return Ec2ActionResult(
              success: true,
              state: 'pending',
              message: 'EC2 start command sent successfully',
              rawOutput: result.stdout.toString(),
            );
          }
        } else {
          return Ec2ActionResult(
            success: false,
            state: 'error',
            message: 'Failed to start EC2: ${result.stderr}',
            rawOutput: '${result.stderr}\n${result.stdout}',
          );
        }
      } catch (e) {
        debugPrint('[Ec2ControlService] CLI start failed: $e');
      }
    }

    // 2. Try AWS SigV4 REST API
    if (accessKey.isNotEmpty && secretKey.isNotEmpty) {
      try {
        final res = await _callAwsRest(
          action: 'StartInstances',
          instanceId: instanceId,
          region: region,
          accessKey: accessKey,
          secretKey: secretKey,
        );

        if (res.statusCode == 200) {
          final state = _extractXmlTag(res.body, 'name') ?? 'pending';
          return Ec2ActionResult(
            success: true,
            state: state,
            message: 'EC2 Instance start initiated ($state)',
            rawOutput: res.body,
          );
        } else {
          return Ec2ActionResult(
            success: false,
            state: 'error',
            message: 'AWS API Error: ${res.statusCode}',
            rawOutput: res.body,
          );
        }
      } catch (e) {
        return Ec2ActionResult(
          success: false,
          state: 'error',
          message: 'Error calling AWS API: $e',
          rawOutput: e.toString(),
        );
      }
    }

    return Ec2ActionResult(
      success: false,
      state: 'error',
      message: 'AWS credentials not configured on mobile. Please enter AWS Keys in Settings.',
      rawOutput: 'AWS CLI not available and AWS Keys are empty in Settings.',
    );
  }

  /// Stop the EC2 Instance
  static Future<Ec2ActionResult> stopInstance() async {
    final config = await getConfig();
    final instanceId = config['instanceId']!;
    final region = config['region']!;
    final accessKey = config['awsAccessKey']!;
    final secretKey = config['awsSecretKey']!;

    // 1. Try local AWS CLI on Desktop
    if (_canUseCli()) {
      try {
        final result = await _runAwsCli([
          'ec2',
          'stop-instances',
          '--instance-ids',
          instanceId,
          '--region',
          region,
          '--output',
          'json',
          '--no-cli-pager',
        ]);

        if (result.exitCode == 0) {
          try {
            final parsed = jsonDecode(result.stdout.toString());
            final stopping = parsed['StoppingInstances']?[0];
            final state = stopping?['CurrentState']?['Name'] ?? 'stopping';
            return Ec2ActionResult(
              success: true,
              state: state,
              message: 'EC2 Instance stop initiated ($state)',
              rawOutput: result.stdout.toString(),
            );
          } catch (_) {
            return Ec2ActionResult(
              success: true,
              state: 'stopping',
              message: 'EC2 stop command sent successfully',
              rawOutput: result.stdout.toString(),
            );
          }
        } else {
          return Ec2ActionResult(
            success: false,
            state: 'error',
            message: 'Failed to stop EC2: ${result.stderr}',
            rawOutput: '${result.stderr}\n${result.stdout}',
          );
        }
      } catch (e) {
        debugPrint('[Ec2ControlService] CLI stop failed: $e');
      }
    }

    // 2. Try AWS SigV4 REST API
    if (accessKey.isNotEmpty && secretKey.isNotEmpty) {
      try {
        final res = await _callAwsRest(
          action: 'StopInstances',
          instanceId: instanceId,
          region: region,
          accessKey: accessKey,
          secretKey: secretKey,
        );

        if (res.statusCode == 200) {
          final state = _extractXmlTag(res.body, 'name') ?? 'stopping';
          return Ec2ActionResult(
            success: true,
            state: state,
            message: 'EC2 Instance stop initiated ($state)',
            rawOutput: res.body,
          );
        } else {
          return Ec2ActionResult(
            success: false,
            state: 'error',
            message: 'AWS API Error: ${res.statusCode}',
            rawOutput: res.body,
          );
        }
      } catch (e) {
        return Ec2ActionResult(
          success: false,
          state: 'error',
          message: 'Error calling AWS API: $e',
          rawOutput: e.toString(),
        );
      }
    }

    return Ec2ActionResult(
      success: false,
      state: 'error',
      message: 'AWS credentials not configured on mobile. Please enter AWS Keys in Settings.',
      rawOutput: 'AWS CLI not available and AWS Keys are empty in Settings.',
    );
  }

  // Check if CLI execution can be performed on the current platform
  static bool _canUseCli() {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  // Execute AWS CLI
  static Future<ProcessResult> _runAwsCli(List<String> args) async {
    return await Process.run('aws', args, runInShell: true);
  }

  // Call AWS EC2 REST API using AWS Signature Version 4
  static Future<http.Response> _callAwsRest({
    required String action,
    required String instanceId,
    required String region,
    required String accessKey,
    required String secretKey,
  }) async {
    final host = 'ec2.$region.amazonaws.com';
    final url = Uri.parse('https://$host/');

    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = _formatDateStamp(now);

    final payload = 'Action=$action&InstanceId.1=$instanceId&Version=2016-11-15';
    final payloadHash = sha256.convert(utf8.encode(payload)).toString();

    final canonicalHeaders = 'content-type:application/x-www-form-urlencoded; charset=utf-8\nhost:$host\nx-amz-date:$amzDate\n';
    const signedHeaders = 'content-type;host;x-amz-date';

    final canonicalRequest = 'POST\n/\n\n$canonicalHeaders\n$signedHeaders\n$payloadHash';
    final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();

    final credentialScope = '$dateStamp/$region/ec2/aws4_request';
    final stringToSign = 'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n$canonicalRequestHash';

    final signingKey = _getSignatureKey(secretKey, dateStamp, region, 'ec2');
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    final authHeader = 'AWS4-HMAC-SHA256 Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'Host': host,
        'X-Amz-Date': amzDate,
        'Authorization': authHeader,
      },
      body: payload,
    ).timeout(const Duration(seconds: 10));
  }

  static List<int> _getSignatureKey(String key, String dateStamp, String regionName, String serviceName) {
    final kSecret = utf8.encode('AWS4$key');
    final kDate = Hmac(sha256, kSecret).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(regionName)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(serviceName)).bytes;
    final kSigning = Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
    return kSigning;
  }

  static String _formatAmzDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}T'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}Z';
  }

  static String _formatDateStamp(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  static String? _extractXmlTag(String xml, String tag) {
    final match = RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(xml);
    return match?.group(1)?.trim();
  }
}
