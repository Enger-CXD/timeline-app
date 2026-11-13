import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';

import '../audio_native.dart';
import '../data.dart';
import '../file_native.dart';

/// 新建 / 编辑记录页
class RecordEditPage extends StatefulWidget {
  final RecordItem? existing;
  final DateTime? initialDate;

  const RecordEditPage({super.key, this.existing, this.initialDate});

  @override
  State<RecordEditPage> createState() => _RecordEditPageState();
}

class _RecordEditPageState extends State<RecordEditPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  List<String> _images = [];
  List<String> _videos = [];
  List<RecordAttachment> _attachments = [];
  String _voicePath = '';
  int _voiceSeconds = 0;

  late DateTime _date;
  late String _time;

  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<void>? _audioSub;

  bool _recording = false;
  bool _playing = false;
  int _recordSeconds = 0;
  Timer? _timer;

  /// 当前记录所属日期（决定文件归到哪个日期文件夹）
  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _contentController = TextEditingController(text: e?.content ?? '');
    _images = List<String>.from(e?.images ?? const []);
    _videos = List<String>.from(e?.videos ?? const []);
    _attachments = List<RecordAttachment>.from(e?.attachments ?? const []);
    _voicePath = e?.voicePath ?? '';
    _voiceSeconds = e?.voiceSeconds ?? 0;

    if (e != null) {
      _date = DateTime.tryParse(e.date) ?? DateTime.now();
      _time = e.time;
    } else {
      _date = widget.initialDate ?? DateTime.now();
      final now = DateTime.now();
      _time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }

    _audioSub = NativeAudio.onCompleted.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _audioSub?.cancel();
    NativeAudio.stop();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ---------------- 图片 ----------------

  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 90);
      if (files.isEmpty) return;
      final imported = <String>[];
      for (final f in files) {
        imported.add(await RecordStore.importImage(f.path, date: _dateStr));
      }
      setState(() => _images.addAll(imported));
    } catch (e) {
      _toast('选择图片失败：$e');
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  // ---------------- 视频 ----------------

  Future<void> _pickVideo() async {
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;
      final imported = await RecordStore.importVideo(file.path, date: _dateStr);
      setState(() => _videos.add(imported));
    } catch (e) {
      _toast('选择视频失败：$e');
    }
  }

  void _removeVideo(int index) {
    setState(() => _videos.removeAt(index));
  }

  // ---------------- 文件附件 ----------------

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx'],
      );
      if (result == null || result.files.isEmpty) return;
      final added = <RecordAttachment>[];
      for (final f in result.files) {
        if (f.path == null) continue;
        final kind = RecordStore.kindOf(f.name);
        final ext = f.name.contains('.')
            ? f.name.substring(f.name.lastIndexOf('.'))
            : '';
        final newPath = await RecordStore.importFile(f.path!, ext: ext, name: f.name, date: _dateStr);
        added.add(RecordAttachment(name: f.name, path: newPath, kind: kind));
      }
      if (added.isEmpty) {
        _toast('没有可用的文件（只支持 PDF / Word）');
        return;
      }
      setState(() => _attachments.addAll(added));
    } catch (e) {
      _toast('选择文件失败：$e');
    }
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
  }

  // ---------------- 录音 ----------------

  Future<void> _toggleRecord() async {
    if (_recording) {
      await _stopRecord();
      return;
    }
    try {
      final has = await _recorder.hasPermission();
      if (!has) {
        _toast('没有麦克风权限，请在系统设置中允许');
        return;
      }
      final path = await RecordStore.newAudioPath(date: _dateStr);
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _recording = true;
        _recordSeconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e) {
      _toast('录音失败：$e');
    }
  }

  Future<void> _stopRecord() async {
    try {
      final path = await _recorder.stop();
      _timer?.cancel();
      _timer = null;
      if (mounted) {
        setState(() {
          _recording = false;
          if (path != null && path.isNotEmpty) {
            _voicePath = path;
            _voiceSeconds = _recordSeconds;
          }
        });
      }
    } catch (e) {
      _toast('停止录音失败：$e');
    }
  }

  Future<void> _togglePlay() async {
    if (_voicePath.isEmpty) return;
    try {
      if (_playing) {
        await NativeAudio.stop();
        setState(() => _playing = false);
      } else {
        await NativeAudio.play(_voicePath);
        setState(() => _playing = true);
      }
    } catch (e) {
      _toast('播放失败：$e');
    }
  }

  Future<void> _removeVoice() async {
    try {
      if (_voicePath.isNotEmpty) {
        final f = File(_voicePath);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
    setState(() {
      _voicePath = '';
      _voiceSeconds = 0;
      _playing = false;
    });
  }

  // ---------------- 日期 ----------------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  // ---------------- 保存 ----------------

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _toast('请填写标题');
      return;
    }
    if (_recording) {
      _toast('请先结束录音');
      return;
    }
    final item = RecordItem(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: _contentController.text,
      date: DateFormat('yyyy-MM-dd').format(_date),
      time: _time,
      isCompleted: widget.existing?.isCompleted ?? false,
      images: _images,
      voicePath: _voicePath,
      voiceSeconds: _voiceSeconds,
      videos: _videos,
      attachments: _attachments,
      locationName: widget.existing?.locationName ?? '',
      locationLat: widget.existing?.locationLat ?? 0,
      locationLng: widget.existing?.locationLng ?? 0,
    );
    Navigator.pop(context, item);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String get _secondsLabel {
    final s = _recording ? _recordSeconds : _voiceSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCF7F2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.orange),
        title: Text(
          isEdit ? '编辑记录' : '添加新记录',
          style: const TextStyle(color: Color(0xFF7C2D12)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '标题',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '详细内容（文字、记录说明等）',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 日期
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 18, color: Colors.orange),
                  const SizedBox(width: 10),
                  Text(
                    '${DateFormat('yyyy年M月d日').format(_date)}  $_time',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 图片
          _sectionTitle('图片', trailing: TextButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.add_photo_alternate,
                size: 18, color: Colors.orange),
            label: const Text('添加', style: TextStyle(color: Colors.orange)),
          )),
          if (_images.isEmpty)
            Text('还没有图片，点“添加”从相册选择',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
          else
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(_images[i]),
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 88,
                          height: 88,
                          color: Colors.orange.shade50,
                          child: const Icon(Icons.broken_image,
                              color: Colors.orange),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => _removeImage(i),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomLeft: Radius.circular(10),
                            ),
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),

          // 视频
          _sectionTitle('视频', trailing: TextButton.icon(
            onPressed: _pickVideo,
            icon: const Icon(Icons.video_call, size: 18, color: Colors.orange),
            label: const Text('添加', style: TextStyle(color: Colors.orange)),
          )),
          if (_videos.isEmpty)
            Text('还没有视频，点“添加”从相册选择',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
          else
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _videos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _buildVideoTile(i),
              ),
            ),
          const SizedBox(height: 20),

          // 文件附件
          _sectionTitle('文件附件（PDF / Word）', trailing: TextButton.icon(
            onPressed: _pickFiles,
            icon: const Icon(Icons.attach_file, size: 18, color: Colors.orange),
            label: const Text('添加', style: TextStyle(color: Colors.orange)),
          )),
          if (_attachments.isEmpty)
            Text('还没有附件，点“添加”选择 PDF 或 Word 文件',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
          else
            ...List.generate(_attachments.length, (i) {
              final a = _attachments[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(_fileIcon(a.kind), size: 20, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    GestureDetector(
                      onTap: () => _removeAttachment(i),
                      child: const Icon(Icons.close,
                          size: 18, color: Colors.redAccent),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 20),

          // 录音
          _sectionTitle('语音'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggleRecord,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _recording ? Colors.redAccent : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _recording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _recording
                        ? '录音中… $_secondsLabel'
                        : (_voicePath.isEmpty
                            ? '点麦克风开始录音'
                            : '已录制 $_secondsLabel'),
                    style: TextStyle(
                      fontSize: 13,
                      color: _recording ? Colors.redAccent : Colors.grey.shade700,
                    ),
                  ),
                ),
                if (!_recording && _voicePath.isNotEmpty) ...[
                  IconButton(
                    onPressed: _togglePlay,
                    icon: Icon(
                      _playing ? Icons.stop_circle : Icons.play_circle,
                      color: Colors.orange,
                    ),
                  ),
                  IconButton(
                    onPressed: _removeVoice,
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _save,
              child: Text(
                isEdit ? '保存修改' : '保存记录',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 编辑页里的视频小方片：首帧缩略图 + 播放标 + 删除
  Widget _buildVideoTile(int i) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 88,
            height: 88,
            child: FutureBuilder<Uint8List?>(
              future: FileNative.videoThumb(_videos[i], width: 176),
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
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 28),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: () => _removeVideo(i),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  IconData _fileIcon(String kind) {
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

  Widget _sectionTitle(String text, {Widget? trailing}) {    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF7C2D12))),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
