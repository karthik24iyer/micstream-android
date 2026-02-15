import 'dart:async';

/// DiscoveryService - mDNS service discovery for Phase 2
/// Discovers Windows PC broadcasting _micstream._udp.local service
///
/// NOTE: This is a stub implementation for Phase 2.
/// The nsd package API will be properly integrated during testing.
class DiscoveryService {
  // Discovered services
  final List<DiscoveredDevice> _devices = [];

  /// Callback when a new device is discovered
  Function(DiscoveredDevice)? onDeviceDiscovered;

  /// Callback when a device is lost
  Function(DiscoveredDevice)? onDeviceLost;

  bool _isScanning = false;

  /// Start scanning for MicStream services
  /// TODO: Implement with proper nsd package API during testing
  Future<bool> startDiscovery() async {
    if (_isScanning) {
      print('DiscoveryService: Already scanning');
      return true;
    }

    try {
      _isScanning = true;
      print('DiscoveryService: Started scanning for _micstream._udp.local');
      print('DiscoveryService: Note - nsd integration pending, use Manual IP mode for now');

      // TODO: Implement actual nsd discovery when Windows server is ready
      // For now, this is a placeholder that compiles

      return true;

    } catch (e) {
      print('DiscoveryService: Failed to start discovery - $e');
      return false;
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    if (!_isScanning) {
      return;
    }

    _isScanning = false;
    print('DiscoveryService: Stopped scanning');
  }

  /// Get list of discovered devices
  List<DiscoveredDevice> get devices => List.unmodifiable(_devices);

  /// Clear discovered devices
  void clearDevices() {
    _devices.clear();
  }

  /// Check if currently scanning
  bool get isScanning => _isScanning;

  /// Cleanup resources
  void dispose() {
    stopScanning();
  }
}

/// Discovered device model
class DiscoveredDevice {
  final String name;
  final String host;
  final int port;
  final Map<String, String> txt;

  DiscoveredDevice({
    required this.name,
    required this.host,
    required this.port,
    required this.txt,
  });

  /// Get version from TXT record
  String? get version => txt['version'];

  /// Get capabilities from TXT record
  String? get capabilities => txt['capabilities'];

  /// Display name (PC name without service suffix)
  String get displayName {
    // Remove ._micstream._udp.local suffix if present
    return name.split('.').first;
  }

  @override
  String toString() => '$displayName ($host:$port)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => host.hashCode ^ port.hashCode;
}
