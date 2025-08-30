import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/network_diagnostics.dart';

class NetworkTestScreen extends StatefulWidget {
  const NetworkTestScreen({super.key});

  @override
  State<NetworkTestScreen> createState() => _NetworkTestScreenState();
}

class _NetworkTestScreenState extends State<NetworkTestScreen> {
  bool _isRunning = false;
  String? _reportText;
  NetworkDiagnosticsResult? _result;

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunning = true;
      _reportText = null;
      _result = null;
    });

    try {
      final result = await NetworkDiagnostics.runDiagnostics();
      final report = NetworkDiagnostics.generateTroubleshootingReport(result);

      setState(() {
        _result = result;
        _reportText = report;
      });
    } catch (e) {
      setState(() {
        _reportText = 'Error running diagnostics: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Diagnostics'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.network_check,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Network Connectivity Test',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This test will check your internet connection and ability to reach Instagram servers. '
                      'Run this test if you\'re experiencing download issues.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _runDiagnostics,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child:
                            _isRunning
                                ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Running Diagnostics...'),
                                  ],
                                )
                                : const Text('Run Network Test'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_result != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _result!.isNetworkHealthy
                                ? Icons.check_circle
                                : Icons.error,
                            color:
                                _result!.isNetworkHealthy
                                    ? Colors.green
                                    : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _result!.isNetworkHealthy
                                ? 'Network Status: Healthy'
                                : 'Network Status: Issues Found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  _result!.isNetworkHealthy
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildStatusRow(
                        'Internet Access',
                        _result!.hasBasicInternet,
                      ),
                      _buildStatusRow(
                        'Instagram Domain',
                        _result!.canResolveInstagram,
                      ),
                      _buildStatusRow(
                        'Instagram Connection',
                        _result!.canConnectToInstagram,
                      ),
                      if (_result!.instagramIpAddress != null) ...[
                        const SizedBox(height: 4),
                        Text('Instagram IP: ${_result!.instagramIpAddress}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_reportText != null) ...[
              Expanded(
                child: Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.description,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Detailed Report',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: _reportText!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Report copied to clipboard'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy),
                              tooltip: 'Copy Report',
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _reportText!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            status ? Icons.check : Icons.close,
            size: 16,
            color: status ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
