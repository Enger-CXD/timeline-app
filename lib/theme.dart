import 'package:flutter/material.dart';

/// 一套配色（主题皮肤）
class AppPalette {
  final String id;
  final String name;
  final String desc;
  final Color bg; // 页面底色
  final Color card; // 卡片底色
  final Color ink; // 标题/强调文字
  final Color body; // 正文
  final Color primary; // 主色（按钮、日期胶囊、图标）
  final Color primarySoft; // 主色的浅底
  final Color line; // 分割线/描边

  const AppPalette({
    required this.id,
    required this.name,
    required this.desc,
    required this.bg,
    required this.card,
    required this.ink,
    required this.body,
    required this.primary,
    required this.primarySoft,
    required this.line,
  });

  /// 主色的浅色版本（用于浅底图标等）
  Color get primaryLight => Color.lerp(primary, Colors.white, 0.55)!;
}

/// 内置配色列表：原木米杏 + 5 套莫兰迪风格
const List<AppPalette> kPalettes = [
  AppPalette(
    id: 'wood',
    name: '原木米杏',
    desc: '默认暖色，米底焦糖字',
    bg: Color(0xFFFCF7F2),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF7C2D12),
    body: Color(0xFF3A3A3A),
    primary: Color(0xFFB45309),
    primarySoft: Color(0xFFFAE8DC),
    line: Color(0xFFEFE3D9),
  ),
  AppPalette(
    id: 'morandi_pink',
    name: '莫兰迪豆沙',
    desc: '灰粉调，柔和不刺眼',
    bg: Color(0xFFF4F1EF),
    card: Color(0xFFFDFDFC),
    ink: Color(0xFF5C514B),
    body: Color(0xFF4A423D),
    primary: Color(0xFFA27F78),
    primarySoft: Color(0xFFE8DCD8),
    line: Color(0xFFE6DEDA),
  ),
  AppPalette(
    id: 'morandi_green',
    name: '莫兰迪鼠尾草',
    desc: '灰绿调，安静耐看',
    bg: Color(0xFFF1F3EF),
    card: Color(0xFFFDFDFC),
    ink: Color(0xFF4A5450),
    body: Color(0xFF3F4844),
    primary: Color(0xFF7E9284),
    primarySoft: Color(0xFFDFEAE2),
    line: Color(0xFFE0E7E2),
  ),
  AppPalette(
    id: 'morandi_blue',
    name: '莫兰迪雾蓝',
    desc: '灰蓝调，干净清爽',
    bg: Color(0xFFEFF2F5),
    card: Color(0xFFFDFDFD),
    ink: Color(0xFF46525D),
    body: Color(0xFF3D474F),
    primary: Color(0xFF7C93A8),
    primarySoft: Color(0xFFDEE7EE),
    line: Color(0xFFE0E7ED),
  ),
  AppPalette(
    id: 'morandi_purple',
    name: '莫兰迪藕紫',
    desc: '灰紫调，柔和高级',
    bg: Color(0xFFF3F1F4),
    card: Color(0xFFFDFDFD),
    ink: Color(0xFF534B58),
    body: Color(0xFF453F49),
    primary: Color(0xFF8C8095),
    primarySoft: Color(0xFFE7E1EC),
    line: Color(0xFFE6E1E9),
  ),
  AppPalette(
    id: 'morandi_caramel',
    name: '莫兰迪焦糖',
    desc: '灰棕调，温润沉稳',
    bg: Color(0xFFF5F1ED),
    card: Color(0xFFFDFCFB),
    ink: Color(0xFF55483C),
    body: Color(0xFF463B31),
    primary: Color(0xFFA08063),
    primarySoft: Color(0xFFEADFD4),
    line: Color(0xFFE7DDD2),
  ),
];

/// 当前生效的主题（全局静态，页面直接读这里取色）
class AppTheme {
  static AppPalette palette = kPalettes.first;

  static void apply(String id) {
    final m = kPalettes.where((p) => p.id == id);
    palette = m.isEmpty ? kPalettes.first : m.first;
  }

  static String get id => palette.id;
  static Color get bg => palette.bg;
  static Color get card => palette.card;
  static Color get ink => palette.ink;
  static Color get body => palette.body;
  static Color get primary => palette.primary;
  static Color get primarySoft => palette.primarySoft;
  static Color get primaryLight => palette.primaryLight;
  static Color get line => palette.line;
}
