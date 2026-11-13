import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'data.dart';
import 'pages/home_page.dart';
import 'pages/record_edit_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RecordStore.init(); // 初始化 Hive 本地存储
  runApp(const TimeLineApp());
}

class TimeLineApp extends StatelessWidget {
  const TimeLineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '时间轴记录',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFCF7F2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          primary: Colors.orange,
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainContainer(),
    );
  }
}

/// 主容器：统一管理数据、日期、排版参数与三个页面
class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _tab = 0;

  List<RecordItem> _all = [];
  DateTime _date = DateTime.now();

  double _fontSize = 14;
  double _lineSpacing = 4;
  double _cardSpacing = 12;

  @override
  void initState() {
    super.initState();
    _fontSize = RecordStore.getSetting('fontSize', 14);
    _lineSpacing = RecordStore.getSetting('lineSpacing', 4);
    _cardSpacing = RecordStore.getSetting('cardSpacing', 12);
    _reload();
  }

  void _reload() {
    setState(() {
      _all = RecordStore.all();
    });
  }

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_date);

  List<RecordItem> get _todayRecords =>
      _all.where((e) => e.date == _dateKey).toList();

  void _shiftDate(int days) {
    setState(() {
      _date = _date.add(Duration(days: days));
    });
  }

  void _backToToday() {
    setState(() => _date = DateTime.now());
  }

  Future<void> _toggle(String id) async {
    final item = _all.firstWhere(
      (e) => e.id == id,
      orElse: () => RecordItem(
        id: id,
        title: '',
        content: '',
        date: '',
        time: '',
      ),
    );
    if (item.title.isEmpty && item.date.isEmpty) return;
    await RecordStore.save(item.copyWith(isCompleted: !item.isCompleted));
    _reload();
  }

  Future<void> _delete(RecordItem item) async {
    await RecordStore.delete(item);
    _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已删除「${item.title}」')));
  }

  Future<void> _openAdd() async {
    final created = await Navigator.push<RecordItem>(
      context,
      MaterialPageRoute(builder: (_) => RecordEditPage(initialDate: _date)),
    );
    if (created != null) {
      await RecordStore.save(created);
      _reload();
      setState(() {
        _date = DateTime.tryParse(created.date) ?? _date;
      });
    }
  }

  Future<void> _openEdit(BuildContext context, RecordItem item) async {
    final updated = await Navigator.push<RecordItem>(
      context,
      MaterialPageRoute(builder: (_) => RecordEditPage(existing: item)),
    );
    if (updated != null) {
      await RecordStore.save(updated);
      _reload();
    }
  }

  /// 首页直接更新某条记录（例如补充位置信息）
  Future<void> _updateItem(RecordItem item) async {
    await RecordStore.save(item);
    _reload();
  }

  void _onSettingsChanged(double fontSize, double lineSpacing,
      double cardSpacing) {
    setState(() {
      _fontSize = fontSize;
      _lineSpacing = lineSpacing;
      _cardSpacing = cardSpacing;
    });
    RecordStore.setSetting('fontSize', fontSize);
    RecordStore.setSetting('lineSpacing', lineSpacing);
    RecordStore.setSetting('cardSpacing', cardSpacing);
  }

  Future<void> _clearAll() async {
    await RecordStore.clearAll();
    _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已清空全部记录')));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        records: _todayRecords,
        date: _date,
        fontSize: _fontSize,
        lineSpacing: _lineSpacing,
        cardSpacing: _cardSpacing,
        onPrevDate: () => _shiftDate(-1),
        onNextDate: () => _shiftDate(1),
        onToday: _backToToday,
        onAdd: _openAdd,
        onToggle: _toggle,
        onEdit: _openEdit,
        onDelete: _delete,
        onUpdate: _updateItem,
        onChanged: _reload,
      ),
      SearchPage(records: _all, onChanged: _reload),
      SettingsPage(
        fontSize: _fontSize,
        lineSpacing: _lineSpacing,
        cardSpacing: _cardSpacing,
        onChanged: _onSettingsChanged,
        onClearAll: _clearAll,
        onImportDone: () async => _reload(),
      ),
    ];

    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        selectedItemColor: Colors.orange[700],
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '记录'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
