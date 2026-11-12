import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data.dart';
import '../file_native.dart';
import 'detail_page.dart';

/// 首页：按日期展示时间轴
/// 手动填写省 / 市 的对话框（控制器交给 State 自己管理，避免提前 dispose 触发断言）
class _ManualLocationDialog extends StatefulWidget {
  const _ManualLocationDialog();

  @override
  State<_ManualLocationDialog> createState() => _ManualLocationDialogState();
}

class _ManualLocationDialogState extends State<_ManualLocationDialog> {
  final _provinceCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  @override
  void dispose() {
    _provinceCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('手动填写位置'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _provinceCtrl,
            decoration: const InputDecoration(
              labelText: '省 / 直辖市',
              hintText: '例如 湖北省',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cityCtrl,
            decoration: const InputDecoration(
              labelText: '市 / 区',
              hintText: '例如 恩施市',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final name =
                '${_provinceCtrl.text.trim()}${_cityCtrl.text.trim()}'.trim();
            Navigator.pop(context, name);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class HomePage extends StatelessWidget {
  final List<RecordItem> records;
  final DateTime date;
  final double fontSize;
  final double lineSpacing;
  final double cardSpacing;
  final VoidCallback onPrevDate;
  final VoidCallback onNextDate;
  final VoidCallback onToday;
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
    required this.onPrevDate,
    required this.onNextDate,
    required this.onToday,
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
      backgroundColor: const Color(0xFFFCF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCF7F2),
        elevation: 0,
        centerTitle: true,
        title: GestureDetector(
          onTap: onToday,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE6D8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _dateLabel,
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: Colors.orange.shade700,
                ),
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.orange),
          onPressed: onPrevDate,
          tooltip: '前一天',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.orange),
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
                      _buildCard(context, item),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
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
          Icon(Icons.event_note, size: 64, color: Colors.orange.shade200),
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
        color: const Color(0xFFFDE6D8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        item.dateTag,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFFB45309),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, RecordItem item) {
    return GestureDetector(
      onTap: () => _openDetail(context, item),
      onLongPress: () => _showActions(context, item),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFAE8DC)),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: fontSize + 2,
                      fontWeight: FontWeight.bold,
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
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => onToggle(item.id),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: item.isCompleted
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.white,
                      border: Border.all(
                        color: Colors.orange.shade300,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: item.isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.orange)
                        : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: lineSpacing),
            if (item.content.trim().isNotEmpty)
              Text(
                item.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize,
                  color: item.isCompleted ? Colors.grey[400] : Colors.grey[600],
                  decoration:
                      item.isCompleted ? TextDecoration.lineThrough : null,
                  height: 1.3,
                ),
              ),
            if (item.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(item.images[i]),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: Colors.orange.shade50,
                        child: const Icon(Icons.broken_image,
                            size: 20, color: Colors.orange),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (item.voicePath.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.graphic_eq, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      '语音 ${_formatSeconds(item.voiceSeconds)}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
            if (item.videos.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.movie, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      '视频 ${item.videos.length}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
            if (item.attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attach_file, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      '附件 ${item.attachments.length}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],

            // 右下角：位置信息（未设置时是“添加”箭头，已设置后显示 省+市，点一下可导航）
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: item.hasLocation
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openNavigation(context, item),
                      onLongPress: () => _editLocation(context, item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place,
                                size: 13, color: Colors.orange),
                            const SizedBox(width: 2),
                            Text(
                              item.locationName,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFFB45309)),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.navigation,
                                size: 12, color: Color(0xFFB45309)),
                          ],
                        ),
                      ),
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _editLocation(context, item),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.place_outlined,
                                size: 18, color: Colors.orange),
                            Text(
                              '位置',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.orange),
                            ),
                            Icon(Icons.navigation_outlined,
                                size: 16, color: Colors.orange),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSeconds(int s) {
    if (s <= 0) return '--';
    final m = s ~/ 60;
    final r = s % 60;
    return m > 0 ? '$m分${r.toString().padLeft(2, '0')}秒' : '$r秒';
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

  /// 给某条记录补充位置信息（自动定位 / 手动填写 / 清除）
  Future<void> _editLocation(BuildContext context, RecordItem item) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '给「${item.title}」添加位置',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7C2D12),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.my_location, color: Colors.orange),
              title: const Text('自动获取当前位置'),
              subtitle: const Text('需要允许定位权限'),
              onTap: () => Navigator.pop(context, 'auto'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_location_alt_outlined,
                  color: Colors.orange),
              title: const Text('手动填写省 / 市'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
            if (item.hasLocation)
              ListTile(
                leading:
                    const Icon(Icons.location_off, color: Colors.redAccent),
                title: const Text('清除位置',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () => Navigator.pop(context, 'clear'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted || choice == null) return;

    if (choice == 'clear') {
      await onUpdate(item.copyWith(
        locationName: '',
        locationLat: 0,
        locationLng: 0,
      ));
      return;
    }

    if (choice == 'auto') {
      try {
        final r = await FileNative.currentLocation();
        if (r == null) {
          _toast(context, '暂时拿不到位置，可改用手动填写');
          return;
        }
        final province = (r['province'] ?? '').toString().trim();
        final city = (r['city'] ?? '').toString().trim();
        final lat = (r['lat'] as num?)?.toDouble() ?? 0;
        final lng = (r['lng'] as num?)?.toDouble() ?? 0;
        final name = '$province$city'.trim().isEmpty
            ? '当前位置'
            : '$province$city';
        await onUpdate(item.copyWith(
          locationName: name,
          locationLat: lat,
          locationLng: lng,
        ));
        if (context.mounted) _toast(context, '已添加位置：$name');
      } catch (e) {
        if (context.mounted) {
          _toast(context, '定位失败：需要在系统弹窗里允许定位权限，然后再点一次箭头');
        }
      }
      return;
    }

    // 手动填写
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualLocationDialog(),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    await onUpdate(item.copyWith(
      locationName: name,
      locationLat: 0,
      locationLng: 0,
    ));
    if (context.mounted) _toast(context, '已添加位置：$name');
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
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7C2D12),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.orange),
              title: const Text('编辑记录'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('删除记录',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    // 异步弹窗关闭后再执行动作，避免 context 失效
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return;
    if (action == 'edit') {
      await onEdit(context, item);
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
