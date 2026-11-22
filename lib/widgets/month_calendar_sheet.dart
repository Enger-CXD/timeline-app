import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

/// 弹出月历，左右滑动切换月份，单击选某一天。
/// 返回用户点中的日期；直接关掉返回 null。
Future<DateTime?> showMonthCalendar(
  BuildContext context, {
  required DateTime initialDate,
  Set<String> markedDates = const {},
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => MonthCalendarSheet(
      initialDate: initialDate,
      markedDates: markedDates,
    ),
  );
}

/// 月历面板：一个月一页，横向滑动换月
class MonthCalendarSheet extends StatefulWidget {
  final DateTime initialDate;

  /// 有记录的日期（yyyy-MM-dd），在日历上打个小圆点
  final Set<String> markedDates;

  const MonthCalendarSheet({
    super.key,
    required this.initialDate,
    this.markedDates = const {},
  });

  @override
  State<MonthCalendarSheet> createState() => _MonthCalendarSheetState();
}

class _MonthCalendarSheetState extends State<MonthCalendarSheet> {
  /// 从中间随便挑一页做锚点，前后各留 100 年，足够左右滑
  static const int _anchorPage = 1200;

  late final DateTime _anchorMonth =
      DateTime(widget.initialDate.year, widget.initialDate.month, 1);
  late final PageController _controller =
      PageController(initialPage: _anchorPage);
  late int _page = _anchorPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _monthOf(int page) =>
      DateTime(_anchorMonth.year, _anchorMonth.month + (page - _anchorPage), 1);

  DateTime get _visibleMonth => _monthOf(_page);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _goToMonth(int delta) {
    _controller.animateToPage(
      _page + delta,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _pick(DateTime day) => Navigator.pop(context, day);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 448 + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 月份标题 + 换月箭头 + 回今天
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: '上个月',
                  icon: Icon(Icons.chevron_left, color: AppTheme.primary),
                  onPressed: () => _goToMonth(-1),
                ),
                Expanded(
                  child: Text(
                    DateFormat('yyyy年M月').format(_visibleMonth),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '下个月',
                  icon: Icon(Icons.chevron_right, color: AppTheme.primary),
                  onPressed: () => _goToMonth(1),
                ),
                TextButton(
                  onPressed: () => _pick(DateTime.now()),
                  child: Text('回今天',
                      style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                ),
              ],
            ),
          ),
          // 星期表头
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: List.generate(7, (i) {
                const labels = ['一', '二', '三', '四', '五', '六', '日'];
                return Expanded(
                  child: Center(
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: i >= 5 ? AppTheme.primary : Colors.grey,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (p) => setState(() => _page = p),
              itemBuilder: (_, index) => _buildMonth(_monthOf(index)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    // 周一为一周第一天
    final leading = first.weekday - 1;
    final cells = leading + days;
    final rows = (cells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        children: List.generate(rows, (r) {
          return Expanded(
            child: Row(
              children: List.generate(7, (c) {
                final i = r * 7 + c;
                final dayIndex = i - leading + 1;
                if (i < leading || dayIndex > days) {
                  return const Expanded(child: SizedBox());
                }
                return Expanded(child: _dayCell(DateTime(month.year, month.month, dayIndex)));
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _dayCell(DateTime day) {
    final selected = _sameDay(day, widget.initialDate);
    final today = _sameDay(day, DateTime.now());
    final hasRecord = widget.markedDates
        .contains(DateFormat('yyyy-MM-dd').format(day));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _pick(day),
      child: Center(
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            shape: BoxShape.circle,
            border: today && !selected
                ? Border.all(color: AppTheme.primary, width: 1.4)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? Colors.white
                      : (today ? AppTheme.primary : AppTheme.ink),
                ),
              ),
              if (hasRecord)
                Positioned(
                  bottom: 5,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
