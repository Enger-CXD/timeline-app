import 'dart:typed_data';

import 'package:flutter/services.dart';

/// 与 Android 原生交互：视频缩略图 / PDF 渲染 / 定位 / 导航
///
/// 全部走 MethodChannel，不额外引入第三方插件，行为可预期、易排查。
class FileNative {
  static const MethodChannel _media = MethodChannel('timeline/media');
  static const MethodChannel _file = MethodChannel('timeline/file');
  static const MethodChannel _location = MethodChannel('timeline/location');
  static const MethodChannel _nav = MethodChannel('timeline/nav');

  // ---------------- 视频 ----------------

  /// 视频时长（毫秒），失败返回 0
  static Future<int> videoDurationMs(String path) async {
    try {
      final r = await _media.invokeMethod<int>('duration', {'path': path});
      return r ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 视频首帧缩略图（PNG），失败返回 null
  static Future<Uint8List?> videoThumb(String path, {int width = 320}) async {
    try {
      final r = await _media.invokeMethod<Uint8List>(
        'thumb',
        {'path': path, 'width': width},
      );
      return r;
    } catch (_) {
      return null;
    }
  }

  // ---------------- PDF ----------------

  /// PDF 页数，失败返回 0
  static Future<int> pdfPageCount(String path) async {
    try {
      final r = await _file.invokeMethod<int>('pdfPages', {'path': path});
      return r ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 渲染 PDF 第 index 页（从 0 开始）为 PNG 字节
  static Future<Uint8List?> pdfRenderPage(
    String path,
    int index, {
    int width = 1000,
  }) async {
    try {
      final r = await _file.invokeMethod<Uint8List>(
        'pdfRender',
        {'path': path, 'index': index, 'width': width},
      );
      return r;
    } catch (_) {
      return null;
    }
  }

  // ---------------- 定位 ----------------

  /// 获取当前位置并反查“省 + 市”。
  /// 返回 null 表示失败；返回 map 时可能只含 province/city 之一。
  static Future<Map<String, dynamic>?> currentLocation() async {
    try {
      final r = await _location.invokeMethod<Map<dynamic, dynamic>>('current');
      if (r == null) return null;
      return Map<String, dynamic>.from(r);
    } on PlatformException catch (e) {
      if (e.code == 'PERM') {
        throw const PermissionNeeded();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ---------------- 导航 ----------------------------

  /// 打开导航 App（依次尝试 高德 / 百度 / 系统 geo:）
  static Future<bool> openNavigation({
    required double lat,
    required double lng,
    required String name,
  }) async {
    try {
      final r = await _nav.invokeMethod<bool>(
        'open',
        {'lat': lat, 'lng': lng, 'name': name},
      );
      return r ?? false;
    } catch (_) {
      return false;
    }
  }
}

/// 还没有定位权限（需要用户在弹出的系统对话框里允许）
class PermissionNeeded implements Exception {
  const PermissionNeeded();
  @override
  String toString() => '需要定位权限';
}
