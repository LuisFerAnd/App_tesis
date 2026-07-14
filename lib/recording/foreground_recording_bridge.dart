import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class ForegroundRecordingBridge {
  Future<bool> start();

  Future<void> stop();

  Future<bool> isRunning();

  Future<bool> ensureNotificationPermission();

  Future<bool> areNotificationsEnabled();
}

class AndroidForegroundRecordingBridge implements ForegroundRecordingBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.sanare.sanare_mobile/recording_service',
  );

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> start() async {
    if (!_isAndroid) return true;
    return await _channel.invokeMethod<bool>('start') ?? false;
  }

  @override
  Future<void> stop() async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('stop');
  }

  @override
  Future<bool> isRunning() async {
    if (!_isAndroid) return true;
    return await _channel.invokeMethod<bool>('isRunning') ?? false;
  }

  @override
  Future<bool> ensureNotificationPermission() async {
    if (!_isAndroid) return true;
    return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
        false;
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    if (!_isAndroid) return true;
    return await _channel.invokeMethod<bool>('notificationsEnabled') ?? false;
  }
}
