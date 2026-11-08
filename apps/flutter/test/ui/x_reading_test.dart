import 'dart:convert';
import 'dart:io';

import 'package:c001apk_flutter/components/adaptive_reading_pane.dart';
import 'package:c001apk_flutter/components/feed_navigation.dart';
import 'package:c001apk_flutter/components/reading_presentation.dart';
import 'package:c001apk_flutter/logic/network/request.dart';
import 'package:c001apk_flutter/pages/feed/feed_page.dart';
import 'package:c001apk_flutter/pages/home/home_page.dart';
import 'package:c001apk_flutter/pages/home/feed/home_feed_controller.dart';
import 'package:c001apk_flutter/pages/home/return_top_controller.dart';
import 'package:c001apk_flutter/logic/model/feed/datum.dart';
import 'package:c001apk_flutter/utils/global_data.dart';
import 'package:c001apk_flutter/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../network/guest_detail_test.dart' show GuestDetailAdapter;

void main() {
  late Directory temporary;
  late GuestDetailAdapter adapter;
  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('c001apk-x-reading-');
    Hive.init(temporary.path);
    GStorage.settings = await Hive.openBox('settings');
    GStorage.blackList = await Hive.openBox('blackList');
    GStorage.favFeed = await Hive.openBox('favFeed');
    await GStorage.settings.putAll({
      SettingsBoxKey.xAppDevice: 'synthetic-device',
      SettingsBoxKey.versionCode: '2604201',
      SettingsBoxKey.versionName: '16.2.0',
      SettingsBoxKey.apiVersion: '16',
      SettingsBoxKey.sdkInt: '33',
      SettingsBoxKey.userAgent: 'SyntheticTest/1.0',
      SettingsBoxKey.recordHistory: false,
    });
    Request();
  });
  setUp(() {
    GlobalData().isLogin = false;
    adapter = GuestDetailAdapter();
    Request.dio.httpClientAdapter = adapter;
  });
  tearDown(() => Get.reset());
  tearDownAll(() async {
    await Hive.close();
    await temporary.delete(recursive: true);
  });

  testWidgets('reading supplement hides home chrome and preserves its page',
      (tester) async {
    Get.put(ReturnTopController(), tag: 'home');
    final compact = ValueNotifier(false);
    addTearDown(compact.dispose);
    await tester.pumpWidget(GetMaterialApp(
        home: ValueListenableBuilder<bool>(
      valueListenable: compact,
      builder: (_, value, __) => FeedNavigation(
          selectedId: null,
          compact: value,
          openFeed: (_) => false,
          child: const HomePage()),
    )));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    final page = find.byType(HomePage);
    final state = tester.state(page);
    final controller = Get.find<HomeFeedController>(tag: 'FEED');
    controller.publishItems([
      Datum(entityType: 'card', entityTemplate: 'titleCard', title: '首页推广标题'),
      for (var i = 0; i < 30; i++)
        Datum(
            id: i,
            entityType: 'feed',
            uid: 10,
            username: '合成作者',
            message: '合成内容 $i',
            dateline: 1793950000),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('首页推广标题').hitTestable(), findsOneWidget);
    compact.value = true;
    await tester.pumpAndSettle();
    expect(find.byTooltip('编辑主页分类'), findsNothing);
    expect(find.text('首页推广标题').hitTestable(), findsNothing);
    expect(tester.state(page), same(state));
    expect(Get.find<HomeFeedController>(tag: 'FEED'), same(controller));
    compact.value = false;
    await tester.pumpAndSettle();
    expect(find.byTooltip('编辑主页分类'), findsOneWidget);
    expect(find.text('首页推广标题').hitTestable(), findsOneWidget);
    expect(Get.find<HomeFeedController>(tag: 'FEED'), same(controller));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final article in [false, true]) {
    testWidgets(
        '${article ? "article" : "post"} keeps its reading state across widths',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      adapter.apiBody = {
        'data': {
          ...(adapter.webBody['data'] as Map<String, dynamic>),
          'feedTypeName': article ? '图文' : '动态',
          'message_title': article ? '合成文章标题' : '',
          'title': article ? '合成文章标题' : '',
          'message': List.filled(60, '合成帖子正文。').join('\n'),
          'message_raw_output': article
              ? jsonEncode([
                  for (var i = 0; i < 20; i++)
                    {'type': 'text', 'message': '第 $i 段合成正文。' * 20},
                ])
              : '[]',
        }
      };
      await tester.pumpWidget(GetMaterialApp(
          home: Row(children: [
        const SizedBox(width: 80),
        Expanded(
            child: AdaptiveReadingPane(
          leadingInset: 80,
          detailBuilder: (_, id, close) => FeedPage(id: id, onClose: close),
          child: Material(
              child: Builder(
                  builder: (context) => ListView(children: [
                        TextButton(
                            onPressed: () =>
                                FeedNavigation.open(context, '123'),
                            child: const Text('打开')),
                        const Text('保留的首页'),
                      ]))),
        )),
      ])));
      await tester.tap(find.text('打开'));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.text('本文作者'), findsOneWidget);
      expect(find.byTooltip('查看作者'), findsOneWidget);
      expect(find.byTooltip('评论排序'), findsOneWidget);
      if (article) expect(find.text('合成文章标题'), findsOneWidget);
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView).first)
          .controller!;
      scroll.jumpTo(240);
      await tester.pumpAndSettle();
      final requestCount = adapter.requests.length;
      await tester.tap(find.byTooltip('收起信息流'));
      await tester.pumpAndSettle();
      expect(find.text('本文作者').hitTestable(), findsNothing);
      expect(scroll.offset, 240);
      tester.view.physicalSize = const Size(420, 900);
      await tester.pumpAndSettle();
      expect(
          ReadingPresentation.of(
              tester.element(find.byType(CustomScrollView).first)),
          isFalse);
      expect(
          tester
              .widget<CustomScrollView>(find.byType(CustomScrollView).first)
              .controller,
          same(scroll));
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();
      expect(scroll.offset, 240);
      expect(adapter.requests.length, requestCount);
      expect(find.text('本文作者').hitTestable(), findsNothing);
      await tester.tap(find.byTooltip('显示信息流'));
      await tester.pumpAndSettle();
      expect(find.text('本文作者').hitTestable(), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('保留的首页').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
