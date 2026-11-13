import 'package:flutter/material.dart';

import '../backup.dart';
import '../theme.dart';

/// 排版设置页
class SettingsPage extends StatelessWidget {
  final double fontSize;
  final double lineSpacing;
  final double cardSpacing;
  final Function(double fontSize, double lineSpacing, double cardSpacing)
      onChanged;
  final Future<void> Function() onClearAll;
  final Future<void> Function()? onImportDone;
  final String paletteId;
  final void Function(String id) onPaletteChanged;

  const SettingsPage({
    super.key,
    required this.fontSize,
    required this.lineSpacing,
    required this.cardSpacing,
    required this.onChanged,
    required this.onClearAll,
    this.onImportDone,
    required this.paletteId,
    required this.onPaletteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: Text(
          '排版设置',
          style: TextStyle(color: AppTheme.ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _paletteCard(),
          const SizedBox(height: 12),
          _sliderCard(
            title: '字体大小',
            value: fontSize,
            min: 10,
            max: 24,
            onChanged: (v) => onChanged(v, lineSpacing, cardSpacing),
            preview: '正文示例：今天要记录的事情',
            previewSize: fontSize,
            previewHeight: lineSpacing,
          ),
          const SizedBox(height: 12),
          _sliderCard(
            title: '行距',
            value: lineSpacing,
            min: 0,
            max: 16,
            onChanged: (v) => onChanged(fontSize, v, cardSpacing),
          ),
          const SizedBox(height: 12),
          _sliderCard(
            title: '卡片间距',
            value: cardSpacing,
            min: 4,
            max: 32,
            onChanged: (v) => onChanged(fontSize, lineSpacing, v),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.upload_file,
                      color: AppTheme.ink),
                  title: const Text('导出数据'),
                  subtitle: const Text('生成一个 .zip 备份，可保存到手机的文件管理',
                      style: TextStyle(fontSize: 12)),
                  onTap: () => _export(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.settings_backup_restore,
                      color: AppTheme.ink),
                  title: const Text('导入数据'),
                  subtitle: const Text('选择备份 .zip，恢复记录和图片/视频/附件',
                      style: TextStyle(fontSize: 12)),
                  onTap: () => _import(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              title: const Text('清空全部记录'),
              subtitle: const Text('图片和录音文件也会一并删除',
                  style: TextStyle(fontSize: 12)),
              onTap: () => _confirmClear(context),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              '时间轴记录 · 数据保存在本机（Hive）',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  /// 导出：生成备份并调起系统分享/存储面板
  Future<void> _export(BuildContext context) async {
    try {
      await BackupService.exportAndShare(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  /// 导入：选 zip → 恢复记录与文件
  Future<void> _import(BuildContext context) async {
    try {
      final result = await BackupService.importFromPicker();
      if (result.cancelled) return;
      await onImportDone?.call();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('导入完成：${result.imported} 条记录、${result.media} 个文件'),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }

  /// 配色主题选择
  Widget _paletteCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '配色主题',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.ink),
              ),
              const Spacer(),
              const Text('点一下立即切换',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: kPalettes.map((p) {
              final selected = p.id == paletteId;
              return GestureDetector(
                onTap: () => onPaletteChanged(p.id),
                child: Column(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: p.bg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? p.primary
                              : Colors.grey.withValues(alpha: 0.35),
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: p.primary,
                            shape: BoxShape.circle,
                          ),
                          child: selected
                              ? Icon(Icons.check,
                                  size: 12, color: p.card)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected ? p.primary : AppTheme.body,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            kPalettes.firstWhere((p) => p.id == paletteId,
                    orElse: () => kPalettes.first)
                .desc,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _sliderCard({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    String? preview,
    double? previewSize,
    double? previewHeight,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                value.toStringAsFixed(0),
                style: TextStyle(color: AppTheme.primary, fontSize: 13),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: AppTheme.primary,
            divisions: (max - min).round(),
            label: value.toStringAsFixed(0),
            onChanged: onChanged,
          ),
          if (preview != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                preview,
                style: TextStyle(
                  fontSize: previewSize,
                  height: previewHeight == null ? 1.3 : 1 + previewHeight / 20,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空全部记录'),
        content: const Text('此操作不可恢复，确定要删除所有记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) await onClearAll();
  }
}
