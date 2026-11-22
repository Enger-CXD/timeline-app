import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../file_native.dart';
import '../theme.dart';

/// PDF 预览：系统 PdfRenderer / PDFKit 逐页渲染成图片，
/// 点开后可左右滑动翻页，也能双指放大缩小（放大后单指拖动查看细节）。
class PdfPreviewPage extends StatefulWidget {
  final String path;
  final String title;

  const PdfPreviewPage({super.key, required this.path, this.title = 'PDF'});

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  int _pageCount = 0;
  bool _loading = true;
  String? _error;
  int _index = 0;

  late final PageController _controller = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final count = await FileNative.pdfPageCount(widget.path);
    if (!mounted) return;
    setState(() {
      _pageCount = count;
      _loading = false;
      if (count == 0) _error = '这个 PDF 打不开（可能已损坏或被加密）';
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // 2 倍宽渲染，保证放大看字是清楚的；过大时封顶 2000，避免吃内存
    final renderWidth = (width * 2).round().clamp(600, 2000);

    return Scaffold(
      backgroundColor: AppTheme.body,
      appBar: AppBar(
        backgroundColor: AppTheme.body,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            if (_pageCount > 0)
              Text(
                _pageCount > 1
                    ? '第 ${_index + 1} / $_pageCount 页'
                    : '共 $_pageCount 页',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : (_error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.white70)),
                  ),
                )
              : Stack(
                  children: [
                    PhotoViewGallery.builder(
                      itemCount: _pageCount,
                      pageController: _controller,
                      backgroundDecoration:
                          BoxDecoration(color: AppTheme.body),
                      onPageChanged: (i) => setState(() => _index = i),
                      loadingBuilder: (_, __) => const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white54),
                      ),
                      builder: (_, i) => PhotoViewGalleryPageOptions(
                        imageProvider: _PdfPageImage(
                          path: widget.path,
                          index: i,
                          width: renderWidth,
                        ),
                        minScale: PhotoViewComputedScale.contained,
                        initialScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.contained * 4,
                        // 双击在原尺寸和“铺满”之间切换（双指缩放之外的快捷方式）
                        scaleStateCycle: (state) =>
                            state == PhotoViewScaleState.initial
                                ? PhotoViewScaleState.covering
                                : PhotoViewScaleState.initial,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('这一页渲染失败',
                              style: TextStyle(color: Colors.white70)),
                        ),
                      ),
                    ),
                    if (_pageCount > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 28,
                        child: IgnorePointer(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(0, 0, 0, 0.45),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                '左右滑动翻页 · 双指缩放',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                )),
    );
  }
}

/// 按需渲染 PDF 某一页的 ImageProvider：
/// PhotoView 只认 ImageProvider，这里把原生渲染出来的 PNG 字节包成图片。
@immutable
class _PdfPageImage extends ImageProvider<_PdfPageImage> {
  final String path;
  final int index;
  final int width;

  const _PdfPageImage({
    required this.path,
    required this.index,
    required this.width,
  });

  @override
  Future<_PdfPageImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_PdfPageImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _PdfPageImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'pdf#${key.index}',
    );
  }

  Future<ui.Codec> _loadAsync(
    _PdfPageImage key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await FileNative.pdfRenderPage(
      key.path,
      key.index,
      width: key.width,
    );
    if (bytes == null) {
      throw StateError('PDF 第 ${key.index + 1} 页渲染失败');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is _PdfPageImage &&
      other.path == path &&
      other.index == index &&
      other.width == width;

  @override
  int get hashCode => Object.hash(path, index, width);
}
