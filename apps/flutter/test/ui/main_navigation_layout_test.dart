import 'dart:io';

import 'package:c001apk_flutter/components/adaptive_main_scaffold.dart';
import 'package:c001apk_flutter/components/liquid_navigation_bar.dart';
import 'package:c001apk_flutter/constants/liquid_glass_level.dart';
import 'package:c001apk_flutter/components/common_body.dart';
import 'package:c001apk_flutter/components/adaptive_card_list.dart';
import 'package:c001apk_flutter/logic/model/feed/datum.dart';
import 'package:c001apk_flutter/logic/state/loading_state.dart';
import 'package:c001apk_flutter/pages/common/common_controller.dart';
import 'package:c001apk_flutter/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:get/get.dart';

class _FeedController extends CommonController {
  @override
  Future<LoadingState> customGetData() async => LoadingState.empty();
}

void main() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('main-navigation-');
    Hive.init(directory.path);
    GStorage.settings = await Hive.openBox('settings');
  });
  setUp(() => GStorage.settings.clear());
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
    double width = 400,
    double bottom = 24,
    double keyboard = 0,
    Widget? body,
    ValueChanged<int>? onSelected,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: platform),
      home: MediaQuery(
        data: MediaQueryData(
            size: Size(width, 800),
            padding: EdgeInsets.only(bottom: bottom),
            viewPadding: EdgeInsets.only(bottom: bottom),
            viewInsets: EdgeInsets.only(bottom: keyboard)),
        child: AdaptiveMainScaffold(
          selectedIndex: 0,
          onDestinationSelected: onSelected ?? (_) {},
          bodyBuilder: (_, useRail) =>
              body ??
              Builder(
                  builder: (context) => ListView.builder(
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.paddingOf(context).bottom),
                        itemCount: 30,
                        itemBuilder: (_, i) =>
                            SizedBox(height: 100, child: Text('项目 $i')),
                      )),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Android floats over real content and reserves the bottom once',
      (tester) async {
    await mount(tester);
    expect(find.byType(LiquidNavigationBar), findsOneWidget);
    final list = tester.getRect(find.byType(ListView));
    expect(list.bottom, 800);
    final inset =
        tester.widget<ListView>(find.byType(ListView)).padding! as EdgeInsets;
    expect(inset.bottom, 102); // 64 content + 14 top + 24 safe bottom.
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('项目 29')).bottom, lessThanOrEqualTo(698));
  });

  testWidgets(
      'common feed reads the local reserved inset instead of the navigator inset',
      (tester) async {
    final controller = _FeedController()..isEnd = true;
    controller.loadingState.value = LoadingState.success([
      Datum(id: '1', entityType: 'feed'),
    ]);
    await tester.pumpWidget(GetMaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(padding: EdgeInsets.only(bottom: 102)),
      child: Scaffold(
          body: commonBody(controller,
              itemBuilder: (_) => const SizedBox(height: 100))),
    )));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<AdaptiveCardList>(find.byType(AdaptiveCardList))
            .padding
            .bottom,
        112);
    await tester.pumpWidget(const SizedBox());
    Get.reset();
  });

  testWidgets('space beside the capsule passes scrolling to the feed',
      (tester) async {
    await mount(tester);
    final scroll =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    final bar =
        tester.getRect(find.byKey(const ValueKey('liquid-drag-surface')));
    await tester.dragFrom(Offset(20, bar.center.dy), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(scroll.pixels, greaterThan(60));
  });

  testWidgets(
      'a nested page floating action button stays above the expanded capsule',
      (tester) async {
    await mount(tester,
        width: 360,
        body: Scaffold(
          floatingActionButton: FloatingActionButton(
              onPressed: () {}, child: const Icon(Icons.add)),
          body: const SizedBox.expand(),
        ));
    final bar =
        tester.getRect(find.byKey(const ValueKey('liquid-drag-surface')));
    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(fab.bottom, lessThanOrEqualTo(bar.top - 14));
  });

  testWidgets('transparent capsule corners pass scrolling to the feed',
      (tester) async {
    await mount(tester);
    final scroll =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    final bar =
        tester.getRect(find.byKey(const ValueKey('liquid-drag-surface')));
    await tester.dragFrom(
        bar.topLeft + const Offset(1, 1), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(scroll.pixels, greaterThan(60));
  });

  testWidgets('Windows uses floating navigation on a narrow window',
      (tester) async {
    await mount(tester, platform: TargetPlatform.windows);
    expect(find.byType(LiquidNavigationBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Windows glass preferences and width changes preserve the feed',
      (tester) async {
    await mount(tester, platform: TargetPlatform.windows, width: 1280);
    expect(
        tester
            .widget<LiquidNavigationBar>(find.byType(LiquidNavigationBar))
            .direction,
        Axis.vertical);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final scroll =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    final offset = scroll.pixels;
    await tester.binding.setSurfaceSize(const Size(500, 800));
    await tester.pumpAndSettle();
    expect(find.byType(LiquidNavigationBar), findsOneWidget);
    await tester
        .runAsync(() => GStorage.settings.put('floatingNavigation', false));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.state<ScrollableState>(find.byType(Scrollable)).position,
        same(scroll));
    expect(scroll.pixels, closeTo(offset, 1));
  });

  testWidgets('wide Android uses the rail and resizing preserves scroll',
      (tester) async {
    await mount(tester, width: 400);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final scroll =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    final offset = scroll.pixels;
    await tester.binding.setSurfaceSize(const Size(900, 800));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<LiquidNavigationBar>(find.byType(LiquidNavigationBar))
            .direction,
        Axis.vertical);
    expect(
        identical(
            tester.state<ScrollableState>(find.byType(Scrollable)).position,
            scroll),
        isTrue);
    expect(scroll.pixels, closeTo(offset, 1));
  });

  testWidgets('wide floating navigation is centered and selects vertically',
      (tester) async {
    final selections = <int>[];
    await mount(tester,
        width: 1280,
        platform: TargetPlatform.windows,
        onSelected: selections.add);
    final surface = find.byKey(const ValueKey('liquid-drag-surface'));
    final rect = tester.getRect(surface);
    expect(rect.center.dx, closeTo(72, 1));
    expect(rect.center.dy, closeTo(400, 1));
    expect(rect.height, greaterThan(rect.width));
    await tester.dragFrom(
        Offset(rect.center.dx, rect.top + 35), const Offset(0, 175));
    await tester.pumpAndSettle();
    expect(selections.last, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'wide standard navigation remains centered when floating is disabled',
      (tester) async {
    await tester.runAsync(() => GStorage.settings.put(SettingsBoxKey.floatingNavigation, false));
    await mount(tester, width: 1280);
    final top = tester.getRect(find.text('主页')).top;
    final bottom = tester.getRect(find.text('我的')).bottom;
    expect((top + bottom) / 2, closeTo(400, 40));
    expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .groupAlignment,
        0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('style preference changes keep the mounted feed and its offset',
      (tester) async {
    await mount(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final scroll =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    final offset = scroll.pixels;
    await tester
        .runAsync(() => GStorage.settings.put('floatingNavigation', false));
    await tester.pumpAndSettle();
    expect(find.byType(LiquidNavigationBar), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
        identical(
            tester.state<ScrollableState>(find.byType(Scrollable)).position,
            scroll),
        isTrue);
    expect(scroll.pixels, closeTo(offset, 1));
  });

  testWidgets('switching glass levels reaches the bar without remounting feeds',
      (tester) async {
    await mount(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final scroll =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    final offset = scroll.pixels;
    for (final level in LiquidGlassLevel.values) {
      await tester.runAsync(
          () => GStorage.settings.put('liquidGlassLevel', level.storedValue));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<LiquidNavigationBar>(find.byType(LiquidNavigationBar))
              .level,
          level);
      expect(
          identical(
              tester.state<ScrollableState>(find.byType(Scrollable)).position,
              scroll),
          isTrue);
      expect(scroll.pixels, closeTo(offset, 1));
    }
  });

  testWidgets(
      'the software keyboard hides navigation instead of covering input',
      (tester) async {
    await mount(tester, keyboard: 300);
    expect(find.byType(LiquidNavigationBar), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
