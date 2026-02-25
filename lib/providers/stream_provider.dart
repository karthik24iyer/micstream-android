import 'package:flutter/foundation.dart';
import '../services/audio_stream_manager.dart';
import '../services/discovery_service.dart';

/// StreamProvider - State management for audio streaming
/// Phase 1: Basic connection state and statistics
/// Phase 2: mDNS service discovery
/// Phase 4: Noise suppression toggle
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

  // ─── Getters ───────────────────────────────────────────────────────────────

  StreamConnectionState get connectionState => _connectionState;
  String? get destinationAddress => _destinationAddress;
  String? get destinationName => _destinationName;
  String? get errorMessage => _errorMessage;

  bool get isScanning => _isScanning;
  List<DiscoveredDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  int get packetsSent => _packetsSent;
  int get bytesSent => _bytesSent;
  bool get isStreaming => _connectionState == StreamConnectionState.connected;

  // ─── Connection ────────────────────────────────────────────────────────────

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

      await Future.delayed(const Duration(seconds: 1));

      if (_connectionState == StreamConnectionState.connected) {
        _packetsSent = _streamManager.packetsSent;
        _bytesSent = _streamManager.bytesSent;
        notifyListeners();
      }

      return _connectionState == StreamConnectionState.connected;
    });
  }

  // ─── Phase 2: Discovery ────────────────────────────────────────────────────

  Future<bool> startScanning() async {
    if (_isScanning) return true;

    _discoveredDevices.clear();
    notifyListeners();

    _discoveryService.onDeviceDiscovered = (device) {
      if (!_discoveredDevices.any((d) => d.host == device.host)) {
        _discoveredDevices.add(device);
        notifyListeners();
        stopScanning();
      }
    };

    final success = await _discoveryService.startDiscovery();
    _isScanning = success;
    notifyListeners();
    return success;
  }

  Future<void> stopScanning() async {
    await _discoveryService.stopScanning();
    _isScanning = false;
    notifyListeners();
  }

  Future<bool> connectToDevice(DiscoveredDevice device) async {
    if (_connectionState == StreamConnectionState.connected) return true;

    await stopScanning();

    _connectionState = StreamConnectionState.connecting;
    _destinationAddress = device.host;
    _destinationName = device.displayName;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _streamManager.startStreaming(device.host);
      if (success) {
        _connectionState = StreamConnectionState.connected;
        _startStatisticsUpdater();
      } else {
        _connectionState = StreamConnectionState.disconnected;
        _errorMessage = 'Failed to start streaming';
      }
    } catch (e) {
      _connectionState = StreamConnectionState.disconnected;
      _errorMessage = 'Error: $e';
    }

    notifyListeners();
    return _connectionState == StreamConnectionState.connected;
  }

  @override
  void dispose() {
    _streamManager.dispose().then((_) {
      _discoveryService.dispose();
    });
    super.dispose();
  }
}

/// Connection state enum
enum StreamConnectionState {
  disconnected,
  connecting,
  connected,
}
