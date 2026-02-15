import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

/// AudioCaptureService - Captures microphone audio at 48kHz, 16-bit PCM, mono
/// Phase 1: Raw PCM audio capture
class AudioCaptureService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  bool _isCapturing = false;

  /// Callback when audio data is available
  Function(Uint8List)? onAudioData;

  /// Start capturing audio from microphone
  Future<bool> startCapture() async {
    if (_isCapturing) {
      print('AudioCaptureService: Already capturing');
      return true;
    }

    try {
      // Check microphone permission
      if (!await _recorder.hasPermission()) {
        print('AudioCaptureService: Microphone permission denied');
        return false;
      }

      // Configure recording settings
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits, // 16-bit PCM
        sampleRate: 48000,                // 48kHz
        numChannels: 1,                   // Mono
        bitRate: 768000,                  // 48000 * 16 * 1 = 768kbps
      );

      // Start recording stream
      final stream = await _recorder.startStream(config);

      _audioStreamSubscription = stream.listen(
        (audioData) {
          // Forward raw PCM data to callback
          onAudioData?.call(audioData);
        },
        onError: (error) {
          print('AudioCaptureService: Stream error - $error');
          stopCapture();
        },
        onDone: () {
          print('AudioCaptureService: Stream closed');
          _isCapturing = false;
        },
      );

      _isCapturing = true;
      print('AudioCaptureService: Capture started (48kHz, 16-bit PCM, mono)');
      return true;

    } catch (e) {
      print('AudioCaptureService: Failed to start capture - $e');
      return false;
    }
  }

  /// Stop capturing audio
  Future<void> stopCapture() async {
    if (!_isCapturing) {
      return;
    }

    try {
      await _audioStreamSubscription?.cancel();
      await _recorder.stop();
      _isCapturing = false;
      print('AudioCaptureService: Capture stopped');
    } catch (e) {
      print('AudioCaptureService: Error stopping capture - $e');
    }
  }

  /// Check if currently capturing
  bool get isCapturing => _isCapturing;

  /// Cleanup resources
  void dispose() {
    stopCapture();
    _recorder.dispose();
  }
}
