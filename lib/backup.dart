import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'data.dart';

/// 导入结果
class ImportResult {
  final int imported;
  final int media;
  final bool cancelled;

  const ImportResult(this.imported, this.media, {this.cancelled = false});
}

/// 数据导入 / 导出（整包备份）
///
/// 备份包结构：
///   时间轴记录备份_20261113_153000.zip
///     ├─ data.json      所有记录的 JSON（图片/视频/附件用 media/xxx 引用）
///     └─ media/         原始图片、视频、录音、PDF/Word 文件
class BackupService {
  static const String _formatKey = '时间轴记录';
  static const int _formatVersion = 1;

  // ---------------- 导出 ----------------

  /// 生成备份 zip，返回生成的本地文件
  static Future<File> createBackup() async {
    final items = RecordStore.all();
    final archive = Archive();
    final pathToEntry = <String, String>{};
    var seq = 0;

    Future<void> addMedia(String path) async {
      if (path.isEmpty || pathToEntry.containsKey(path)) return;
      final file = File(path);
      if (!await file.exists()) return;
      final ext = _extOf(path);
      final entryName = 'media/${seq++}$ext';
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
      pathToEntry[path] = entryName;
    }

    for (final item in items) {
      for (final p in item.images) {
        await addMedia(p);
      }
      for (final p in item.videos) {
        await addMedia(p);
      }
      if (item.voicePath.isNotEmpty) await addMedia(item.voicePath);
      for (final a in item.attachments) {
        await addMedia(a.path);
      }
    }

    final records = items.map((e) {
      final m = e.toMap();
      m['images'] =
          e.images.map((p) => pathToEntry[p] ?? '').where((p) => p.isNotEmpty).toList();
      m['videos'] =
          e.videos.map((p) => pathToEntry[p] ?? '').where((p) => p.isNotEmpty).toList();
      m['voicePath'] = e.voicePath.isEmpty ? '' : (pathToEntry[e.voicePath] ?? '');
      m['attachments'] = e.attachments
          .where((a) => pathToEntry.containsKey(a.path))
          .map((a) => {
                'name': a.name,
                'path': pathToEntry[a.path],
                'kind': a.kind,
              })
          .toList();
      return m;
    }).toList();

    final payload = {
      'app': _formatKey,
      'format': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'count': records.length,
      'records': records,
    };

    final dataBytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(payload));
    archive.addFile(ArchiveFile('data.json', dataBytes.length, dataBytes));

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw Exception('打包失败');

    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/时间轴记录备份_$stamp.zip');
    await file.writeAsBytes(encoded);
    return file;
  }

  /// 生成备份并调起系统分享面板（可「存储到文件」/「保存到下载目录」）
  static Future<void> exportAndShare(BuildContext context) async {
    final file = await createBackup();
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/zip')],
      subject: '时间轴记录备份',
      text: '时间轴记录数据备份（含图片、视频、录音、附件）',
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  // ---------------- 导入 ----------------

  /// 让用户选一个备份 zip 并导入（同 id 记录覆盖，其余保留）
  static Future<ImportResult> importFromPicker() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (picked == null || picked.files.isEmpty) {
      return const ImportResult(0, 0, cancelled: true);
    }
    final path = picked.files.first.path;
    if (path == null) return const ImportResult(0, 0, cancelled: true);
    return importFromZip(File(path));
  }

  static Future<ImportResult> importFromZip(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? dataEntry;
    for (final f in archive.files) {
      if (f.name == 'data.json' || f.name.endsWith('/data.json')) {
        dataEntry = f;
        break;
      }
    }
    if (dataEntry == null) {
      throw Exception('这不是有效的时间轴记录备份（缺少 data.json）');
    }

    final raw = utf8.decode(dataEntry.content as List<int>, allowMalformed: true);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    if (decoded['app'] != _formatKey) {
      throw Exception('备份来源不匹配（app=${decoded['app']}）');
    }

    final entryByName = <String, ArchiveFile>{};
    for (final f in archive.files) {
      entryByName[f.name] = f;
    }

    final records = (decoded['records'] as List?) ?? const [];
    var imported = 0;
    var mediaCount = 0;
    var seq = 0;

    Future<String> restore(String entryName, Directory targetDir) async {
      final entry = entryByName[entryName];
      if (entry == null) return '';
      if (!await targetDir.exists()) await targetDir.create(recursive: true);
      final ext = _extOf(entryName);
      final name = '${DateTime.now().microsecondsSinceEpoch}_${seq++}$ext';
      final file = File('${targetDir.path}/$name');
      final content = entry.content as List<int>;
      await file.writeAsBytes(List<int>.from(content));
      mediaCount++;
      return file.path;
    }

    for (final rawItem in records) {
      final map = Map<String, dynamic>.from(rawItem as Map);

      final images = <String>[];
      for (final p in (map['images'] as List? ?? const [])) {
        final restored = await restore(p.toString(), RecordStore.imageDir);
        if (restored.isNotEmpty) images.add(restored);
      }

      final videos = <String>[];
      for (final p in (map['videos'] as List? ?? const [])) {
        final restored = await restore(p.toString(), RecordStore.videoDir);
        if (restored.isNotEmpty) videos.add(restored);
      }

      var voicePath = '';
      final voiceEntry = (map['voicePath'] ?? '').toString();
      if (voiceEntry.isNotEmpty) {
        voicePath = await restore(voiceEntry, RecordStore.audioDir);
      }

      final attachments = <RecordAttachment>[];
      for (final a in (map['attachments'] as List? ?? const [])) {
        final m = Map<String, dynamic>.from(a as Map);
        final entryName = (m['path'] ?? '').toString();
        if (entryName.isEmpty) continue;
        final restored = await restore(entryName, RecordStore.fileDir);
        if (restored.isEmpty) continue;
        attachments.add(RecordAttachment(
          name: (m['name'] ?? '').toString(),
          path: restored,
          kind: (m['kind'] ?? 'other').toString(),
        ));
      }

      map['images'] = images;
      map['videos'] = videos;
      map['voicePath'] = voicePath;
      map['attachments'] = attachments.map((e) => e.toMap()).toList();

      final item = RecordItem.fromMap(map);
      await RecordStore.save(item);
      imported++;
    }

    return ImportResult(imported, mediaCount);
  }

  static String _extOf(String path) {
    final dot = path.lastIndexOf('.');
    final slash = path.lastIndexOf(RegExp(r'[/\\]'));
    if (dot > slash && dot != -1 && dot >= path.length - 8) {
      return path.substring(dot);
    }
    return '';
  }
}
