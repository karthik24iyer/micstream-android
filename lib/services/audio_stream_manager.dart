import 'dart:typed_data';
import 'audio_capture_service.dart';
import 'udp_sender_service.dart';
import 'opus_encoder_service.dart';
import 'noise_suppression_service.dart';

/// AudioStreamManager - Orchestrates the audio capture → NS → Opus → UDP pipeline
/// Phase 3: Opus compressed streaming (64kbps)
/// Phase 4: RNNoise noise suppression inserted before Opus encoding
class AudioStreamManager {
  final AudioCaptureService _audioCapture = AudioCaptureService();
  final UdpSenderService _udpSender = UdpSenderService();
  final OpusEncoderService _opusEncoder = OpusEncoderService();
  final NoiseSuppressionService _noiseSuppress = NoiseSuppressionService();

  bool _isStreaming = false;

  // Frame buffering for Opus (needs exactly 1920 bytes = 960 samples)
  final List<int> _frameBuffer = [];
  static const int _opusFrameSize = 1920; // 960 samples * 2 bytes

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

    if (!await _opusEncoder.initialize()) {
      print('AudioStreamManager: Failed to initialize Opus encoder');
      return false;
    }

    // Phase 4: initialize RNNoise (non-fatal — streaming works without it)
    final nsReady = await _noiseSuppress.initialize();
    if (!nsReady) {
      print('AudioStreamManager: Noise suppression unavailable — streaming without NS');
    }

    if (!await _udpSender.initialize()) {
      print('AudioStreamManager: Failed to initialize UDP sender');
      _opusEncoder.dispose();
      _noiseSuppress.dispose();
      return false;
    }

    _udpSender.setDestination(destinationAddress, port: port);
    _frameBuffer.clear();
    _audioCapture.onAudioData = _handleAudioData;

    if (!await _audioCapture.startCapture()) {
      print('AudioStreamManager: Failed to start audio capture');
      await _udpSender.close();
      _opusEncoder.dispose();
      _noiseSuppress.dispose();
      return false;
    }

    _isStreaming = true;
    _streamStartTime = DateTime.now();
    _packetsent = 0;
    _bytesSent = 0;

    final nsStatus = _noiseSuppress.isInitialized ? 'NS ON' : 'NS unavailable';
    print('AudioStreamManager: Streaming started to $destinationAddress:$port (Opus 64kbps, $nsStatus)');
    return true;
  }

  /// Handle audio data from capture service — buffer, denoise, encode, send
  Future<void> _handleAudioData(Uint8List pcmData) async {
    // Add incoming data to buffer
    _frameBuffer.addAll(pcmData);

    // Process ALL complete 20ms frames
    while (_frameBuffer.length >= _opusFrameSize) {
      // Extract one 960-sample frame
      final frameData = Uint8List.fromList(_frameBuffer.sublist(0, _opusFrameSize));
      _frameBuffer.removeRange(0, _opusFrameSize);

      // Phase 4: apply noise suppression before Opus encoding
      final cleanFrame = _noiseSuppress.processOpusFrame(frameData);

      // Encode and send (await ensures sequential sending)
      final opusData = _opusEncoder.encode(cleanFrame);
      if (opusData != null && opusData.isNotEmpty) {
        final nsActive = _noiseSuppress.isInitialized;
        final success = await _udpSender.sendOpusPacket(opusData, noiseSuppressed: nsActive);
        if (success) {
          _packetsent++;
          // Opus packet: 4 (seq) + 4 (timestamp) + 1 (flags) + opus_data (~160 bytes)
          _bytesSent += 9 + opusData.length;
        }
      }
    }
  }

  /// Stop streaming
  Future<void> stopStreaming() async {
    if (!_isStreaming) {
      return;
    }

    await _audioCapture.stopCapture();
    await _udpSender.close();
    _opusEncoder.dispose();
    _noiseSuppress.dispose();

    _frameBuffer.clear();
    _isStreaming = false;

    final duration = _streamStartTime != null
        ? DateTime.now().difference(_streamStartTime!)
        : Duration.zero;

    print('AudioStreamManager: Streaming stopped');
    print('  Duration: ${duration.inSeconds}s');
    print('  Packets sent: $_packetsent');
    print('  Bytes sent: $_bytesSent');

    if (duration.inSeconds > 0) {
      final avgBitrate = (_bytesSent * 8) / duration.inSeconds;
      print('  Avg bitrate: ${(avgBitrate / 1000).toStringAsFixed(1)} kbps');
    }
  }

  // ─── Status / Statistics ──────────────────────────────────────────────────

  bool get isStreaming => _isStreaming;
  int get packetsSent => _packetsent;
  int get bytesSent => _bytesSent;
  int get sequenceNumber => _udpSender.sequenceNumber;

  /// Cleanup resources
  Future<void> dispose() async {
    await stopStreaming();
    _audioCapture.dispose();
  }
}
