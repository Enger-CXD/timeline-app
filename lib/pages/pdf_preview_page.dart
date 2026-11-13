import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme.dart';

import '../file_native.dart';

/// PDF 预览：用系统自带的 PdfRenderer 逐页渲染成图片显示
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

  @override
  void initState() {
    super.initState();
    _load();
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
              Text('共 $_pageCount 页',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
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
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _pageCount,
                  itemBuilder: (_, i) => _PageView(
                    path: widget.path,
                    index: i,
                    width:
                        (MediaQuery.of(context).size.width - 24).toInt(),
                  ),
                )),
    );
  }
}

class _PageView extends StatelessWidget {
  final String path;
  final int index;
  final int width;

  const _PageView({
    required this.path,
    required this.index,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<Uint8List?>(
            future: FileNative.pdfRenderPage(path, index, width: width),
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return Container(
                  height: width * 1.2,
                  color: Colors.white24,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary),
                    ),
                  ),
                );
              }
              if (snap.data == null) {
                return Container(
                  height: 80,
                  color: Colors.white24,
                  child: const Center(
                    child: Text('这一页渲染失败',
                        style: TextStyle(color: Colors.white70)),
                  ),
                );
              }
              return Container(
                color: Colors.white,
                child: Image.memory(snap.data!, fit: BoxFit.fitWidth),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            '第 ${index + 1} 页',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
