import 'dart:io';
import 'dart:typed_data';
import 'package:udp/udp.dart';

/// UdpSenderService - Sends audio packets via UDP
/// Phase 1: [seq(4)][pcm_data] packet format
class UdpSenderService {
  UDP? _socket;
  String? _destinationAddress;
  int _destinationPort = 5005;

  int _sequenceNumber = 0;
  bool _isInitialized = false;

  /// Initialize UDP socket
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    try {
      // Bind to any available port
      _socket = await UDP.bind(Endpoint.any());
      _isInitialized = true;
      print('UdpSenderService: Socket initialized');
      return true;
    } catch (e) {
      print('UdpSenderService: Failed to initialize socket - $e');
      return false;
    }
  }

  /// Set destination address and port
  void setDestination(String address, {int port = 5005}) {
    _destinationAddress = address;
    _destinationPort = port;
    print('UdpSenderService: Destination set to $address:$port');
  }

  /// Send audio packet with sequence number
  /// Phase 1 format: [4 bytes: sequence][PCM data]
  Future<bool> sendAudioPacket(Uint8List pcmData) async {
    if (!_isInitialized || _socket == null) {
      print('UdpSenderService: Socket not initialized');
      return false;
    }

    if (_destinationAddress == null) {
      print('UdpSenderService: Destination not set');
      return false;
    }

    try {
      // Create packet: [sequence(4 bytes)][PCM data]
      final packet = BytesBuilder();

      // Add sequence number (4 bytes, big-endian)
      packet.add(_uint32ToBytes(_sequenceNumber));

      // Add PCM audio data
      packet.add(pcmData);

      // Send via UDP
      final endpoint = Endpoint.unicast(
        InternetAddress(_destinationAddress!),
        port: Port(_destinationPort),
      );

      final bytesSent = await _socket!.send(
        packet.toBytes(),
        endpoint,
      );

      if (bytesSent > 0) {
        _sequenceNumber++;
        return true;
      } else {
        print('UdpSenderService: Failed to send packet');
        return false;
      }

    } catch (e) {
      print('UdpSenderService: Error sending packet - $e');
      return false;
    }
  }

  /// Convert uint32 to big-endian bytes
  Uint8List _uint32ToBytes(int value) {
    final data = Uint8List(4);
    data.buffer.asByteData().setUint32(0, value, Endian.big);
    return data;
  }

  /// Get current sequence number
  int get sequenceNumber => _sequenceNumber;

  /// Reset sequence number
  void resetSequence() {
    _sequenceNumber = 0;
  }

  /// Close socket and cleanup
  Future<void> close() async {
    if (_socket != null) {
      _socket!.close();
      _socket = null;
      _isInitialized = false;
      _sequenceNumber = 0;
      print('UdpSenderService: Socket closed');
    }
  }

  /// Check if initialized
  bool get isInitialized => _isInitialized;
}
