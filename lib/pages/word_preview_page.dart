import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Word（.docx）预览：解压 docx 内部的 word/document.xml，取出文字显示。
///
/// 说明：docx 是压缩包，里面没有“排版后的页面”，所以这里展示的是**正文文字内容**
/// （段落、换行、制表符保留），图片和复杂表格不会显示。老的 .doc 二进制格式不支持。
class WordPreviewPage extends StatefulWidget {
  final String path;
  final String title;

  const WordPreviewPage({super.key, required this.path, this.title = 'Word'});

  @override
  State<WordPreviewPage> createState() => _WordPreviewPageState();
}

class _WordPreviewPageState extends State<WordPreviewPage> {
  bool _loading = true;
  String? _error;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.path.toLowerCase().endsWith('.doc')) {
        setState(() {
          _loading = false;
          _error = '这是老式 .doc 文件，App 内只能预览 .docx。'
              '请在电脑上用 Word 打开后“另存为 .docx”再添加。';
        });
        return;
      }
      final bytes = await File(widget.path).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? entry;
      for (final f in archive.files) {
        if (f.name == 'word/document.xml') {
          entry = f;
          break;
        }
      }
      if (entry == null) {
        setState(() {
          _loading = false;
          _error = '文件里没找到正文内容，可能不是标准的 .docx';
        });
        return;
      }
      final raw = utf8.decode(entry.content as List<int>, allowMalformed: true);
      final text = _xmlToPlainText(raw);
      setState(() {
        _text = text.trim().isEmpty ? '（这个文档只有图片或表格，没有可显示的文字）' : text;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '解析失败：$e';
      });
    }
  }

  /// 从 document.xml 里抽出纯文本（保留段落换行）
  String _xmlToPlainText(String xml) {
    var s = xml;
    // 段落结束 -> 换行；换行符、制表符直接替换
    s = s.replaceAll(RegExp(r'</w:p>'), '\n');
    s = s.replaceAll(RegExp(r'<w:br[^>]*/>'), '\n');
    s = s.replaceAll(RegExp(r'<w:tab[^>]*/>'), '\t');
    // 去掉所有标签
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    // 常见实体
    s = s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'");
    // 压缩连续空行
    s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.primary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppTheme.ink, fontSize: 14)),
            const Text('Word 文字预览',
                style: TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : (_error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.grey, height: 1.6)),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  child: SelectableText(
                    _text,
                    style: const TextStyle(fontSize: 15, height: 1.7),
                  ),
                )),
    );
  }
}
