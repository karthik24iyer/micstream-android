import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/stream_provider.dart';
import '../services/discovery_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _permissionGranted = false;
  bool _notificationGranted = true; // assume granted until checked

  @override
  void initState() {
    super.initState();
    _checkMicrophonePermission();
  }

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

    // Android 13+: request notification permission upfront so the
    // foreground-service notification is visible while streaming.
    final notifStatus = await Permission.notification.status;
    if (notifStatus.isDenied) {
      final result = await Permission.notification.request();
      setState(() => _notificationGranted = result.isGranted);
    } else {
      setState(() => _notificationGranted = notifStatus.isGranted);
    }
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      final result = await Permission.notification.request();
      setState(() => _notificationGranted = result.isGranted);
    }
  }

  Future<void> _handleDeviceConnect(
      AudioStreamProvider provider, DiscoveredDevice device) async {
    if (provider.isStreaming) {
      await provider.disconnect();
      return;
    }

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

  Future<void> _handleScan(AudioStreamProvider provider) async {
    if (provider.isScanning) {
      await provider.stopScanning();
    } else {
      await provider.startScanning();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
              padding: EdgeInsets.fromLTRB(
                24, 24, 24,
                24 + MediaQuery.of(context).size.height * 0.25,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'MicQ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 60),

                  _buildStatusIndicator(streamProvider),

                  const SizedBox(height: 45),

                  _buildDiscoveryMode(streamProvider),

                  const SizedBox(height: 16),

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

                  if (!_notificationGranted) ...[
                    const SizedBox(height: 12),
                    _buildNotificationBanner(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.yellow.withOpacity(0.08),
        border: Border.all(color: Colors.yellow.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_outlined, color: Colors.yellow, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Allow notifications to keep streaming with screen off',
              style: TextStyle(color: Colors.yellow.shade200, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _requestNotificationPermission,
            style: TextButton.styleFrom(
              foregroundColor: Colors.yellow,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryMode(AudioStreamProvider provider) {
    return Column(
      children: [
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 24),

        if (provider.discoveredDevices.isEmpty && provider.isScanning)
          Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Scanning for devices...',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          )
        else if (provider.discoveredDevices.isEmpty && !provider.isScanning)
          Text(
            'No devices found.\nMake sure Windows receiver is running.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          )
        else
          _buildDeviceList(provider),
      ],
    );
  }

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
        separatorBuilder: (_, __) =>
            Divider(color: Colors.white.withOpacity(0.1), height: 1),
        itemBuilder: (context, index) {
          final device = provider.discoveredDevices[index];
          return ListTile(
            leading: const Icon(Icons.computer, color: Colors.blue),
            title: Text(
              device.displayName,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${device.host}:${device.port}',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
            trailing: ElevatedButton(
              onPressed: () => _handleDeviceConnect(provider, device),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    provider.isStreaming ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              child:
                  Text(provider.isStreaming ? 'DISCONNECT' : 'CONNECT'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusIndicator(AudioStreamProvider provider) {
    Color statusColor;
    String statusText;

    switch (provider.connectionState) {
      case StreamConnectionState.connecting:
        statusColor = Colors.orange;
        statusText = 'Connecting...';
        break;
      case StreamConnectionState.connected:
        statusColor = Colors.green;
        statusText = 'Connected';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Disconnected';
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
              color: statusColor, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

}
