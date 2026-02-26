import 'dart:async';
import 'dart:typed_data';
import 'package:nsd/nsd.dart' as nsd;

/// DiscoveryService - mDNS service discovery
/// Discovers Windows PC broadcasting _micstream._udp.local service
class DiscoveryService {
  final List<DiscoveredDevice> _devices = [];
  final Set<String> _resolving = {};
  nsd.Discovery? _discovery;

  Function(DiscoveredDevice)? onDeviceDiscovered;
  Function(DiscoveredDevice)? onDeviceLost;

  bool _isScanning = false;

  /// Start scanning for MicQ services
  Future<bool> startDiscovery() async {
    if (_isScanning) return true;

    _devices.clear();
    _resolving.clear();

    try {
      _discovery = await nsd.startDiscovery('_micstream._udp');
      _discovery!.addListener(_onServicesChanged);
      _isScanning = true;
      print('DiscoveryService: Scanning for _micstream._udp.local');
      return true;
    } catch (e) {
      print('DiscoveryService: Failed to start - $e');
      return false;
    }
  }

  void _onServicesChanged() {
    final discovery = _discovery;
    if (discovery == null) return;

    final services = discovery.services;

    // Handle lost devices (track by name since host may not be resolved yet)
    final currentNames = services.map((s) => s.name ?? '').toSet();
    _devices.removeWhere((device) {
      final lost = !currentNames.contains(device.name);
      if (lost) onDeviceLost?.call(device);
      return lost;
    });

    // Add/resolve new services
    for (final service in services) {
      final name = service.name ?? '';
      final host = service.host; // String? in nsd v4
      final port = service.port;

      if (host != null && port != null) {
        _tryAddDevice(name, host, port, service.txt);
      } else if (name.isNotEmpty && !_resolving.contains(name)) {
        _resolving.add(name);
        nsd.resolve(service).then((resolved) {
          _resolving.remove(name);
          final rHost = resolved.host;
          final rPort = resolved.port;
          if (rHost != null && rPort != null) {
            _tryAddDevice(resolved.name ?? name, rHost, rPort, resolved.txt);
          }
        }).catchError((e) {
          _resolving.remove(name);
          print('DiscoveryService: Resolve failed for $name - $e');
        });
      }
    }
  }

  void _tryAddDevice(
      String name, String host, int port, Map<String, Uint8List?>? txt) {
    if (_devices.any((d) => d.host == host)) return;

    final device = DiscoveredDevice(
      name: name,
      host: host,
      port: port,
      txt: _decodeTxt(txt),
    );
    _devices.add(device);
    onDeviceDiscovered?.call(device);
  }

  Map<String, String> _decodeTxt(Map<String, Uint8List?>? txt) {
    if (txt == null) return {};
    return txt.map((k, v) => MapEntry(k, v != null ? String.fromCharCodes(v) : ''));
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    if (_discovery != null) {
      _discovery!.removeListener(_onServicesChanged);
      await nsd.stopDiscovery(_discovery!);
      _discovery = null;
    }
    _resolving.clear();
    _isScanning = false;
    print('DiscoveryService: Stopped scanning');
  }

  List<DiscoveredDevice> get devices => List.unmodifiable(_devices);
  void clearDevices() => _devices.clear();
  bool get isScanning => _isScanning;

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

  String? get version => txt['version'];
  String? get capabilities => txt['capabilities'];

  String get displayName => name.split('.').first;

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
