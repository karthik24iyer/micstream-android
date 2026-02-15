import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/stream_provider.dart';
import '../services/discovery_service.dart';

/// HomeScreen - Main UI
/// Phase 1: IP input, connect/disconnect button, status indicator
/// Phase 2: mDNS discovery, device list, scan button
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _ipController = TextEditingController();
  bool _permissionGranted = false;
  bool _useDiscovery = true; // Phase 2: Toggle between discovery and manual IP

  @override
  void initState() {
    super.initState();
    _checkMicrophonePermission();
    _ipController.text = '192.168.1.100'; // Default for manual mode
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  /// Check microphone permission
  Future<void> _checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    setState(() {
      _permissionGranted = status.isGranted;
    });

    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      setState(() {
        _permissionGranted = result.isGranted;
      });
    }
  }

  /// Handle manual connect button
  Future<void> _handleManualConnect(AudioStreamProvider provider) async {
    if (provider.isStreaming) {
      await provider.disconnect();
      return;
    }

    final ipAddress = _ipController.text.trim();
    if (ipAddress.isEmpty) {
      _showError('Please enter IP address');
      return;
    }

    if (!_permissionGranted) {
      _showError('Microphone permission required');
      await _checkMicrophonePermission();
      return;
    }

    final success = await provider.connect(ipAddress);
    if (!success && mounted) {
      _showError(provider.errorMessage ?? 'Connection failed');
    }
  }

  /// Handle device connection (Phase 2)
  Future<void> _handleDeviceConnect(
      AudioStreamProvider provider, DiscoveredDevice device) async {
    if (!_permissionGranted) {
      _showError('Microphone permission required');
      await _checkMicrophonePermission();
      return;
    }

    final success = await provider.connectToDevice(device);
    if (!success && mounted) {
      _showError(provider.errorMessage ?? 'Connection failed');
    }
  }

  /// Handle scan button (Phase 2)
  Future<void> _handleScan(AudioStreamProvider provider) async {
    if (provider.isScanning) {
      await provider.stopScanning();
    } else {
      await provider.startScanning();
    }
  }

  /// Show error snackbar
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Consumer<AudioStreamProvider>(
          builder: (context, streamProvider, child) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Title
                  const Text(
                    'MicStream',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Status Indicator
                  _buildStatusIndicator(streamProvider),

                  const SizedBox(height: 24),

                  // Mode Toggle (Phase 2)
                  if (!streamProvider.isStreaming)
                    _buildModeToggle(),

                  const SizedBox(height: 24),

                  // Content based on mode and connection status
                  if (!streamProvider.isStreaming) ...[
                    if (_useDiscovery)
                      _buildDiscoveryMode(streamProvider)
                    else
                      _buildManualMode(streamProvider),
                  ] else ...[
                    // Connected state
                    _buildConnectedInfo(streamProvider),
                    const SizedBox(height: 24),
                    _buildStatistics(streamProvider),
                  ],

                  const SizedBox(height: 24),

                  // Main action button
                  if (streamProvider.isStreaming)
                    _buildDisconnectButton(streamProvider),

                  const SizedBox(height: 16),

                  // Permission warning
                  if (!_permissionGranted)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Microphone permission required',
                              style: TextStyle(color: Colors.orange.shade300),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build mode toggle widget (Phase 2)
  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _useDiscovery = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _useDiscovery ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Auto-Discover',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _useDiscovery = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_useDiscovery ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Manual IP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build discovery mode UI (Phase 2)
  Widget _buildDiscoveryMode(AudioStreamProvider provider) {
    return Column(
      children: [
        // Scan button
        ElevatedButton.icon(
          onPressed: () => _handleScan(provider),
          style: ElevatedButton.styleFrom(
            backgroundColor: provider.isScanning ? Colors.orange : Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(provider.isScanning ? Icons.stop : Icons.search),
          label: Text(
            provider.isScanning ? 'STOP SCANNING' : 'SCAN FOR DEVICES',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Device list
        if (provider.discoveredDevices.isEmpty && provider.isScanning)
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Scanning for devices...',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          )
        else if (provider.discoveredDevices.isEmpty && !provider.isScanning)
          Container(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No devices found.\nMake sure Windows receiver is running.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          )
        else
          _buildDeviceList(provider),
      ],
    );
  }

  /// Build device list (Phase 2)
  Widget _buildDeviceList(AudioStreamProvider provider) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: provider.discoveredDevices.length,
        separatorBuilder: (context, index) => Divider(
          color: Colors.white.withOpacity(0.1),
          height: 1,
        ),
        itemBuilder: (context, index) {
          final device = provider.discoveredDevices[index];
          return ListTile(
            leading: const Icon(Icons.computer, color: Colors.blue),
            title: Text(
              device.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${device.host}:${device.port}',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            trailing: ElevatedButton(
              onPressed: () => _handleDeviceConnect(provider, device),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('CONNECT'),
            ),
          );
        },
      ),
    );
  }

  /// Build manual IP mode UI (Phase 1)
  Widget _buildManualMode(AudioStreamProvider provider) {
    return Column(
      children: [
        // IP input
        TextField(
          controller: _ipController,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            labelText: 'Windows PC IP Address',
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            hintText: '192.168.1.100',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.blue, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: TextInputType.number,
        ),

        const SizedBox(height: 24),

        // Connect button
        ElevatedButton(
          onPressed: provider.connectionState == StreamConnectionState.connecting
              ? null
              : () => _handleManualConnect(provider),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            provider.connectionState == StreamConnectionState.connecting
                ? 'CONNECTING...'
                : 'CONNECT',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Build connected info widget
  Widget _buildConnectedInfo(AudioStreamProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Connected to',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            provider.destinationName ?? provider.destinationAddress ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (provider.destinationName != null)
            Text(
              provider.destinationAddress ?? '',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  /// Build disconnect button
  Widget _buildDisconnectButton(AudioStreamProvider provider) {
    return ElevatedButton(
      onPressed: () => provider.disconnect(),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'DISCONNECT',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Build status indicator widget
  Widget _buildStatusIndicator(AudioStreamProvider provider) {
    Color statusColor = Colors.grey;
    String statusText = 'Disconnected';

    switch (provider.connectionState) {
      case StreamConnectionState.disconnected:
        statusColor = Colors.grey;
        statusText = 'Disconnected';
        break;
      case StreamConnectionState.connecting:
        statusColor = Colors.orange;
        statusText = 'Connecting...';
        break;
      case StreamConnectionState.connected:
        statusColor = Colors.green;
        statusText = 'Connected';
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Build statistics widget
  Widget _buildStatistics(AudioStreamProvider provider) {
    final kbps = provider.bytesSent > 0
        ? (provider.bytesSent * 8 / 1000).toStringAsFixed(1)
        : '0.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildStatRow('Packets Sent', '${provider.packetsSent}'),
          const Divider(color: Colors.white24, height: 24),
          _buildStatRow(
              'Data Sent', '${(provider.bytesSent / 1024).toStringAsFixed(1)} KB'),
          const Divider(color: Colors.white24, height: 24),
          _buildStatRow('Bitrate', '$kbps kbps'),
        ],
      ),
    );
  }

  /// Build statistics row
  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
