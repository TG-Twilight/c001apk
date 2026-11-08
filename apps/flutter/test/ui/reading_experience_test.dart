import 'package:c001apk_flutter/components/adaptive_reading_pane.dart';
import 'package:c001apk_flutter/components/feed_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'the desktop rail does not shift the article away from the window center',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Row(children: [
      const SizedBox(width: 80),
      Expanded(
          child: AdaptiveReadingPane(
        leadingInset: 80,
        detailBuilder: (_, id, close) => const Material(
            key: ValueKey('centered-article'), child: Text('正文')),
        child: Material(
            child: Builder(
                builder: (context) => Column(children: [
                      TextButton(
                          onPressed: () => FeedNavigation.open(context, '1'),
                          child: const Text('打开')),
                      const Text('辅助列表'),
                    ]))),
      )),
    ])));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(
        tester
            .getRect(find.byKey(const ValueKey('centered-article')))
            .center
            .dx,
        closeTo(640, 1));
    expect(find.text('辅助列表').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  Future<void> open(WidgetTester tester, {double width = 1320}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: AdaptiveReadingPane(
        detailBuilder: (_, id, close) => Scaffold(
          key: ValueKey('detail-$id'),
          appBar: AppBar(leading: BackButton(onPressed: close)),
          body: ListView(children: [
            for (var i = 0; i < 80; i++)
              SizedBox(height: 80, child: Text('正文 $id-$i')),
          ]),
        ),
        child: Material(
            child: Builder(
                builder: (context) => ListView(
                      children: [
                        for (var i = 0; i < 80; i++)
                          ListTile(
                              title: Text('动态 $i'),
                              onTap: () => FeedNavigation.open(context, '$i')),
                      ],
                    ))),
      ),
    ));
    await tester.tap(find.text('动态 0'));
    await tester.pumpAndSettle();
  }

  testWidgets('reading stays centered and bounded beside the auxiliary feed',
      (tester) async {
    await open(tester);
    final detail = tester.getRect(find.byKey(const ValueKey('detail-0')));
    expect(detail.center.dx, closeTo(660, 1));
    expect(detail.width, inInclusiveRange(640, 720));
    final feed = tester.getRect(find.text('动态 1'));
    expect(feed.left, greaterThan(detail.right));
    expect(feed.right, lessThanOrEqualTo(1320));
  });

  testWidgets('hiding the feed keeps reading position and survives resizing',
      (tester) async {
    await open(tester);
    final reading = find.descendant(
        of: find.byKey(const ValueKey('detail-0')),
        matching: find.byType(ListView));
    await tester.drag(reading, const Offset(0, -400));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('正文 0-8')).dy;
    await tester.tap(find.byTooltip('收起信息流'));
    await tester.pumpAndSettle();
    expect(find.text('动态 1').hitTestable(), findsNothing);
    expect(tester.getTopLeft(find.text('正文 0-8')).dy, closeTo(before, 1));
    tester.view.physicalSize = const Size(1600, 900);
    await tester.pumpAndSettle();
    expect(find.text('动态 1').hitTestable(), findsNothing);
    await tester.tap(find.byTooltip('显示信息流'));
    await tester.pumpAndSettle();
    expect(find.text('动态 1').hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(find.text('正文 0-8')).dy, closeTo(before, 1));
  });

  testWidgets(
      '1164dp tablet landscape keeps the feed beside the article with a rail',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1164, 777);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Row(children: [
        const SizedBox(width: 144),
        Expanded(
            child: AdaptiveReadingPane(
          leadingInset: 144,
          detailBuilder: (_, id, close) =>
              const Material(key: ValueKey('tablet-detail'), child: Text('正文')),
          child: Material(
              child: Builder(
                  builder: (context) => ListView(
                        children: [
                          TextButton(
                              onPressed: () =>
                                  FeedNavigation.open(context, '1'),
                              child: const Text('打开动态')),
                          const Text('信息流'),
                        ],
                      ))),
        )),
      ]),
    ));
    await tester.tap(find.text('打开动态'));
    await tester.pumpAndSettle();
    final detail = tester.getRect(find.byKey(const ValueKey('tablet-detail')));
    expect(find.text('信息流').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.text('信息流')).left, greaterThan(detail.right));
    expect(detail.width, greaterThanOrEqualTo(390));
    await tester.tap(find.byTooltip('收起信息流'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1600, 900);
    await tester.pumpAndSettle();
    expect(find.text('信息流').hitTestable(), findsNothing);
    await tester.tap(find.byTooltip('显示信息流'));
    await tester.pumpAndSettle();
    expect(find.text('信息流').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'tablet reading fits both panes and falls back when the window narrows',
      (tester) async {
    await open(tester, width: 800);
    final detail = tester.getRect(find.byKey(const ValueKey('detail-0')));
    expect(detail.width, 520);
    expect(find.text('动态 1').hitTestable(), findsOneWidget);
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('detail-0'))).width, 400);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('动态 1').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
