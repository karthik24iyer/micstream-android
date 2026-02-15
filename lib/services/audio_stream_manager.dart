import 'dart:typed_data';
import 'audio_capture_service.dart';
import 'udp_sender_service.dart';

/// AudioStreamManager - Orchestrates the audio capture → UDP pipeline
/// Phase 1: Direct PCM streaming (no encoding)
class AudioStreamManager {
  final AudioCaptureService _audioCapture = AudioCaptureService();
  final UdpSenderService _udpSender = UdpSenderService();

  bool _isStreaming = false;

  // Statistics
  int _packetsent = 0;
  int _bytesSent = 0;
  DateTime? _streamStartTime;

  /// Start streaming audio to destination
  Future<bool> startStreaming(String destinationAddress, {int port = 5005}) async {
    if (_isStreaming) {
      print('AudioStreamManager: Already streaming');
      return true;
    }

    // Initialize UDP sender
    if (!await _udpSender.initialize()) {
      print('AudioStreamManager: Failed to initialize UDP sender');
      return false;
    }

    // Set destination
    _udpSender.setDestination(destinationAddress, port: port);

    // Set audio data callback
    _audioCapture.onAudioData = _handleAudioData;

    // Start microphone capture
    if (!await _audioCapture.startCapture()) {
      print('AudioStreamManager: Failed to start audio capture');
      await _udpSender.close();
      return false;
    }

    _isStreaming = true;
    _streamStartTime = DateTime.now();
    _packetsent = 0;
    _bytesSent = 0;

    print('AudioStreamManager: Streaming started to $destinationAddress:$port');
    return true;
  }

  /// Handle audio data from capture service
  void _handleAudioData(Uint8List pcmData) {
    if (!_isStreaming) {
      return;
    }

    // Send PCM data via UDP
    _udpSender.sendAudioPacket(pcmData).then((success) {
      if (success) {
        _packetsent++;
        _bytesSent += pcmData.length + 4; // PCM data + 4 bytes sequence
      }
    });
  }

  /// Stop streaming
  Future<void> stopStreaming() async {
    if (!_isStreaming) {
      return;
    }

    await _audioCapture.stopCapture();
    await _udpSender.close();

    _isStreaming = false;

    final duration = _streamStartTime != null
        ? DateTime.now().difference(_streamStartTime!)
        : Duration.zero;

    print('AudioStreamManager: Streaming stopped');
    print('  Duration: ${duration.inSeconds}s');
    print('  Packets sent: $_packetsent');
    print('  Bytes sent: $_bytesSent');
  }

  /// Get streaming status
  bool get isStreaming => _isStreaming;

  /// Get packets sent
  int get packetsSent => _packetsent;

  /// Get bytes sent
  int get bytesSent => _bytesSent;

  /// Get current sequence number
  int get sequenceNumber => _udpSender.sequenceNumber;

  /// Cleanup resources
  void dispose() {
    stopStreaming();
    _audioCapture.dispose();
  }
}
