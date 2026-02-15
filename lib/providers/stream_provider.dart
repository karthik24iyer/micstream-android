import 'package:flutter/foundation.dart';
import '../services/audio_stream_manager.dart';
import '../services/discovery_service.dart';

/// StreamProvider - State management for audio streaming
/// Phase 1: Basic connection state and statistics
/// Phase 2: mDNS service discovery
class AudioStreamProvider with ChangeNotifier {
  final AudioStreamManager _streamManager = AudioStreamManager();
  final DiscoveryService _discoveryService = DiscoveryService();

  // Connection state
  StreamConnectionState _connectionState = StreamConnectionState.disconnected;
  String? _destinationAddress;
  String? _destinationName;
  String? _errorMessage;

  // Discovery state (Phase 2)
  bool _isScanning = false;
  List<DiscoveredDevice> _discoveredDevices = [];

  // Statistics
  int _packetsSent = 0;
  int _bytesSent = 0;

  /// Get current connection state
  StreamConnectionState get connectionState => _connectionState;

  /// Get destination address
  String? get destinationAddress => _destinationAddress;

  /// Get destination name
  String? get destinationName => _destinationName;

  /// Get error message
  String? get errorMessage => _errorMessage;

  /// Get discovery scanning status (Phase 2)
  bool get isScanning => _isScanning;

  /// Get discovered devices (Phase 2)
  List<DiscoveredDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  /// Get packets sent
  int get packetsSent => _packetsSent;

  /// Get bytes sent
  int get bytesSent => _bytesSent;

  /// Get streaming status
  bool get isStreaming => _connectionState == StreamConnectionState.connected;

  /// Connect and start streaming
  Future<bool> connect(String ipAddress) async {
    if (_connectionState == StreamConnectionState.connected) {
      return true;
    }

    // Validate IP address format
    if (!_isValidIpAddress(ipAddress)) {
      _errorMessage = 'Invalid IP address format';
      notifyListeners();
      return false;
    }

    _connectionState = StreamConnectionState.connecting;
    _destinationAddress = ipAddress;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _streamManager.startStreaming(ipAddress);

      if (success) {
        _connectionState = StreamConnectionState.connected;
        _startStatisticsUpdater();
        notifyListeners();
        return true;
      } else {
        _connectionState = StreamConnectionState.disconnected;
        _errorMessage = 'Failed to start streaming';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _connectionState = StreamConnectionState.disconnected;
      _errorMessage = 'Error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Validate IP address format (IPv4)
  bool _isValidIpAddress(String ip) {
    if (ip.isEmpty) return false;

    final parts = ip.split('.');
    if (parts.length != 4) return false;

    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return false;
      }
    }

    return true;
  }

  /// Disconnect and stop streaming
  Future<void> disconnect() async {
    if (_connectionState == StreamConnectionState.disconnected) {
      return;
    }

    await _streamManager.stopStreaming();

    _connectionState = StreamConnectionState.disconnected;
    _destinationAddress = null;
    _packetsSent = 0;
    _bytesSent = 0;
    notifyListeners();
  }

  /// Start periodic statistics update
  void _startStatisticsUpdater() {
    Future.doWhile(() async {
      if (_connectionState != StreamConnectionState.connected) {
        return false;
      }

      // Update statistics every second
      await Future.delayed(const Duration(seconds: 1));

      if (_connectionState == StreamConnectionState.connected) {
        _packetsSent = _streamManager.packetsSent;
        _bytesSent = _streamManager.bytesSent;
        notifyListeners();
      }

      return _connectionState == StreamConnectionState.connected;
    });
  }

  // ========== Phase 2: Discovery Methods ==========

  /// Start scanning for devices (Phase 2)
  Future<bool> startScanning() async {
    if (_isScanning) {
      return true;
    }

    _discoveredDevices.clear();
    notifyListeners();

    // Set up callbacks
    _discoveryService.onDeviceDiscovered = (device) {
      if (!_discoveredDevices.any((d) => d.host == device.host)) {
        _discoveredDevices.add(device);
        notifyListeners();
      }
    };

    final success = await _discoveryService.startDiscovery();
    _isScanning = success;
    notifyListeners();

    return success;
  }

  /// Stop scanning (Phase 2)
  Future<void> stopScanning() async {
    await _discoveryService.stopScanning();
    _isScanning = false;
    notifyListeners();
  }

  /// Connect to a discovered device (Phase 2)
  Future<bool> connectToDevice(DiscoveredDevice device) async {
    // Stop scanning before connecting
    await stopScanning();

    _destinationName = device.displayName;

    // Connect using IP address
    return await connect(device.host);
  }

  @override
  void dispose() {
    _streamManager.dispose();
    _discoveryService.dispose();
    super.dispose();
  }
}

/// Connection state enum
enum StreamConnectionState {
  disconnected,
  connecting,
  connected,
}
