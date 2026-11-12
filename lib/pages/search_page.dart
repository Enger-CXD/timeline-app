import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data.dart';
import 'detail_page.dart';

/// 记录列表 / 搜索页
class SearchPage extends StatefulWidget {
  final List<RecordItem> records;
  final VoidCallback onChanged;

  const SearchPage({super.key, required this.records, required this.onChanged});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final kw = _keyword.trim().toLowerCase();
    final list = widget.records.where((item) {
      if (kw.isEmpty) return true;
      return item.title.toLowerCase().contains(kw) ||
          item.content.toLowerCase().contains(kw) ||
          item.date.contains(kw);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFCF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCF7F2),
        elevation: 0,
        title: TextField(
          onChanged: (v) => setState(() => _keyword = v),
          decoration: const InputDecoration(
            hintText: '搜索标题、内容或日期…',
            prefixIcon: Icon(Icons.search, color: Colors.orange),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_keyword.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey),
              onPressed: () => setState(() => _keyword = ''),
            ),
        ],
      ),
      body: list.isEmpty
          ? Center(
              child: Text(
                _keyword.isEmpty ? '还没有任何记录' : '没有匹配的记录',
                style: const TextStyle(color: Colors.grey),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = list[i];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _open(context, item),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: item.isCompleted
                                              ? Colors.grey
                                              : const Color(0xFF7C2D12),
                                          decoration: item.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      item.time,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.content.replaceAll('\n', ' '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      DateFormat('yyyy-MM-dd')
                                          .format(DateTime.tryParse(item.date) ??
                                              DateTime.now()),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFB45309)),
                                    ),
                                    if (item.images.isNotEmpty) ...[
                                      const SizedBox(width: 10),
                                      const Icon(Icons.image,
                                          size: 12, color: Colors.orange),
                                      Text(' ${item.images.length}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange)),
                                    ],
                                    if (item.voicePath.isNotEmpty) ...[
                                      const SizedBox(width: 10),
                                      const Icon(Icons.mic,
                                          size: 12, color: Colors.orange),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _open(BuildContext context, RecordItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailPage(item: item, onChanged: widget.onChanged),
      ),
    );
  }
}
