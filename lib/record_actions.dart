import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'file_native.dart';
import 'theme.dart';

/// 记录卡片的通用交互：改地址、长按菜单。
/// 首页和「记录」页共用，保证两处行为一致。

/// 让用户给某条记录设置地点。返回更新后的记录，取消/无变化返回 null。
Future<RecordItem?> editLocationFlow(
  BuildContext context,
  RecordItem item,
) async {
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              '「${item.title}」的地点',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.ink,
              ),
            ),
          ),
          if (item.hasLocation)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '当前：${item.locationName}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
          ListTile(
            leading: Icon(Icons.my_location, color: AppTheme.primary),
            title: const Text('重新自动定位'),
            subtitle: const Text('用手机当前所在位置覆盖'),
            onTap: () => Navigator.pop(context, 'auto'),
          ),
          ListTile(
            leading: Icon(Icons.edit_location_alt_outlined,
                color: AppTheme.primary),
            title: const Text('手动修改省 / 市'),
            onTap: () => Navigator.pop(context, 'manual'),
          ),
          if (item.hasLocation)
            ListTile(
              leading: Icon(Icons.navigation_outlined, color: AppTheme.primary),
              title: const Text('打开导航 App'),
              onTap: () => Navigator.pop(context, 'nav'),
            ),
          if (item.hasLocation)
            ListTile(
              leading: const Icon(Icons.location_off, color: Colors.redAccent),
              title: const Text('清除地点',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(context, 'clear'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  // 关闭弹窗后等一帧，避免 context 已被回收
  await Future<void>.delayed(Duration.zero);
  if (!context.mounted || choice == null) return null;

  if (choice == 'nav') {
    final ok = await FileNative.openNavigation(
      lat: item.locationLat,
      lng: item.locationLng,
      name: item.locationName,
    );
    if (!ok && context.mounted) {
      _toast(context, '没有找到可用的导航 App（装个高德或百度地图再试）');
    }
    return null;
  }

  if (choice == 'clear') {
    return item.copyWith(locationName: '', locationLat: 0, locationLng: 0);
  }

  if (choice == 'auto') {
    try {
      final r = await FileNative.currentLocation();
      if (r == null) {
        if (context.mounted) _toast(context, '暂时拿不到位置，可改用手动填写');
        return null;
      }
      final province = (r['province'] ?? '').toString().trim();
      final city = (r['city'] ?? '').toString().trim();
      final lat = (r['lat'] as num?)?.toDouble() ?? 0;
      final lng = (r['lng'] as num?)?.toDouble() ?? 0;
      final name = '$province$city'.trim();
      if (name.isEmpty) {
        if (context.mounted) _toast(context, '暂时拿不到位置，可改用手动填写');
        return null;
      }
      if (context.mounted) _toast(context, '已更新位置：$name');
      return item.copyWith(locationName: name, locationLat: lat, locationLng: lng);
    } on PermissionNeeded {
      if (context.mounted) {
        _toast(context, '定位权限被拒绝：在系统弹窗里点“允许”，再点一次即可');
      }
      return null;
    } on PlatformException catch (e) {
      if (context.mounted) _toast(context, e.message ?? '定位失败，可改用手动填写');
      return null;
    } catch (e) {
      if (context.mounted) _toast(context, '定位失败：$e');
      return null;
    }
  }

  // 手动填写
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _ManualLocationDialog(initial: item.locationName),
  );
  if (!context.mounted) return null;
  if (name == null || name.isEmpty) return null;
  _toast(context, '已更新位置：$name');
  return item.copyWith(locationName: name, locationLat: 0, locationLng: 0);
}

void _toast(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// 长按卡片的菜单，返回 'edit' / 'delete' / 'location' / null
Future<String?> showRecordActions(BuildContext context, RecordItem item) async {
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.ink,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.edit_outlined, color: AppTheme.primary),
            title: const Text('编辑记录'),
            onTap: () => Navigator.pop(context, 'edit'),
          ),
          ListTile(
            leading: Icon(Icons.edit_location_alt_outlined,
                color: AppTheme.primary),
            title: const Text('修改地点'),
            onTap: () => Navigator.pop(context, 'location'),
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
  await Future<void>.delayed(Duration.zero);
  return action;
}

/// 手工填写“省 + 市”的对话框
class _ManualLocationDialog extends StatefulWidget {
  final String initial;

  const _ManualLocationDialog({this.initial = ''});

  @override
  State<_ManualLocationDialog> createState() => _ManualLocationDialogState();
}

class _ManualLocationDialogState extends State<_ManualLocationDialog> {
  final _provinceCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 已有地址时尽量拆出来回填，省得重新敲：湖北省恩施市 -> 湖北省 + 恩施市
    final init = widget.initial.trim();
    if (init.isEmpty || init == '当前位置') return;
    final sep = init.indexOf('省');
    if (sep >= 0) {
      _provinceCtrl.text = init.substring(0, sep + 1);
      _cityCtrl.text = init.substring(sep + 1);
      return;
    }
    final m = RegExp(r'[市区盟州]').firstMatch(init);
    if (m != null) {
      _provinceCtrl.text = init.substring(0, m.end);
      _cityCtrl.text = init.substring(m.end);
    } else {
      _cityCtrl.text = init;
    }
  }

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
