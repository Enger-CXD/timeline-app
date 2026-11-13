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

    // Android 上优先用「外部私有目录」：/storage/emulated/0/Android/data/<包名>/files
    // 这样在手机文件管理器 / 连电脑 USB 时能看到，方便用户自己找文件。
    var base = docs.path;
    if (Platform.isAndroid) {
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null && ext.path.isNotEmpty) base = ext.path;
      } catch (_) {}
    }
    _filesDir = base;

    _ready = true;
    await _seedIfEmpty();

    // 老版本把文件放在内部存储的 Documents 下，若和当前目录不同，先搬过来
    try {
      await _absorbLegacyBase(docs.path);
    } catch (_) {}
    // 把老版本扁平目录的文件搬进「按日期」的目录结构（只需生效一次）
    try {
      await migrateLegacyMedia();
    } catch (_) {}
  }

  /// 把旧根目录下的 images/audio/videos/files 搬到新根目录
  static Future<void> _absorbLegacyBase(String oldBase) async {
    if (oldBase == _filesDir || oldBase.isEmpty) return;
    for (final sub in ['images', 'audio', 'videos', 'files']) {
      final legacy = Directory('$oldBase/$sub');
      if (!await legacy.exists()) continue;
      final target = Directory('$_filesDir/$sub');
      if (!await target.exists()) await target.create(recursive: true);
      await for (final entity in legacy.list()) {
        if (entity is! File) continue;
        try {
          final name = entity.uri.pathSegments.last;
          await entity.copy('${target.path}/$name');
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  static bool get ready => _ready;

  /// 应用根目录（Android: /storage/emulated/0/Android/data/<包名>/files；iOS: 应用沙盒 Documents）
  static String get filesDir => _filesDir;

  /// 多媒体归档根目录：<根目录>/时间轴记录
  static const String mediaFolderName = '时间轴记录';
  static String get mediaRoot => '$_filesDir/$mediaFolderName';

  /// 年-月-日，例如 2026-11-13
  static String dayName(String date) =>
      date.trim().isEmpty ? DateFormat('yyyy-MM-dd').format(DateTime.now()) : date.trim();

  /// 某一天的目录：<根目录>/时间轴记录/2026-11-13
  static Directory dayDir(String date) =>
      Directory('$mediaRoot/${dayName(date)}');

  /// 某天的分类子目录（中文命名，方便在文件管理器里一眼看懂）
  static Directory imagesDirOf(String date) =>
      Directory('${dayDir(date).path}/图片');
  static Directory videosDirOf(String date) =>
      Directory('${dayDir(date).path}/视频');
  static Directory audioDirOf(String date) =>
      Directory('${dayDir(date).path}/录音');
  static Directory filesDirOf(String date) =>
      Directory('${dayDir(date).path}/附件');

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
    // 每次保存后，重写当天的 记录.json，让本地文件夹里也能看到结构化数据
    await syncDayIndex(item.date);
  }

  /// 把某一天的所有记录导出成 <日期>/记录.json，便于在文件管理器里查看
  static Future<void> syncDayIndex(String date) async {
    try {
      final dir = dayDir(date);
      if (!await dir.exists()) await dir.create(recursive: true);
      final items = byDate(dayName(date))
          .map((e) => {
                'id': e.id,
                'time': e.time,
                'title': e.title,
                'content': e.content,
                'isCompleted': e.isCompleted,
                'images': e.images.map((p) => _relativeTo(dir, p)).toList(),
                'videos': e.videos.map((p) => _relativeTo(dir, p)).toList(),
                'voice': e.voicePath.isEmpty ? '' : _relativeTo(dir, e.voicePath),
                'voiceSeconds': e.voiceSeconds,
                'attachments': e.attachments
                    .map((a) => {
                          'name': a.name,
                          'kind': a.kind,
                          'file': _relativeTo(dir, a.path),
                        })
                    .toList(),
                'locationName': e.locationName,
                'locationLat': e.locationLat,
                'locationLng': e.locationLng,
              })
          .toList();
      final payload = {
        'date': dayName(date),
        'count': items.length,
        'updatedAt': DateTime.now().toIso8601String(),
        'records': items,
      };
      final file = File('${dir.path}/记录.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
      );
    } catch (_) {
      // 导出失败不影响主流程
    }
  }

  /// 把绝对路径换成相对日期目录的路径，例如 图片/123.jpg
  static String _relativeTo(Directory dayDirectory, String path) {
    final prefix = '${dayDirectory.path}/';
    return path.startsWith(prefix) ? path.substring(prefix.length) : path;
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

  /// 生成便于阅读的文件名，例如 123045_351.jpg
  static String _newFileName(String ext) {
    final now = DateTime.now();
    final hms = DateFormat('HHmmss').format(now);
    return '${hms}_${now.millisecond}$ext';
  }

  static Future<Directory> _ensure(Directory dir) async {
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 把用户选择的图片复制到 <日期>/图片 目录，返回新绝对路径
  static Future<String> importImage(String sourcePath, {String date = ''}) async {
    final dir = await _ensure(imagesDirOf(date));
    final target = '${dir.path}/${_newFileName(_extensionOf(sourcePath))}';
    await File(sourcePath).copy(target);
    return target;
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    final slash = path.lastIndexOf(RegExp(r'[/\\]'));
    if (dot > slash && dot != -1) return path.substring(dot);
    return '.jpg';
  }

  /// 把用户选择的视频复制到 <日期>/视频 目录，返回新绝对路径
  static Future<String> importVideo(String sourcePath, {String date = ''}) async {
    final dir = await _ensure(videosDirOf(date));
    final target = '${dir.path}/${_newFileName(_extensionOf(sourcePath))}';
    await File(sourcePath).copy(target);
    return target;
  }

  /// 把用户选择的 PDF / Word 复制到 <日期>/附件 目录，返回新绝对路径
  static Future<String> importFile(String sourcePath,
      {String ext = '', String name = '', String date = ''}) async {
    final dir = await _ensure(filesDirOf(date));
    final extension = ext.isNotEmpty ? ext : _extensionOf(sourcePath);
    final baseName = name.isNotEmpty ? name : _newFileName(extension);
    var target = '${dir.path}/$baseName';
    // 同名文件不覆盖，加时间前缀
    if (await File(target).exists()) {
      target = '${dir.path}/${_newFileName(extension)}_$baseName';
    }
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

  /// 生成录音文件路径：<日期>/录音/123045_351.m4a
  static Future<String> newAudioPath({String date = ''}) async {
    final dir = await _ensure(audioDirOf(date));
    return '${dir.path}/${_newFileName('.m4a')}';
  }

  // ---------------- 旧数据迁移 ----------------

  /// 把老版本扁平目录（images/audio/videos/files）里的文件，
  /// 按所属记录的日期搬进 时间轴记录/<日期>/<分类>/，并改写记录里的路径。
  static Future<void> migrateLegacyMedia() async {
    final legacyDirs = {
      'images': '图片',
      'videos': '视频',
      'audio': '录音',
      'files': '附件',
    };
    final anyExists = legacyDirs.keys
        .any((k) => Directory('$_filesDir/$k').existsSync());
    if (!anyExists && !File('$_filesDir/records_v1.hive').existsSync()) {
      // 全新安装且无旧目录，无需迁移
      if (!anyExists) return;
    }

    final items = all();
    // 建立 旧路径 -> 记录 的映射
    final owner = <String, RecordItem>{};
    for (final it in items) {
      for (final p in it.images) {
        owner[p] = it;
      }
      for (final p in it.videos) {
        owner[p] = it;
      }
      if (it.voicePath.isNotEmpty) owner[it.voicePath] = it;
      for (final a in it.attachments) {
        owner[a.path] = it;
      }
    }

    var changed = false;
    for (final entry in legacyDirs.entries) {
      final legacy = Directory('$_filesDir/${entry.key}');
      if (!await legacy.exists()) continue;
      await for (final entity in legacy.list()) {
        if (entity is! File) continue;
        try {
          final item = owner[entity.path];
          final date = item?.date ?? dayName('');
          final sub = entry.value;
          final targetDir = await _ensure(Directory('${dayDir(date).path}/$sub'));
          final fileName = entity.uri.pathSegments.last;
          final targetPath = '${targetDir.path}/$fileName';
          await entity.copy(targetPath);
          await entity.delete();

          if (item != null) {
            if (entry.key == 'images') {
              item.images = item.images
                  .map((p) => p == entity.path ? targetPath : p)
                  .toList();
            } else if (entry.key == 'videos') {
              item.videos = item.videos
                  .map((p) => p == entity.path ? targetPath : p)
                  .toList();
            } else if (entry.key == 'audio') {
              if (item.voicePath == entity.path) item.voicePath = targetPath;
            } else {
              item.attachments = item.attachments
                  .map((a) => a.path == entity.path
                      ? RecordAttachment(
                          name: a.name, path: targetPath, kind: a.kind)
                      : a)
                  .toList();
            }
            changed = true;
          }
        } catch (_) {
          // 单文件失败跳过
        }
      }
      // 目录空了就删掉
      try {
        if (await legacy.exists() && await legacy.list().isEmpty) {
          await legacy.delete(recursive: true);
        }
      } catch (_) {}
    }

    if (changed) {
      for (final it in items) {
        await _records.put(it.id, jsonEncode(it.toMap()));
      }
    }
    // 为所有有记录的日期补齐 记录.json
    for (final it in all()) {
      await syncDayIndex(it.date);
    }
  }
}
