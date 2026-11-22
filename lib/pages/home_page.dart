import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data.dart';
import '../file_native.dart';
import '../record_actions.dart';
import '../theme.dart';
import '../widgets/month_calendar_sheet.dart';
import '../widgets/record_card.dart';
import 'detail_page.dart';

/// 首页：按日期展示时间轴
class HomePage extends StatelessWidget {
  final List<RecordItem> records;
  final DateTime date;
  final double fontSize;
  final double lineSpacing;
  final double cardSpacing;

  /// 有记录的日期集合（yyyy-MM-dd），月历上打点用
  final Set<String> markedDates;

  final VoidCallback onPrevDate;
  final VoidCallback onNextDate;
  final ValueChanged<DateTime> onPickDate;
  final VoidCallback onAdd;
  final ValueChanged<String> onToggle;
  final Future<void> Function(BuildContext context, RecordItem item) onEdit;
  final Future<void> Function(RecordItem item) onDelete;
  final Future<void> Function(RecordItem item) onUpdate;
  final VoidCallback onChanged;

  const HomePage({
    super.key,
    required this.records,
    required this.date,
    required this.fontSize,
    required this.lineSpacing,
    required this.cardSpacing,
    required this.markedDates,
    required this.onPrevDate,
    required this.onNextDate,
    required this.onPickDate,
    required this.onAdd,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdate,
    required this.onChanged,
  });

  String get _dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff == -1) return '明天';
    return DateFormat('M月d日').format(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        centerTitle: true,
        title: GestureDetector(
          onTap: () => _openCalendar(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _dateLabel,
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: AppTheme.primary,
                ),
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: AppTheme.primary),
          onPressed: onPrevDate,
          tooltip: '前一天',
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.chevron_right, color: AppTheme.primary),
            onPressed: onNextDate,
            tooltip: '后一天',
          ),
        ],
      ),
      body: records.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final item = records[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: cardSpacing),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTimeTag(item),
                      const SizedBox(height: 6),
                      RecordCard(
                        item: item,
                        fontSize: fontSize,
                        lineSpacing: lineSpacing,
                        onTap: () => _openDetail(context, item),
                        onToggle: () => onToggle(item.id),
                        onLongPress: () => _showActions(context, item),
                        onNavigate: () => _openNavigation(context, item),
                        onEditLocation: () => _editLocation(context, item),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: onAdd,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_note, size: 64, color: AppTheme.primaryLight),
          const SizedBox(height: 12),
          Text(
            '${DateFormat('M月d日').format(date)} 还没有记录',
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            '点右下角 + 添加一条',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTag(RecordItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        item.dateTag,
        style: TextStyle(
          fontSize: 10,
          color: AppTheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 点日期胶囊里的下箭头：弹出月历，左右滑动换月，单击选中某天
  Future<void> _openCalendar(BuildContext context) async {
    final picked = await showMonthCalendar(
      context,
      initialDate: date,
      markedDates: markedDates,
    );
    if (picked != null) onPickDate(picked);
  }

  void _openDetail(BuildContext context, RecordItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailPage(item: item, onChanged: onChanged),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _editLocation(BuildContext context, RecordItem item) async {
    final updated = await editLocationFlow(context, item);
    if (updated == null) return;
    await onUpdate(updated);
  }

  /// 点地点文字：跳转到导航 App
  Future<void> _openNavigation(BuildContext context, RecordItem item) async {
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
      await onEdit(context, item);
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
    if (ok == true) await onDelete(item);
  }
}
