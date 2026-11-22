import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data.dart';
import '../file_native.dart';
import '../record_actions.dart';
import '../theme.dart';
import '../widgets/record_card.dart';
import 'detail_page.dart';

/// 记录列表 / 搜索页：卡片与首页完全一致
/// （标题、右上角可勾选方框、右下角可跳转的地址）
class SearchPage extends StatefulWidget {
  final List<RecordItem> records;
  final double fontSize;
  final double lineSpacing;
  final double cardSpacing;
  final VoidCallback onChanged;
  final ValueChanged<String> onToggle;
  final Future<void> Function(BuildContext context, RecordItem item) onEdit;
  final Future<void> Function(RecordItem item) onDelete;
  final Future<void> Function(RecordItem item) onUpdate;

  const SearchPage({
    super.key,
    required this.records,
    required this.fontSize,
    required this.lineSpacing,
    required this.cardSpacing,
    required this.onChanged,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _keywordCtrl = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kw = _keyword.trim().toLowerCase();
    final list = widget.records.where((item) {
      if (kw.isEmpty) return true;
      return item.title.toLowerCase().contains(kw) ||
          item.content.toLowerCase().contains(kw) ||
          item.date.contains(kw) ||
          item.locationName.toLowerCase().contains(kw);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: TextField(
          controller: _keywordCtrl,
          onChanged: (v) => setState(() => _keyword = v),
          decoration: InputDecoration(
            hintText: '搜索标题、内容、日期或地点…',
            prefixIcon: Icon(Icons.search, color: AppTheme.primary),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_keyword.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey),
              onPressed: () {
                _keywordCtrl.clear();
                setState(() => _keyword = '');
              },
            ),
        ],
      ),
      body: list.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 56, color: AppTheme.primaryLight),
                  const SizedBox(height: 12),
                  Text(
                    _keyword.isEmpty ? '还没有任何记录' : '没有匹配的记录',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final item = list[i];
                return Padding(
                  padding: EdgeInsets.only(bottom: widget.cardSpacing),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dateTag(item),
                      const SizedBox(height: 6),
                      RecordCard(
                        item: item,
                        fontSize: widget.fontSize,
                        lineSpacing: widget.lineSpacing,
                        onTap: () => _open(context, item),
                        onToggle: () => widget.onToggle(item.id),
                        onLongPress: () => _showActions(context, item),
                        onNavigate: () => _openNavigation(context, item),
                        onEditLocation: () => _editLocation(context, item),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _dateTag(RecordItem item) {
    final d = DateTime.tryParse(item.date);
    final text = d == null
        ? item.date
        : '${DateFormat('yyyy-MM-dd').format(d)}  周${const [
            '一', '二', '三', '四', '五', '六', '日'
          ][d.weekday - 1]}  ${item.time}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: AppTheme.primary,
          fontWeight: FontWeight.bold,
        ),
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

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _editLocation(BuildContext context, RecordItem item) async {
    final updated = await editLocationFlow(context, item);
    if (updated == null) return;
    await widget.onUpdate(updated);
  }

  Future<void> _openNavigation(BuildContext context, RecordItem item) async {
    if (!item.hasLocation) return;
    final ok = await FileNative.openNavigation(
      lat: item.locationLat,
      lng: item.locationLng,
      name: item.locationName,
    );
    if (!ok && context.mounted) {
      _toast(context, '没有找到可用的导航 App（装个高德或百度地图再试）');
    }
  }

  Future<void> _showActions(BuildContext context, RecordItem item) async {
    final action = await showRecordActions(context, item);
    if (!context.mounted || action == null) return;
    if (action == 'edit') {
      await widget.onEdit(context, item);
    } else if (action == 'location') {
      await _editLocation(context, item);
    } else if (action == 'delete') {
      await _confirmDelete(context, item);
    }
  }

  Future<void> _confirmDelete(BuildContext context, RecordItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定删除「${item.title}」吗？图片和录音也会一起删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) await widget.onDelete(item);
  }
}
