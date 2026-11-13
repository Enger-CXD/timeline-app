import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'package:video_player/video_player.dart';

/// 全屏视频播放页（支持播放/暂停、拖动进度）
class VideoPlayerPage extends StatefulWidget {
  final String path;
  final String title;

  const VideoPlayerPage({super.key, required this.path, this.title = '视频'});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _controller;
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.file(File(widget.path));
      _controller = c;
      await c.initialize();
      c.addListener(() {
        if (mounted) setState(() {});
      });
      await c.play();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title,
            style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '视频打不开：$_error',
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            : (c == null || !_ready)
                ? CircularProgressIndicator(color: AppTheme.primary)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: c.value.aspectRatio == 0
                            ? 16 / 9
                            : c.value.aspectRatio,
                        child: VideoPlayer(c),
                      ),
                      const SizedBox(height: 12),
                      VideoProgressIndicator(
                        c,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: AppTheme.primary,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              if (c.value.isPlaying) {
                                c.pause();
                              } else {
                                if (c.value.position >= c.value.duration) {
                                  c.seekTo(Duration.zero);
                                }
                                c.play();
                              }
                            },
                            icon: Icon(
                              c.value.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              size: 44,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_fmt(c.value.position)} / ${_fmt(c.value.duration)}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }
}
