import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// 文件附件（PDF / Word）
class RecordAttachment {
  final String name; // 原始文件名，例如 报告.pdf
  final String path; // 应用私有目录中的本地路径
  final String kind; // pdf / docx / doc / other

  const RecordAttachment({
    required this.name,
    required this.path,
    required this.kind,
  });

  Map<String, dynamic> toMap() => {'name': name, 'path': path, 'kind': kind};

  static RecordAttachment fromMap(Map<String, dynamic> m) => RecordAttachment(
        name: (m['name'] ?? '') as String,
        path: (m['path'] ?? '') as String,
        kind: (m['kind'] ?? 'other') as String,
      );
}

/// 单条记录的数据模型
class RecordItem {
  final String id;
  String title;
  String content;
  String date; // yyyy-MM-dd
  String time; // HH:mm
  bool isCompleted;
  List<String> images; // 本地图片路径
  String voicePath; // 本地录音路径
  int voiceSeconds; // 录音时长（秒）
  List<String> videos; // 本地视频路径
  List<RecordAttachment> attachments; // PDF / Word 附件
  String locationName; // 例如 湖北省恩施市
  double locationLat;
  double locationLng;

  RecordItem({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.time,
    this.isCompleted = false,
    this.images = const [],
    this.voicePath = '',
    this.voiceSeconds = 0,
    this.videos = const [],
    this.attachments = const [],
    this.locationName = '',
    this.locationLat = 0,
    this.locationLng = 0,
  });

  bool get hasLocation => locationName.isNotEmpty;

  /// 时间轴节点标签，例如 "12:45" -> "12:00"
  String get dateTag =>
      time.length >= 2 ? '${time.substring(0, 2)}:00' : time;

  /// 日期 + 时间的排序键
  String get sortKey => '$date $time';

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'date': date,
        'time': time,
        'isCompleted': isCompleted,
        'images': images,
        'voicePath': voicePath,
        'voiceSeconds': voiceSeconds,
        'videos': videos,
        'attachments': attachments.map((e) => e.toMap()).toList(),
        'locationName': locationName,
        'locationLat': locationLat,
        'locationLng': locationLng,
      };

  static RecordItem fromMap(Map<String, dynamic> m) => RecordItem(
        id: m['id'] as String,
        title: (m['title'] ?? '') as String,
        content: (m['content'] ?? '') as String,
        date: (m['date'] ?? '') as String,
        time: (m['time'] ?? '') as String,
        isCompleted: (m['isCompleted'] ?? false) == true,
        images: ((m['images'] ?? const <String>[]) as List)
            .map((e) => e.toString())
            .toList(),
        voicePath: (m['voicePath'] ?? '') as String,
        voiceSeconds: (m['voiceSeconds'] ?? 0) as int,
        videos: ((m['videos'] ?? const <String>[]) as List)
            .map((e) => e.toString())
            .toList(),
        attachments: ((m['attachments'] ?? const []) as List)
            .whereType<Map>()
            .map((e) => RecordAttachment.fromMap(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        locationName: (m['locationName'] ?? '') as String,
        locationLat: ((m['locationLat'] ?? 0) as num).toDouble(),
        locationLng: ((m['locationLng'] ?? 0) as num).toDouble(),
      );

  RecordItem copyWith({
    String? title,
    String? content,
    String? date,
    String? time,
    bool? isCompleted,
    List<String>? images,
    String? voicePath,
    int? voiceSeconds,
    List<String>? videos,
    List<RecordAttachment>? attachments,
    String? locationName,
    double? locationLat,
    double? locationLng,
  }) =>
      RecordItem(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        date: date ?? this.date,
        time: time ?? this.time,
        isCompleted: isCompleted ?? this.isCompleted,
        images: images ?? this.images,
        voicePath: voicePath ?? this.voicePath,
        voiceSeconds: voiceSeconds ?? this.voiceSeconds,
        videos: videos ?? this.videos,
        attachments: attachments ?? this.attachments,
        locationName: locationName ?? this.locationName,
        locationLat: locationLat ?? this.locationLat,
        locationLng: locationLng ?? this.locationLng,
      );
}

/// 基于 Hive 的本地持久化存储
class RecordStore {
  static const _recordBoxName = 'records_v1';
  static const _settingBoxName = 'settings_v1';

  static late Box<String> _records;
  static late Box _settings;
  static String _filesDir = '';
  static bool _ready = false;

  /// 应用启动时调用一次
  static Future<void> init() async {
    await Hive.initFlutter();
    _records = await Hive.openBox<String>(_recordBoxName);
    _settings = await Hive.openBox(_settingBoxName);
    final docs = await getApplicationDocumentsDirectory();
    _filesDir = docs.path;
    _ready = true;
    await _seedIfEmpty();
  }

  static bool get ready => _ready;

  /// 应用私有目录：图片放在 images/，录音放在 audio/
  static String get filesDir => _filesDir;

  static Directory get imageDir => Directory('$_filesDir/images');
  static Directory get audioDir => Directory('$_filesDir/audio');
  static Directory get videoDir => Directory('$_filesDir/videos');
  static Directory get fileDir => Directory('$_filesDir/files');

  static Future<void> _seedIfEmpty() async {
    if (_records.isNotEmpty) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await save(RecordItem(
      id: 'demo-1',
      title: '随手打卡',
      content: '午休前完成整理',
      date: today,
      time: '12:45',
    ));
    await save(RecordItem(
      id: 'demo-2',
      title: '喂奶记录',
      content: '喂奶量: 120\n喂养方式: 母乳\n状态: 安静，喝完很快睡着',
      date: today,
      time: '10:12',
    ));
  }

  /// 读取全部记录（按时间倒序）
  static List<RecordItem> all() {
    final items = <RecordItem>[];
    for (final key in _records.keys) {
      final raw = _records.get(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        items.add(RecordItem.fromMap(map));
      } catch (_) {
        // 忽略损坏数据
      }
    }
    items.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return items;
  }

  /// 按日期筛选
  static List<RecordItem> byDate(String date) =>
      all().where((e) => e.date == date).toList();

  static Future<void> save(RecordItem item) async {
    await _records.put(item.id, jsonEncode(item.toMap()));
  }

  static Future<void> delete(RecordItem item) async {
    await _records.delete(item.id);
    // 顺手清理该记录的多媒体文件，避免残留占空间
    for (final p in item.images) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    if (item.voicePath.isNotEmpty) {
      try {
        final f = File(item.voicePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    for (final p in item.videos) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    for (final a in item.attachments) {
      try {
        final f = File(a.path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  static Future<void> clearAll() async {
    await _records.clear();
  }

  // ---------------- 设置项 ----------------

  static double getSetting(String key, double fallback) {
    final v = _settings.get(key);
    if (v is num) return v.toDouble();
    return fallback;
  }

  static Future<void> setSetting(String key, double value) async {
    await _settings.put(key, value);
  }

  // ---------------- 文件处理 ----------------

  /// 把用户选择的图片复制到应用私有目录，返回新路径
  static Future<String> importImage(String sourcePath) async {
    final dir = imageDir;
    if (!await dir.exists()) await dir.create(recursive: true);
    final ext = _extensionOf(sourcePath);
    final target =
        '${dir.path}/${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(sourcePath).copy(target);
    return target;
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    final slash = path.lastIndexOf(RegExp(r'[/\\]'));
    if (dot > slash && dot != -1) return path.substring(dot);
    return '.jpg';
  }

  /// 把用户选择的视频复制到应用私有目录，返回新路径
  static Future<String> importVideo(String sourcePath) async {
    final dir = videoDir;
    if (!await dir.exists()) await dir.create(recursive: true);
    final ext = _extensionOf(sourcePath);
    final target = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(sourcePath).copy(target);
    return target;
  }

  /// 把用户选择的 PDF / Word 文件复制到应用私有目录，返回新路径
  static Future<String> importFile(String sourcePath, {String ext = ''}) async {
    final dir = fileDir;
    if (!await dir.exists()) await dir.create(recursive: true);
    final extension = ext.isNotEmpty ? ext : _extensionOf(sourcePath);
    final target =
        '${dir.path}/${DateTime.now().microsecondsSinceEpoch}$extension';
    await File(sourcePath).copy(target);
    return target;
  }

  /// 根据扩展名判断附件类型
  static String kindOf(String fileNameOrPath) {
    final lower = fileNameOrPath.toLowerCase();
    if (lower.endsWith('.pdf')) return 'pdf';
    if (lower.endsWith('.docx')) return 'docx';
    if (lower.endsWith('.doc')) return 'doc';
    return 'other';
  }

  /// 生成一个录音文件路径
  static Future<String> newAudioPath() async {
    final dir = audioDir;
    if (!await dir.exists()) await dir.create(recursive: true);
    return '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';
  }
}
