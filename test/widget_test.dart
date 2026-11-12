import 'package:flutter_test/flutter_test.dart';
import 'package:time_line_demo/data.dart';

void main() {
  test('RecordItem 序列化与反序列化保持一致', () {
    final item = RecordItem(
      id: 'x1',
      title: '测试标题',
      content: '测试内容',
      date: '2026-11-12',
      time: '12:45',
      isCompleted: true,
      images: const ['/a.jpg', '/b.jpg'],
      voicePath: '/c.m4a',
      voiceSeconds: 15,
    );

    final restored = RecordItem.fromMap(item.toMap());

    expect(restored.id, 'x1');
    expect(restored.title, '测试标题');
    expect(restored.content, '测试内容');
    expect(restored.date, '2026-11-12');
    expect(restored.time, '12:45');
    expect(restored.isCompleted, true);
    expect(restored.images.length, 2);
    expect(restored.voicePath, '/c.m4a');
    expect(restored.voiceSeconds, 15);
  });

  test('dateTag 取整点作为时间轴标签', () {
    final item =
        RecordItem(id: '1', title: 't', content: 'c', date: '2026-11-12', time: '12:45');
    expect(item.dateTag, '12:00');
    expect(item.sortKey, '2026-11-12 12:45');
  });

  test('copyWith 只改指定字段', () {
    final item =
        RecordItem(id: '1', title: 't', content: 'c', date: 'd', time: '10:12');
    final done = item.copyWith(isCompleted: true);
    expect(done.id, '1');
    expect(done.title, 't');
    expect(done.isCompleted, true);
    expect(item.isCompleted, false);
  });
}
