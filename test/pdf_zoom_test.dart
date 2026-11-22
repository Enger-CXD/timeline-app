import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';

import 'package:time_line_demo/pages/pdf_preview_page.dart';

/// 用 1 张图冒充 PDF 页面（原生通道被打桩），验证预览页“双指缩放”真的改变了渲染尺寸。
/// photo_view 在 filterQuality != none 时靠布局尺寸表达缩放，所以这里量图片本身的尺寸。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Uint8List png = File('assets_icon_1024.png').readAsBytesSync();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('timeline/file'),
            (MethodCall call) async {
      switch (call.method) {
        case 'pdfPages':
          return 2;
        case 'pdfRender':
          return png;
        default:
          return null;
      }
    });
  });

  Future<void> openPreview(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: PdfPreviewPage(path: '/tmp/fake.pdf')),
    );
    await tester.pump();
    // 让原生返回 + 图片解码在真实时间里跑完
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }
    expect(find.textContaining('左右滑动翻页'), findsOneWidget);
    expect(find.byType(RawImage), findsWidgets);
  }

  double pageWidth(WidgetTester tester) =>
      tester.getSize(find.byType(RawImage).first).width;

  Future<void> pinch(WidgetTester tester,
      {required double step,
      int frames = 12,
      bool zoomIn = true,
      double startOffset = 40}) async {
    final center = tester.getCenter(find.byType(PhotoView));
    final g1 = await tester.startGesture(center - Offset(startOffset, 0));
    final g2 = await tester.startGesture(center + Offset(startOffset, 0));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < frames; i++) {
      await g1.moveBy(Offset(zoomIn ? -step : step, 0));
      await g2.moveBy(Offset(zoomIn ? step : -step, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g1.up();
    await g2.up();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('双指张开 → 页面放大', (tester) async {
    await openPreview(tester);
    final before = pageWidth(tester);
    await pinch(tester, step: 12);
    final after = pageWidth(tester);
    // ignore: avoid_print
    print('pinch out: $before -> $after');
    expect(after, greaterThan(before * 1.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('双指捏合 → 页面缩小', (tester) async {
    await openPreview(tester);
    final initial = pageWidth(tester);
    await pinch(tester, step: 14);
    final zoomed = pageWidth(tester);
    expect(zoomed, greaterThan(initial));

    await pinch(tester,
        step: 11, frames: 20, zoomIn: false, startOffset: 240);
    final back = pageWidth(tester);
    // ignore: avoid_print
    print('pinch in: $zoomed -> $back');
    expect(back, lessThan(zoomed));
    expect(tester.takeException(), isNull);
  });
}
