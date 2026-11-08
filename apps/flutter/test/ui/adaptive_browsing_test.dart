import 'package:c001apk_flutter/components/adaptive_card_list.dart';
import 'package:c001apk_flutter/components/adaptive_reading_pane.dart';
import 'package:c001apk_flutter/components/feed_navigation.dart';
import 'package:c001apk_flutter/components/app_keyboard_navigation.dart';
import 'package:c001apk_flutter/utils/utils.dart';
import 'package:c001apk_flutter/components/cards/carousel_card.dart';
import 'package:c001apk_flutter/logic/model/feed/entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  Future<void> resize(WidgetTester tester, double width,
      {double height = 900}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    await tester.pumpAndSettle();
  }

  tearDown(Get.reset);

  for (final sliver in [false, true]) {
    for (final (width, columns) in [
      (800.0, 2),
      (1200.0, 3),
      (1600.0, 4),
    ]) {
      testWidgets('$columns columns fill short-card gaps (sliver: $sliver)',
          (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await resize(tester, width);
        Widget card(BuildContext _, int i) =>
            SizedBox(key: ValueKey('gap-$i'), height: i == 0 ? 420 : 80);
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: sliver
                    ? CustomScrollView(slivers: [
                        AdaptiveCardList.sliver(
                            itemCount: 12, itemBuilder: card)
                      ])
                    : AdaptiveCardList(itemCount: 12, itemBuilder: card))));
        final short = tester.getRect(find.byKey(const ValueKey('gap-1')));
        final next = tester.getRect(find.byKey(ValueKey('gap-$columns')));
        // The next card must use the short column, with only the normal gap.
        expect(next.left, short.left);
        expect(next.top, closeTo(short.bottom + 10, 0.1));
        expect(
            next.top,
            lessThan(
                tester.getRect(find.byKey(const ValueKey('gap-0'))).bottom));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('cards form 1 to 4 columns as available width changes',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdaptiveCardList(
      itemCount: 20,
      itemBuilder: (_, i) =>
          SizedBox(key: ValueKey('card-$i'), height: 120, child: Text('$i')),
    ))));
    for (final (width, columns) in [
      (400.0, 1),
      (800.0, 2),
      (1200.0, 3),
      (1600.0, 4)
    ]) {
      await resize(tester, width);
      final first = tester.getTopLeft(find.byKey(const ValueKey('card-0')));
      final last =
          tester.getTopLeft(find.byKey(ValueKey('card-${columns - 1}')));
      final next = tester.getTopLeft(find.byKey(ValueKey('card-$columns')));
      expect(last.dy, first.dy);
      expect(next.dy, greaterThan(first.dy));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('headers span columns and footer follows all cards',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 1200);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdaptiveCardList(
      itemCount: 5,
      isFullWidth: (i) => i == 2,
      itemBuilder: (_, i) => SizedBox(key: ValueKey('item-$i'), height: 60),
      footer: const SizedBox(key: ValueKey('footer'), height: 40),
    ))));
    expect(tester.getSize(find.byKey(const ValueKey('item-2'))).width, 1180);
    expect(
        tester.getTopLeft(find.byKey(const ValueKey('item-3'))).dy,
        greaterThan(
            tester.getTopLeft(find.byKey(const ValueKey('item-2'))).dy));
    expect(
        tester.getTopLeft(find.byKey(const ValueKey('footer'))).dy,
        greaterThan(
            tester.getTopLeft(find.byKey(const ValueKey('item-4'))).dy));
  });

  testWidgets('structural cards and footer clear the tallest masonry column',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 1200, height: 1400);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdaptiveCardList(
      itemCount: 10,
      isFullWidth: (i) => i == 5,
      itemBuilder: (_, i) => SizedBox(
          key: ValueKey('boundary-$i'), height: i == 0 || i == 6 ? 420 : 80),
      footer: const SizedBox(key: ValueKey('boundary-footer'), height: 40),
    ))));
    Rect card(int i) => tester.getRect(find.byKey(ValueKey('boundary-$i')));
    expect(card(5).width, 1180);
    expect(card(5).top, card(0).bottom + 10);
    expect(card(6).top, card(5).bottom + 10);
    expect(card(9).top, card(7).bottom + 10);
    expect(tester.getRect(find.byKey(const ValueKey('boundary-footer'))).top,
        card(6).bottom + 10);
  });

  testWidgets('segments shorter than the column count scroll past normally',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 1600);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdaptiveCardList(
      controller: scroll,
      itemCount: 203,
      isFullWidth: (i) => i == 2,
      itemBuilder: (_, i) => SizedBox(
          key: ValueKey('short-$i'),
          height: i == 0
              ? 400
              : i == 1
                  ? 600
                  : 120),
    ))));
    final width = tester.getSize(find.byKey(const ValueKey('short-0'))).width;
    expect(width, 387.5);
    for (final offset in [300.0, 400.0, 600.0, 900.0, 1500.0, 400.0, 0.0]) {
      scroll.jumpTo(offset);
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(offset, 0.1));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('changing text size recalculates columns without resizing',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 1600);
    var scale = 1.0;
    late StateSetter update;
    final cards = AdaptiveCardList(
        itemCount: 20,
        itemBuilder: (_, i) =>
            SizedBox(key: ValueKey('scale-$i'), height: 120));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) {
        update = setState;
        return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: cards);
      },
    ))));
    expect(tester.getTopLeft(find.byKey(const ValueKey('scale-3'))).dy, 10);
    update(() => scale = 2);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('scale-1'))).dy, 10);
    expect(tester.getTopLeft(find.byKey(const ValueKey('scale-2'))).dy, 140);
  });

  testWidgets('masonry sections scroll both ways without losing their offsets',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 1600);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final built = <int>{};
    var footerBuilds = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdaptiveCardList(
      controller: scroll,
      itemCount: 500,
      isFullWidth: (i) => i % 20 == 0,
      itemBuilder: (_, i) {
        built.add(i);
        return SizedBox(
            key: ValueKey('section-$i'),
            height: i % 20 == 0 ? 60 : (i % 5 + 1) * 40);
      },
      footer: Builder(builder: (_) {
        footerBuilds++;
        return const Text('尾部');
      }),
    ))));
    expect(built.length, lessThan(80));
    expect(footerBuilds, 0);
    for (final offset in [
      500.0,
      1000.0,
      1500.0,
      2000.0,
      2500.0,
      3000.0,
      3500.0,
      2500.0,
      1500.0,
      500.0,
      0.0
    ]) {
      scroll.jumpTo(offset);
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(offset, 0.1));
      expect(tester.takeException(), isNull);
    }
    expect(tester.getRect(find.byKey(const ValueKey('section-0'))).top, 10);
    expect(tester.getRect(find.byKey(const ValueKey('section-4'))).top, 80);
    expect(footerBuilds, 0);
  });

  for (final sliver in [false, true]) {
    testWidgets('deep card anchor survives resizing after a heading ($sliver)',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await resize(tester, 1600);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      Widget card(BuildContext _, int i) => SizedBox(
          key: ValueKey('deep-$i'), height: i == 0 ? 60 : (i % 5 + 1) * 40);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: sliver
                  ? CustomScrollView(controller: scroll, slivers: [
                      AdaptiveCardList.sliver(
                          itemCount: 500,
                          isFullWidth: (i) => i == 0,
                          itemBuilder: card)
                    ])
                  : AdaptiveCardList(
                      controller: scroll,
                      itemCount: 500,
                      isFullWidth: (i) => i == 0,
                      itemBuilder: card))));
      for (var offset = 500.0; offset <= 4000; offset += 500) {
        scroll.jumpTo(offset);
        await tester.pumpAndSettle();
      }
      final anchor = find.byKey(const ValueKey('deep-123'));
      await tester.ensureVisible(anchor);
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(anchor).dy;
      await resize(tester, 400);
      expect(anchor, findsOneWidget);
      expect(tester.getTopLeft(anchor).dy, closeTo(top, 1));
      await resize(tester, 1600);
      expect(tester.getTopLeft(anchor).dy, closeTo(top, 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('appending pages keeps visible cards in place', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 1200);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var count = 40;
    late StateSetter update;
    await tester
        .pumpWidget(MaterialApp(home: StatefulBuilder(builder: (_, setState) {
      update = setState;
      return Scaffold(
          body: AdaptiveCardList(
              controller: scroll,
              itemCount: count,
              itemBuilder: (_, i) => SizedBox(
                  key: ValueKey('append-$i'), height: i % 3 == 0 ? 360 : 80)));
    })));
    scroll.jumpTo(250);
    await tester.pumpAndSettle();
    final before = tester.getRect(find.byKey(const ValueKey('append-6')));
    update(() => count = 80);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('append-6'))), before);
    expect(scroll.offset, 250);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long full-width lists recycle cards behind the viewport',
      (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdaptiveCardList(
                controller: scroll,
                itemCount: 1000,
                isFullWidth: (_) => true,
                itemBuilder: (_, i) {
                  builds++;
                  return SizedBox(key: ValueKey('recycle-$i'), height: 120);
                }))));
    scroll.jumpTo(50000);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recycle-0')), findsNothing);
    builds = 0;
    scroll.jumpTo(50010);
    await tester.pumpAndSettle();
    expect(builds, lessThan(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('growing a card reflows later cards without overlap',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 800);
    var expanded = false;
    late StateSetter update;
    await tester
        .pumpWidget(MaterialApp(home: StatefulBuilder(builder: (_, setState) {
      update = setState;
      return Scaffold(
          body: AdaptiveCardList(
              itemCount: 8,
              itemBuilder: (_, i) => SizedBox(
                  key: ValueKey('grow-$i'),
                  height: i == 0 && expanded ? 420 : 80)));
    })));
    update(() => expanded = true);
    await tester.pumpAndSettle();
    final short = tester.getRect(find.byKey(const ValueKey('grow-1')));
    final next = tester.getRect(find.byKey(const ValueKey('grow-2')));
    expect(next.left, short.left);
    expect(next.top, short.bottom + 10);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'wide banners leave room for browsing and retain phone proportions',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 1600);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.topCenter,
                child: CarouselCard(dataList: [
                  Entity.fromJson({'url': '/feed/1', 'pic': ''})
                ])))));
    expect(tester.getSize(find.byType(CarouselCard)).height,
        lessThanOrEqualTo(240));
    await resize(tester, 400);
    expect(
        tester.getSize(find.byType(CarouselCard)).height, closeTo(400 / 3, 1));
  });

  Widget reader(
          {ReadingMode mode = ReadingMode.automatic,
          String? shareLink,
          ValueChanged<bool>? onCanHandlePop}) =>
      GetMaterialApp(
        builder: (_, child) => NotificationListener<NavigationNotification>(
            onNotification: (notification) {
              onCanHandlePop?.call(notification.canHandlePop);
              return false;
            },
            child: AppKeyboardNavigation(navigatorKey: Get.key, child: child!)),
        getPages: [
          GetPage(
              name: '/feed/:id', page: () => const Scaffold(body: Text('独立详情')))
        ],
        home: AdaptiveReadingPane(
          mode: mode,
          detailBuilder: (_, id, close) => Scaffold(
            appBar: AppBar(
                leading: BackButton(onPressed: close), title: Text('详情 $id')),
            body: ListView(key: const ValueKey('reading-scroll'), children: [
              for (var i = 0; i < 30; i++)
                SizedBox(height: 80, child: Text('正文 $id-$i')),
              Builder(
                  builder: (context) => TextButton(
                      onPressed: () => FeedNavigation.open(context, '99'),
                      child: const Text('关联动态')))
            ]),
          ),
          child: Scaffold(
              body: Builder(
                  builder: (context) => ListView(
                        key: const ValueKey('feed-scroll'),
                        children: [
                          const Text('信息流说明'),
                          if (shareLink != null)
                            TextButton(
                                onPressed: () => Utils.onOpenLink(
                                    shareLink, null, false, context),
                                child: const Text('分享动态')),
                          for (var i = 0; i < 50; i++)
                            ListTile(
                              title: Text('动态 $i'),
                              onTap: () => FeedNavigation.open(context, '$i'),
                            )
                        ],
                      ))),
        ),
      );

  testWidgets(
      'detail stays centered and the auxiliary list remains interactive',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 1400);
    await tester.pumpWidget(reader());
    await tester.tap(find.text('动态 0'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('详情 0')).dx,
        lessThan(tester.getTopLeft(find.text('动态 0')).dx));
    await tester.tap(find.text('动态 1'));
    await tester.pumpAndSettle();
    expect(find.text('详情 1'), findsOneWidget);
    expect(find.text('详情 0'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('详情 1'), findsNothing);
    expect(find.text('详情 0'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('动态 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing keeps detail state and returning preserves list offset',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 1200);
    await tester.pumpWidget(reader());
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final tile = find.text('动态 10');
    final before = tester.getTopLeft(tile).dy;
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await resize(tester, 400);
    expect(find.text('详情 10'), findsOneWidget);
    await resize(tester, 1200);
    expect(find.text('详情 10'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(tile).dy, closeTo(before, 1));
  });

  testWidgets(
      'manual mode enables phone landscape but keeps portrait single page',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 760, height: 400);
    await tester.pumpWidget(reader(mode: ReadingMode.enabled));
    await tester.tap(find.text('动态 0'));
    await tester.pumpAndSettle();
    expect(find.text('详情 0'), findsOneWidget);
    expect(find.text('动态 0').hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(find.text('动态 0')).dx,
        greaterThan(tester.getTopLeft(find.text('详情 0')).dx));
    await tester.pageBack();
    await resize(tester, 400, height: 760);
    await tester.tap(find.text('动态 0'));
    await tester.pumpAndSettle();
    expect(find.text('独立详情'), findsOneWidget);
  });

  testWidgets('automatic mode fits both panes on a portrait tablet',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 760, height: 1100);
    await tester.pumpWidget(reader());
    await tester.tap(find.text('动态 0'));
    await tester.pumpAndSettle();
    expect(find.text('详情 0'), findsOneWidget);
    expect(find.text('动态 0').hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(find.text('动态 0')).dx,
        greaterThan(tester.getTopLeft(find.text('详情 0')).dx));
  });

  for (final mode in [ReadingMode.automatic, ReadingMode.disabled]) {
    testWidgets('$mode uses an independent page on phone landscape',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await resize(tester, mode == ReadingMode.disabled ? 1200 : 900,
          height: 400);
      await tester.pumpWidget(reader(mode: mode));
      await tester.tap(find.text('动态 0'));
      await tester.pumpAndSettle();
      expect(find.text('独立详情'), findsOneWidget);
      expect(find.text('详情 0'), findsNothing);
    });
  }

  testWidgets('system back dismisses a dialog before closing the reading pane',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 1200);
    await tester.pumpWidget(reader());
    await tester.tap(find.text('动态 0'));
    await tester.pumpAndSettle();
    showDialog<void>(
        context: tester.element(find.text('详情 0')),
        builder: (_) => const AlertDialog(title: Text('临时弹窗')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('临时弹窗'), findsNothing);
    expect(find.text('详情 0'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('详情 0'), findsNothing);
  });

  testWidgets(
      'embedded details tell the native back bridge they can handle back',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final events = <bool>[];
    await resize(tester, 1200);
    await tester.pumpWidget(reader(onCanHandlePop: events.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('动态 0'));
    await tester.pumpAndSettle();
    expect(events.last, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('详情 0'), findsNothing);
    expect(events.last, isFalse);
  });

  testWidgets('pagination footer is lazy until the end approaches',
      (tester) async {
    var footerBuilds = 0;
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdaptiveCardList(
      controller: scroll,
      itemCount: 100,
      itemBuilder: (_, i) => const SizedBox(height: 120),
      footer: Builder(builder: (_) {
        footerBuilds++;
        return const Text('列表尾部');
      }),
    ))));
    expect(footerBuilds, 0);
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(footerBuilds, 1);
  });

  testWidgets('changing columns preserves the visible feed row',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await resize(tester, 1200);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdaptiveCardList(
      controller: scroll,
      itemCount: 100,
      itemBuilder: (_, i) => SizedBox(
          key: ValueKey('anchor-$i'), height: 120, child: Text('卡片 $i')),
    ))));
    scroll.jumpTo(520);
    await tester.pumpAndSettle();
    final originalTop =
        tester.getTopLeft(find.byKey(const ValueKey('anchor-12'))).dy;
    await resize(tester, 400);
    expect(find.byKey(const ValueKey('anchor-12')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('anchor-12'))).dy,
        closeTo(originalTop, 1));
    await resize(tester, 1200);
    expect(tester.getTopLeft(find.byKey(const ValueKey('anchor-12'))).dy,
        closeTo(originalTop, 1));
    for (final width in [400.0, 800.0, 1200.0, 400.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('anchor-12'))).dy,
        closeTo(originalTop, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrows follow the active pane even when the feed is wider',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 2000);
    await tester.pumpWidget(reader());
    await tester.tap(find.text('动态 0'));
    await tester.pumpAndSettle();
    ScrollPosition position(String key) => tester
        .state<ScrollableState>(find
            .descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(Scrollable))
            .first)
        .position;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(position('reading-scroll').pixels, greaterThan(0));
    expect(position('feed-scroll').pixels, 0);
    await tester.tap(find.text('信息流说明'));
    final detailOffset = position('reading-scroll').pixels;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(position('reading-scroll').pixels, detailOffset);
    expect(position('feed-scroll').pixels, greaterThan(0));
  });

  testWidgets('reselecting a cached article focuses its reading scroll region',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await resize(tester, 1400);
    await tester.pumpWidget(reader());
    for (final id in [0, 1, 0]) {
      await tester.tap(find.text('动态 $id'));
      await tester.pumpAndSettle();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find
            .descendant(
                of: find.byKey(const ValueKey('reading-scroll')),
                matching: find.byType(Scrollable))
            .first)
        .position;
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('variable height cards preserve their anchor when columns change',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await resize(tester, 1200);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdaptiveCardList(
      controller: scroll,
      itemCount: 90,
      itemBuilder: (_, i) => LayoutBuilder(
          builder: (_, box) => SizedBox(
              key: ValueKey('variable-$i'),
              height: (i % 4 + 1) * 35 * (box.maxWidth < 500 ? 1.5 : 1),
              child: Text('$i'))),
    ))));
    final key = find.byKey(const ValueKey('variable-15'));
    await tester.scrollUntilVisible(key, 250);
    await tester.ensureVisible(key);
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(key).dy;
    await resize(tester, 400);
    expect(tester.getTopLeft(key).dy, closeTo(top, 1));
    await resize(tester, 1200);
    expect(tester.getTopLeft(key).dy, closeTo(top, 1));
  });

  testWidgets('profile sliver preserves the visible row across column changes',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await resize(tester, 1200);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CustomScrollView(controller: scroll, slivers: [
      const SliverToBoxAdapter(child: SizedBox(height: 180)),
      AdaptiveCardList.sliver(
          itemCount: 90,
          itemBuilder: (_, i) =>
              SizedBox(key: ValueKey('sliver-$i'), height: 120)),
    ]))));
    scroll.jumpTo(700);
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('sliver-12'));
    final top = tester.getTopLeft(card).dy;
    await resize(tester, 400);
    expect(tester.getTopLeft(card).dy, closeTo(top, 1));
    await resize(tester, 1200);
    expect(tester.getTopLeft(card).dy, closeTo(top, 1));
  });

  for (final link in [
    '/feed/123?s=test',
    'https://www.coolapk.com/feed/123?s=test',
    'coolmarket://feed/123'
  ]) {
    testWidgets('shared link $link stays in the reading pane', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await resize(tester, 1200);
      await tester.pumpWidget(reader(shareLink: link));
      await tester.tap(find.text('分享动态'));
      await tester.pumpAndSettle();
      expect(find.text('详情 123'), findsOneWidget);
      expect(Get.currentRoute, '/');
      final detail = find.byKey(const ValueKey('reading-scroll'));
      await tester.scrollUntilVisible(find.text('关联动态'), 600,
          scrollable: find
              .descendant(of: detail, matching: find.byType(Scrollable))
              .first);
      await tester.tap(find.text('关联动态'));
      await tester.pumpAndSettle();
      expect(find.text('详情 99'), findsOneWidget);
      expect(Get.currentRoute, '/');
    });
  }
}
