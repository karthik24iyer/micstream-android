import 'package:flutter/services.dart';

/// Thin wrapper around the Android foreground-service MethodChannel.
/// On non-Android platforms the calls are no-ops so the same code
/// can be used without platform guards in callers.
class ForegroundService {
  static const _channel = MethodChannel('com.micstream/foreground_service');

  static Future<void> start() async {
    try {
      await _channel.invokeMethod('start');
    } on MissingPluginException {
      // Running on a platform without the native side (web, desktop, etc.)
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } on MissingPluginException {
      // Running on a platform without the native side
    }
  }
}
