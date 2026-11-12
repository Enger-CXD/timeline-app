import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../audio_native.dart';
import '../data.dart';
import '../file_native.dart';
import 'pdf_preview_page.dart';
import 'record_edit_page.dart';
import 'video_player_page.dart';
import 'word_preview_page.dart';

/// 记录详情页：图片大图查看、语音播放、编辑入口
class DetailPage extends StatefulWidget {
  final RecordItem item;
  final VoidCallback onChanged;

  const DetailPage({super.key, required this.item, required this.onChanged});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  StreamSubscription<void>? _audioSub;
  bool _playing = false;
  late RecordItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _audioSub = NativeAudio.onCompleted.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    NativeAudio.stop();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_item.voicePath.isEmpty) return;
    try {
      if (_playing) {
        await NativeAudio.stop();
        setState(() => _playing = false);
      } else {
        await NativeAudio.play(_item.voicePath);
        setState(() => _playing = true);
      }
    } catch (e) {
      _toast('播放失败：$e');
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<RecordItem>(
      context,
      MaterialPageRoute(builder: (_) => RecordEditPage(existing: _item)),
    );
    if (updated != null) {
      await RecordStore.save(updated);
      if (!mounted) return;
      setState(() => _item = updated);
      widget.onChanged();
      _toast('已保存修改');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String get _timeLabel {
    final d = DateTime.tryParse(_item.date);
    final dateText =
        d == null ? _item.date : DateFormat('yyyy年M月d日').format(d);
    return '$dateText ${_item.time}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCF7F2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.orange),
        title: Text(
          _item.title,
          style: const TextStyle(color: Color(0xFF7C2D12)),
        ),
        actions: [
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_outlined, color: Colors.orange),
            onPressed: _edit,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                _timeLabel,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const Divider(height: 24),
          if (_item.content.trim().isNotEmpty)
            Text(
              _item.content,
              style: const TextStyle(fontSize: 16, height: 1.6),
            )
          else
            Text('（没有文字内容）',
                style: TextStyle(color: Colors.grey.shade500)),

          if (_item.voicePath.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              '语音',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFAE8DC)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _togglePlay,
                    icon: Icon(
                      _playing ? Icons.stop_circle : Icons.play_circle,
                      size: 34,
                      color: Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _playing ? '正在播放…' : '点击播放',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                  Text(
                    _secondsLabel(_item.voiceSeconds),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],

          if (_item.images.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              '图片（${_item.images.length}）',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _item.images.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _viewFullScreen(i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(_item.images[i]),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.orange.shade50,
                      child: const Icon(Icons.broken_image, color: Colors.orange),
                    ),
                  ),
                ),
              ),
            ),
          ],

          if (_item.videos.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              '视频（${_item.videos.length}）',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.35,
              ),
              itemCount: _item.videos.length,
              itemBuilder: (_, i) => _VideoCard(
                path: _item.videos[i],
                onTap: () => _openVideo(i),
              ),
            ),
          ],

          if (_item.attachments.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              '附件（${_item.attachments.length}）',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            ...List.generate(_item.attachments.length, (i) {
              final a = _item.attachments[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFAE8DC)),
                ),
                child: ListTile(
                  leading: Icon(_attachIcon(a.kind), color: Colors.orange),
                  title: Text(a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(_attachLabel(a.kind),
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right,
                      color: Colors.grey, size: 18),
                  onTap: () => _openAttachment(a),
                ),
              );
            }),
          ],

          const SizedBox(height: 32),
          Center(
            child: Text(
              _item.isCompleted ? '已完成' : '进行中',
              style: TextStyle(
                fontSize: 12,
                color: _item.isCompleted ? Colors.green : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _secondsLabel(int s) {
    if (s <= 0) return '--';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _viewFullScreen(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageGalleryPage(
          paths: List<String>.from(_item.images),
          initialIndex: index,
        ),
      ),
    );
  }

  void _openVideo(int index) {
    final path = _item.videos[index];
    // 视频播放会占用音频通道，先停掉语音播放
    NativeAudio.stop();
    setState(() => _playing = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          path: path,
          title: '视频 ${index + 1} / ${_item.videos.length}',
        ),
      ),
    );
  }

  IconData _attachIcon(String kind) {
    switch (kind) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _attachLabel(String kind) {
    switch (kind) {
      case 'pdf':
        return 'PDF · 点击预览';
      case 'docx':
        return 'Word · 点击预览';
      case 'doc':
        return 'Word 老格式 · 点击查看说明';
      default:
        return '点击预览';
    }
  }

  void _openAttachment(RecordAttachment a) {
    if (!File(a.path).existsSync()) {
      _toast('文件已被删除或丢失：${a.name}');
      return;
    }
    if (a.kind == 'pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreviewPage(path: a.path, title: a.name),
        ),
      );
    } else if (a.kind == 'docx' || a.kind == 'doc') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WordPreviewPage(path: a.path, title: a.name),
        ),
      );
    } else {
      _toast('这个类型的文件暂不支持在 App 内预览');
    }
  }
}

/// 详情页里的视频卡片：首帧缩略图 + 时长
class _VideoCard extends StatelessWidget {
  final String path;
  final VoidCallback onTap;

  const _VideoCard({required this.path, required this.onTap});

  String _durationLabel(int ms) {
    if (ms <= 0) return '';
    final total = ms ~/ 1000;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: FileNative.videoThumb(path, width: 400),
              builder: (_, snap) {
                if (snap.data != null) {
                  return Image.memory(snap.data!, fit: BoxFit.cover);
                }
                return Container(
                  color: Colors.black87,
                  child: const Icon(Icons.movie, color: Colors.white70),
                );
              },
            ),
            Container(color: Colors.black26),
            const Center(
              child: Icon(Icons.play_circle_fill,
                  color: Colors.white, size: 44),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: FutureBuilder<int>(
                future: FileNative.videoDurationMs(path),
                builder: (_, snap) {
                  final label = _durationLabel(snap.data ?? 0);
                  if (label.isEmpty) return const SizedBox.shrink();
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(label,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 全屏图片浏览：支持左右滑动切换、双指缩放、顶部显示 “当前 / 总数”
class ImageGalleryPage extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const ImageGalleryPage({
    super.key,
    required this.paths,
    required this.initialIndex,
  });

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<ImageGalleryPage> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.paths.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: Text(
          '${_index + 1} / $total',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            itemCount: total,
            pageController: _controller,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            onPageChanged: (i) => setState(() => _index = i),
            builder: (_, i) => PhotoViewGalleryPageOptions(
              imageProvider: FileImage(File(widget.paths[i])),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained * 3,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.orange,
                size: 48,
              ),
            ),
          ),
          if (total > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(0, 0, 0, 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '左右滑动切换 · 双指缩放',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 说明：全屏浏览直接使用 photo_view 的 PhotoViewGallery，
/// 它内部已处理好“横向拖动翻页 + 双指缩放”的手势竞争，
/// 不需要再用 InteractiveViewer 自己权衡 panEnabled。
