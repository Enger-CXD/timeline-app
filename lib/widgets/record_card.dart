import 'dart:io';

import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';

/// 首页 / 记录页共用的记录卡片。
///
/// 布局与首页一致：标题 + 时间 + 右上角可勾选的方框，
/// 正文、图片缩略图、语音 / 视频 / 附件标签，
/// 右下角是指记录地点：点地址文字直接跳导航，点旁边的铅笔改地址。
class RecordCard extends StatelessWidget {
  final RecordItem item;
  final double fontSize;
  final double lineSpacing;

  /// 点卡片空白处 -> 打开详情
  final VoidCallback onTap;

  /// 点右上角方框 -> 勾选 / 取消勾选
  final VoidCallback onToggle;

  /// 长按卡片 -> 编辑 / 删除菜单
  final VoidCallback onLongPress;

  /// 点右下角地址文字 -> 跳转导航
  final VoidCallback onNavigate;

  /// 点右下角铅笔（或“添加位置”）-> 修改地址
  final VoidCallback onEditLocation;

  const RecordCard({
    super.key,
    required this.item,
    required this.fontSize,
    required this.lineSpacing,
    required this.onTap,
    required this.onToggle,
    required this.onLongPress,
    required this.onNavigate,
    required this.onEditLocation,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primarySoft),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题 + 时间 + 右上角勾选框
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: fontSize + 2,
                      fontWeight: FontWeight.bold,
                      color: item.isCompleted ? Colors.grey : AppTheme.ink,
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
                Semantics(
                  button: true,
                  label: item.isCompleted ? '取消完成' : '标记完成',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggle,
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: item.isCompleted
                            ? AppTheme.primary.withValues(alpha: 0.1)
                            : Colors.white,
                        border: Border.all(
                          color: AppTheme.primaryLight,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: item.isCompleted
                          ? Icon(Icons.check, size: 18, color: AppTheme.primary)
                          : null,
                    ),
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
                        color: AppTheme.primarySoft,
                        child: Icon(Icons.broken_image,
                            size: 20, color: AppTheme.primary),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (item.voicePath.isNotEmpty)
              _tag(Icons.graphic_eq, '语音 ${_formatSeconds(item.voiceSeconds)}'),
            if (item.videos.isNotEmpty)
              _tag(Icons.movie, '视频 ${item.videos.length}'),
            if (item.attachments.isNotEmpty)
              _tag(Icons.attach_file, '附件 ${item.attachments.length}'),

            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: _locationRow(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.primary),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 11, color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }

  /// 右下角：地点。左半截点一下跳导航，右半截铅笔点一下改地址。
  Widget _locationRow() {
    if (!item.hasLocation) {
      return Semantics(
        button: true,
        label: '添加位置',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onEditLocation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_outlined, size: 18, color: AppTheme.primary),
                const SizedBox(width: 2),
                Text('添加位置',
                    style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                const SizedBox(width: 2),
                Icon(Icons.edit_outlined, size: 14, color: AppTheme.primary),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 地址文字：点击跳转导航
          Semantics(
            button: true,
            label: '导航到${item.locationName}',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onNavigate,
              onLongPress: onEditLocation,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 6, 6, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 2),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      child: Text(
                        item.locationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.navigation, size: 13, color: AppTheme.primary),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          // 铅笔：手动修改这条记录的地址
          Semantics(
            button: true,
            label: '修改地点',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEditLocation,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
                child: Icon(
                  Icons.edit_location_alt_outlined,
                  size: 16,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSeconds(int s) {
    if (s <= 0) return '--';
    final m = s ~/ 60;
    final r = s % 60;
    return m > 0 ? '$m分${r.toString().padLeft(2, '0')}秒' : '$r秒';
  }
}
