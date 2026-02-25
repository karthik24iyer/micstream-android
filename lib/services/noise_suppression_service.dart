import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// ─── FFI native function type definitions ────────────────────────────────────

// DenoiseState* rnnoise_create(RNNModel* model)  — pass null for built-in model
typedef _RnnoiseCreateNative = Pointer<Void> Function(Pointer<Void>);
typedef _RnnoiseCreate = Pointer<Void> Function(Pointer<Void>);

// void rnnoise_destroy(DenoiseState* st)
typedef _RnnoiseDestroyNative = Void Function(Pointer<Void>);
typedef _RnnoiseDestroy = void Function(Pointer<Void>);

// float rnnoise_process_frame(DenoiseState* st, float* out, const float* in)
typedef _RnnoiseProcessFrameNative = Float Function(
    Pointer<Void>, Pointer<Float>, Pointer<Float>);
typedef _RnnoiseProcessFrame = double Function(
    Pointer<Void>, Pointer<Float>, Pointer<Float>);

// ─── Service ─────────────────────────────────────────────────────────────────

/// NoiseSuppressionService — RNNoise background noise suppression via Dart FFI
///
/// Phase 4: Processes PCM audio through the RNNoise neural network to suppress
/// keyboard clicks, fan hum, and ambient noise before Opus encoding.
///
/// Frame size: 480 samples (10ms @ 48kHz, 16-bit mono).
/// For 20ms Opus frames (960 samples / 1920 bytes), call [processOpusFrame]
/// which internally splits into two 10ms halves.
///
/// Requires librnnoise.so built by the Android CMake configuration.
/// Run scripts/setup_rnnoise.sh (or .ps1) then `flutter build apk --release`
/// to compile the native library. If the .so is not present, the service
/// gracefully returns the input audio unchanged.
class NoiseSuppressionService {
  static const int _frameSize = 480; // 10ms at 48kHz
  static const int _frameSizeBytes = _frameSize * 2; // 16-bit = 2 bytes/sample

  DynamicLibrary? _lib;
  Pointer<Void> _state = nullptr;

  _RnnoiseCreate? _fnCreate;
  _RnnoiseDestroy? _fnDestroy;
  _RnnoiseProcessFrame? _fnProcessFrame;

  bool _isInitialized = false;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Load librnnoise.so and create a RNNoise denoiser state.
  /// Returns true on success, false if the library is unavailable (app continues
  /// to work, audio is passed through unprocessed).
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _lib = DynamicLibrary.open('librnnoise.so');

      _fnCreate = _lib!
          .lookupFunction<_RnnoiseCreateNative, _RnnoiseCreate>('rnnoise_create');
      _fnDestroy = _lib!
          .lookupFunction<_RnnoiseDestroyNative, _RnnoiseDestroy>('rnnoise_destroy');
      _fnProcessFrame = _lib!.lookupFunction<_RnnoiseProcessFrameNative,
          _RnnoiseProcessFrame>('rnnoise_process_frame');

      // null → use default built-in model (weights compiled into rnn_data.c)
      _state = _fnCreate!(nullptr);
      if (_state == nullptr) {
        print('NoiseSuppressionService: rnnoise_create returned null');
        return false;
      }

      _isInitialized = true;
      print(
          'NoiseSuppressionService: Initialized — RNNoise 10ms frames, 48kHz mono');
      return true;
    } catch (e) {
      // Library not present (setup script not run yet, or debug build without NDK)
      print('NoiseSuppressionService: librnnoise.so not available — $e');
      print(
          'NoiseSuppressionService: Run scripts/setup_rnnoise.sh then rebuild to enable noise suppression.');
      return false;
    }
  }

  void dispose() {
    if (_isInitialized && _state != nullptr) {
      _fnDestroy!(_state);
      _state = nullptr;
      _isInitialized = false;
    }
    _lib = null;
    print('NoiseSuppressionService: Disposed');
  }

  // ─── Properties ────────────────────────────────────────────────────────────

  bool get isInitialized => _isInitialized;

  // ─── Processing ────────────────────────────────────────────────────────────

  /// Process a 20ms Opus frame: 960 samples / 1920 bytes of 16-bit PCM.
  /// Splits internally into two 10ms RNNoise frames.
  /// Returns the cleaned frame, or the original if NS is disabled/unavailable.
  Uint8List processOpusFrame(Uint8List pcmData) {
    assert(pcmData.length == 1920,
        'Expected 1920 bytes for a 20ms frame, got ${pcmData.length}');

    if (!_isInitialized) return pcmData;

    final first = _processFrame480(Uint8List.sublistView(pcmData, 0, 960));
    final second = _processFrame480(Uint8List.sublistView(pcmData, 960, 1920));

    final result = Uint8List(1920);
    result.setRange(0, 960, first);
    result.setRange(960, 1920, second);
    return result;
  }

  /// Process a single 10ms frame: exactly 480 samples / 960 bytes of 16-bit PCM.
  Uint8List _processFrame480(Uint8List pcmData) {
    assert(pcmData.length == _frameSizeBytes,
        'Expected $_frameSizeBytes bytes, got ${pcmData.length}');

    final inputPtr  = calloc<Float>(_frameSize);
    final outputPtr = calloc<Float>(_frameSize);

    try {
      final int16View =
          pcmData.buffer.asInt16List(pcmData.offsetInBytes, _frameSize);

      // int16 → float  (RNNoise expects raw int16 range: -32768 to 32767)
      for (int i = 0; i < _frameSize; i++) {
        inputPtr[i] = int16View[i].toDouble();
      }

      // Run RNNoise (return value is the voice activity probability, unused here)
      _fnProcessFrame!(_state, outputPtr, inputPtr);

      // float → int16 (clamp to prevent overflow)
      final result = Int16List(_frameSize);
      for (int i = 0; i < _frameSize; i++) {
        result[i] = outputPtr[i].round().clamp(-32768, 32767);
      }

      return result.buffer.asUint8List();
    } finally {
      calloc.free(inputPtr);
      calloc.free(outputPtr);
    }
  }
}
