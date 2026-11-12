import 'dart:async';

import 'package:flutter/services.dart';

/// 录音播放：调用 Android 原生 MediaPlayer（见 MainActivity.kt），
/// 不依赖第三方音频插件。
class NativeAudio {
  static const MethodChannel _channel = MethodChannel('timeline/audio');
  static final StreamController<void> _completed =
      StreamController<void>.broadcast();
  static bool _inited = false;

  static void _ensureInit() {
    if (_inited) return;
    _inited = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'completed') _completed.add(null);
      return null;
    });
  }

  /// 播放结束（或播放出错）时触发
  static Stream<void> get onCompleted {
    _ensureInit();
    return _completed.stream;
  }

  static Future<void> play(String path) async {
    _ensureInit();
    await _channel.invokeMethod('play', {'path': path});
  }

  static Future<void> stop() async {
    _ensureInit();
    await _channel.invokeMethod('stop');
  }
}
