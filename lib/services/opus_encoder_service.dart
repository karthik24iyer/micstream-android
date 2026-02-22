import 'dart:typed_data';
import 'package:opus_dart/opus_dart.dart';

/// OpusEncoderService - Encodes PCM audio to Opus format
/// Phase 3: 48kHz, 64kbps, 20ms frames (960 samples)
/// Note: Opus library must be initialized in main.dart before creating encoder
class OpusEncoderService {
  SimpleOpusEncoder? _encoder;
  bool _isInitialized = false;

  static const int _sampleRate = 48000;
  static const int _channels = 1;
  static const int _frameSize = 960; // 20ms at 48kHz

  /// Initialize Opus encoder
  /// Note: Opus library is initialized globally in main.dart
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    try {
      // Create Opus encoder instance (library already initialized in main.dart)
      _encoder = SimpleOpusEncoder(
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
      );

      _isInitialized = true;
      print('OpusEncoderService: Encoder initialized (48kHz, mono, VOIP mode, 20ms frames)');
      return true;
    } catch (e) {
      print('OpusEncoderService: Failed to initialize encoder - $e');
      return false;
    }
  }

  /// Encode PCM data to Opus
  /// Input: 16-bit PCM data (960 samples = 1920 bytes for 20ms frame)
  /// Output: Opus encoded data (~160 bytes at 64kbps)
  Uint8List? encode(Uint8List pcmData) {
    if (!_isInitialized || _encoder == null) {
      print('OpusEncoderService: Encoder not initialized');
      return null;
    }

    try {
      return _encoder!.encode(input: _bytesToInt16List(pcmData));
    } catch (e) {
      print('OpusEncoderService: Encoding error - $e');
      return null;
    }
  }

  /// Convert byte array to Int16List
  Int16List _bytesToInt16List(Uint8List bytes) {
    final buffer = bytes.buffer;
    return buffer.asInt16List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 2);
  }

  /// Cleanup resources
  void dispose() {
    if (_encoder != null) {
      _encoder!.destroy();
      _encoder = null;
      _isInitialized = false;
    }
  }
}
