import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:c001apk_flutter/logic/network/request.dart';
import 'package:c001apk_flutter/logic/accounts/account_store.dart';
import 'package:c001apk_flutter/pages/message/message_controller.dart';
import 'package:c001apk_flutter/pages/local_follow/local_follow_page.dart';
import 'package:c001apk_flutter/constants/constants.dart';
import 'package:c001apk_flutter/main.dart';
import 'package:c001apk_flutter/pages/settings/settings_page.dart';
import 'package:c001apk_flutter/components/settings/drop_down_menu_item.dart';
import 'package:c001apk_flutter/components/cards/feed_card.dart';
import 'package:c001apk_flutter/components/cards/carousel_card.dart';
import 'package:c001apk_flutter/components/cards/icon_link_grid_card.dart';
import 'package:c001apk_flutter/components/cards/icon_mini_scroll_card.dart';
import 'package:c001apk_flutter/pages/home/feed/home_feed_page.dart';
import 'package:c001apk_flutter/pages/feed/feed_page.dart';
import 'package:c001apk_flutter/logic/model/feed/datum.dart';
import 'package:c001apk_flutter/utils/global_data.dart';
import 'package:c001apk_flutter/utils/storage_util.dart';
import 'package:c001apk_flutter/utils/utils.dart';
import 'package:dio/dio.dart';
import 'package:dynamic_color/samples.dart';
import 'package:dynamic_color/test_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

class EmptyGuestAdapter implements HttpClientAdapter {
  bool showHomeCards = false;
  bool showInbox = false;
  final notificationPages = <int>[];
  bool showFeed = false;
  bool showUser = false;
  bool accountDetail = false;
  bool appOnlyPublic = false;
  final detailIds = <String>[];
  final followRequests = <Map<String, dynamic>>[];
  Completer<void>? topicGate;
  static const feed = {
    'id': 123,
    'entityType': 'feed',
    'feedTypeName': '动态',
    'uid': 10,
    'dateline': 1760000000,
    'userInfo': {'uid': 10, 'username': '合成作者'},
    'message': '可正常阅读的合成正文',
    'message_raw_output': '[]',
    'likenum': 0,
    'replynum': 0,
  };
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (showUser &&
        ['/v6/user/space', '/v6/user/feedList'].contains(options.uri.path)) {
      return ResponseBody.fromString(
          jsonEncode({
            'data': options.uri.path == '/v6/user/space'
                ? {
                    'uid': 10,
                    'username': '合成用户',
                    'cover': '',
                    'userAvatar': '',
                    'logintime': 1760000000,
                    'level': 1,
                    'feed': 12,
                    'beLikeNum': 0,
                    'fans': 0,
                    'follow': 0
                  }
                : options.queryParameters['page'] == 1
                    ? [
                        for (var i = 0; i < 12; i++)
                          {...feed, 'entityId': 'user-feed-$i', 'id': 200 + i}
                      ]
                    : []
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json']
          });
    }
    if (showHomeCards && options.uri.path == '/v6/main/indexV8') {
      return ResponseBody.fromString(
        jsonEncode({
          'data': options.queryParameters['page'] == 1
              ? [
                  for (final template in [
                    'imageCarouselCard_1',
                    'iconLinkGridCard',
                    'iconMiniScrollCard',
                  ])
                    {
                      'entityId': template,
                      'entityType': 'card',
                      'entityTemplate': template,
                      'entities': [
                        for (var i = 0; i < 10; i++)
                          {
                            'title': '合成入口$i',
                            'url': '/feed/${100 + i}',
                            'pic': ''
                          },
                      ],
                    },
                  for (var i = 0; i < 12; i++)
                    {...feed, 'entityId': 'feed-$i', 'id': 200 + i},
                ]
              : [],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    if (showInbox) {
      Object? data;
      switch (options.uri.path) {
        case '/v6/notification/checkCount':
          data = {'message': 2, 'notification': 3};
        case '/v6/notification/list':
          final page = options.queryParameters['page'] as int;
          notificationPages.add(page);
          data = page <= 2
              ? [
                  {
                    'id': page,
                    'entityType': 'notification',
                    'fromusername': '酷安小秘书',
                    'note': '合成系统信息$page',
                    'dateline': 1760000000,
                  }
                ]
              : [];
        case '/v6/message/list':
          data = options.queryParameters['page'] == 1
              ? [
                  {
                    'id': 20,
                    'entityType': 'message',
                    'messageUid': 10,
                    'messageUsername': '合成联系人',
                    'message': '合成私信预览',
                    'ukey': 'synthetic-conversation',
                    'dateline': 1760000000,
                  }
                ]
              : [];
      }
      if (data != null) {
        return ResponseBody.fromString(jsonEncode({'data': data}), 200,
            headers: {
              Headers.contentTypeHeader: ['application/json']
            });
      }
    }
    if (options.uri.path == '/v6/feed/detail') {
      detailIds.add(options.queryParameters['id'].toString());
    }
    final url = options.queryParameters['url']?.toString() ?? '';
    if (url.contains('V9_HOME_TAB_FOLLOW')) {
      followRequests.add(Map.of(options.queryParameters));
      if (url.endsWith('type=topic')) await topicGate?.future;
      return ResponseBody.fromString(
        jsonEncode({
          'data': options.queryParameters['page'] == 1
              ? [
                  {
                    ...feed,
                    'message': url.endsWith('type=topic') ? '合成话题内容' : '合成用户内容'
                  },
                ]
              : []
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    if (showFeed &&
        (options.uri.path == '/v6/feed/detail' ||
            options.uri.path == '/feed/123')) {
      if (appOnlyPublic && options.uri.path == '/feed/123') {
        return ResponseBody.fromString(
            '<html><title>动态分享 - 酷安</title>'
            '<div>请用酷安手机APP扫码查看详情</div></html>',
            200,
            headers: {
              Headers.contentTypeHeader: ['text/html']
            });
      }
      return ResponseBody.fromString(
        jsonEncode(options.uri.path == '/feed/123' || accountDetail
            ? {
                'data': {
                  ...feed,
                  if (accountDetail) 'userAction': {'like': 1},
                }
              }
            : {'code': 403, 'messageStatus': 'err_request_captcha_v2'}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return ResponseBody.fromString(
        options.uri.path == '/v6/account/checkLoginInfo'
            ? '{"data":null}'
            : '{"data":[]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  Future<void> finishIo(
      WidgetTester tester, Future<void> Function() action) async {
    var finished = false;
    Object? error;
    await tester.runAsync(() async {
      action().then((_) => finished = true, onError: (Object e) {
        error = e;
        finished = true;
      });
    });
    for (var i = 0; i < 100 && !finished; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    if (error != null) throw error!;
    expect(finished, isTrue, reason: 'Local storage operation did not finish');
  }

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('c001apk-locale-');
    Hive.init(temp.path);
    GStorage.settings = await Hive.openBox('settings');
    GStorage.blackList = await Hive.openBox('blackList');
    GStorage.favFeed = await Hive.openBox('favFeed');
    GStorage.historyFeed = await Hive.openBox('historyFeed');
    GStorage.searchHistory = await Hive.openBox('searchHistory');
    await GStorage.settings.putAll({
      SettingsBoxKey.xAppDevice: 'synthetic-test-device',
      SettingsBoxKey.userAgent: 'SyntheticTest/1.0',
      SettingsBoxKey.versionName: '16.2.0',
      SettingsBoxKey.versionCode: '2604201',
      SettingsBoxKey.apiVersion: '16',
      SettingsBoxKey.sdkInt: '33',
    });
    GlobalData().isLogin = false;
    Request();
    Request.dio.httpClientAdapter = EmptyGuestAdapter();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/package_info'),
            (_) async => {
                  'appName': 'c001apk',
                  'packageName': 'synthetic.test',
                  'version': '1.0.0',
                  'buildNumber': '1',
                });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => temp.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/shared_preferences'),
            (call) async =>
                call.method == 'getAll' ? <String, Object>{} : true);
  });

  tearDown(() async {
    Get.reset();
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    for (final surface in ['tabs', 'carousel', 'grid', 'chips']) {
      testWidgets('home $surface accepts ${kind.name} dragging',
          (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Request.dio.httpClientAdapter = EmptyGuestAdapter()
          ..showHomeCards = true;
        await tester.pumpWidget(const C001APKAPP());
        await tester.pumpAndSettle();
        final tabs = find.byType(TabBar).first;
        final homeTabs = tester.widget<TabBar>(tabs).controller!;
        final target = switch (surface) {
          'tabs' => tabs,
          'carousel' => find.byType(CarouselCard),
          'grid' => find.byType(IconLinkGridCard),
          _ => find.byType(IconMiniScrollCard),
        };
        final scrollable = find
            .descendant(
              of: target,
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        final before = position.pixels;
        final initialTab = homeTabs.index;
        await tester.drag(target, const Offset(-260, 0), kind: kind);
        await tester.pumpAndSettle();
        expect(position.pixels, greaterThan(before + 30));
        expect(homeTabs.index, initialTab,
            reason: 'Dragging a nested control must not switch the home page');
        expect(Get.currentRoute, '/', reason: 'Dragging must not open an item');
        await tester.drag(target, const Offset(260, 0), kind: kind);
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(before, 2));
        await tester.tap(find.widgetWithText(Tab, '热门'));
        await tester.pumpAndSettle();
        expect(homeTabs.index, initialTab + 1);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('home preserves mouse wheel scrolling and entry clicks',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Request.dio.httpClientAdapter = EmptyGuestAdapter()..showHomeCards = true;
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    final list = find
        .descendant(
          of: find.byType(HomeFeedPage).first,
          matching: find.byWidgetPredicate((widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down),
        )
        .first;
    final position = tester.state<ScrollableState>(list).position;
    final location = tester.getCenter(list);
    await tester.drag(list, const Offset(0, -120),
        kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(position.pixels, 0,
        reason: 'Mouse dragging is scoped to the horizontal controls');
    await tester.sendEventToBinding(PointerScrollEvent(
      position: location,
      scrollDelta: const Offset(0, 100),
      kind: PointerDeviceKind.mouse,
    ));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(IconMiniScrollCard),
        matching: find.text('合成入口0'),
      ),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(Get.parameters['id'], '100');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keyboard Escape asks before exiting all three main destinations',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var closeCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'), (call) async {
      if (call.method == 'close') closeCalls++;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null));
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    for (final destination in ['主页', '关注', '我的']) {
      await tester.tap(find.widgetWithText(NavigationDestination, destination));
      await tester.pumpAndSettle();
      final selected = tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .selectedIndex;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('退出 c001apk？'), findsOneWidget);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      expect(closeCalls, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          selected);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(closeCalls, 0);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();
    expect(closeCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keyboard Escape returns one level and respects pop guards',
      (tester) async {
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    Get.to(() => const SettingsPage());
    await tester.pumpAndSettle();
    Get.to(() => const SettingsDetailPage(section: SettingsSection.appearance));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsDetailPage), findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    Get.to(() => const PopScope(
          canPop: false,
          child: Scaffold(body: Text('受保护页面')),
        ));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('受保护页面'), findsOneWidget);
    Get.back();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.text('主页'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'keyboard arrows scroll the active page without moving text input',
      (tester) async {
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Request.dio.httpClientAdapter = EmptyGuestAdapter()..showHomeCards = true;
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    final homeList = find
        .descendant(
          of: find.byType(HomeFeedPage).first,
          matching: find.byWidgetPredicate((widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down),
        )
        .first;
    final homePosition = tester.state<ScrollableState>(homeList).position;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(homePosition.pixels, greaterThan(0));
    final firstStep = homePosition.pixels;
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(homePosition.pixels, greaterThan(firstStep));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(homePosition.pixels, closeTo(0, 1));
    await tester.tap(find.widgetWithText(Tab, '热门'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(homePosition.pixels, closeTo(0, 1),
        reason: 'An inactive home tab must not scroll');
    await tester.tap(find.widgetWithText(Tab, '动态'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '我的'));
    await tester.pumpAndSettle();
    final myList = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    final myPosition = tester.state<ScrollableState>(myList).position;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(myPosition.pixels, greaterThan(0));
    expect(homePosition.pixels, closeTo(0, 1));
    await tester.tap(find.widgetWithText(NavigationDestination, '主页'));
    await tester.pumpAndSettle();
    final controller = ScrollController();
    final editor = TextEditingController(text: '第一行\n第二行');
    Get.to(() => Scaffold(
          appBar: AppBar(title: const Text('合成键盘页面')),
          body: ListView(
            controller: controller,
            children: [
              TextField(controller: editor, maxLines: 3),
              for (var i = 0; i < 30; i++) ListTile(title: Text('合成条目$i')),
            ],
          ),
        ));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(homePosition.pixels, closeTo(0, 1),
        reason: 'A covered route must not receive keyboard scrolling');
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    editor.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(editor.selection.baseOffset, greaterThan(0));
    expect(controller.offset, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    editor.dispose();
  });

  testWidgets('keyboard arrows follow visual direction in reversed lists',
      (tester) async {
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    final controller = ScrollController();
    Get.to(() => Scaffold(
          body: ListView.builder(
            controller: controller,
            reverse: true,
            itemCount: 50,
            itemBuilder: (_, index) => ListTile(title: Text('合成消息$index')),
          ),
        ));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, 1));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('real app uses Simplified Chinese system controls and navigation',
      (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const C001APKAPP());
    await tester.pump(const Duration(milliseconds: 500));
    final context = tester.element(find.byType(NavigationBar));
    expect(Localizations.localeOf(context), const Locale('zh', 'CN'));
    final material = MaterialLocalizations.of(context);
    expect(material.backButtonTooltip, '返回');
    expect(material.copyButtonLabel, '复制');
    expect(material.pasteButtonLabel, '粘贴');
    expect(find.text('主页'), findsOneWidget);
    expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .destinations
            .cast<NavigationDestination>()
            .map((item) => item.label),
        ['主页', '关注', '我的']);
    expect(find.widgetWithText(Tab, '关注'), findsNothing);
    await tester.tap(find.widgetWithText(NavigationDestination, '关注'));
    await tester.pumpAndSettle();
    expect(find.text('本地关注动态'), findsOneWidget);
    expect(find.textContaining('还没有本地关注的用户'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    tester.view.physicalSize = const Size(1400, 900);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('主页'), findsOneWidget);
    expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        1);
    expect(find.text('本地关注动态'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.person_outline)));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        2);
    expect(find.text('点击登录'), findsOneWidget);
    expect(find.text('粉丝', skipOffstage: false), findsNothing);
    final localCard = find
        .ancestor(of: find.text('本地收藏'), matching: find.byType(Material))
        .last;
    final divider = find.byType(Divider).first;
    expect(tester.getTopLeft(localCard).dy - tester.getBottomLeft(divider).dy,
        lessThan(20));
    expect(find.text('Settings'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('main destinations are peers when handling system back',
      (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    for (final destination in ['主页', '关注', '我的']) {
      await tester.tap(find.widgetWithText(NavigationDestination, destination));
      await tester.pumpAndSettle();
      final selected = tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .selectedIndex;
      final route = ModalRoute.of(tester.element(find.byType(NavigationBar)))!;
      expect(route.popDisposition, RoutePopDisposition.bubble);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          selected);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('direct settings routes keep the official opaque back preview',
      (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    Get.to(() => const SettingsDetailPage(section: SettingsSection.appearance));
    await tester.pumpAndSettle();
    Future<void> event(String method, double progress) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/backgesture',
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, {
          'touchOffset': <double>[
            tester.view.physicalSize.width * progress,
            300,
          ],
          'progress': progress,
          'swipeEdge': 0,
        })),
        (_) {},
      );
      await tester.pump();
    }

    await event('startBackGesture', 0);
    await event('updateBackGestureProgress', 0.5);
    final fades = tester.widgetList<FadeTransition>(find.ancestor(
      of: find.byType(SettingsDetailPage),
      matching: find.byType(FadeTransition),
    ));
    expect(
        fades.fold<double>(1, (value, fade) => value * fade.opacity.value), 1);
    final opacities = tester.widgetList<Opacity>(find.ancestor(
        of: find.byType(SettingsDetailPage), matching: find.byType(Opacity)));
    expect(opacities.every((opacity) => opacity.opacity == 1), isTrue);
    expect(
        tester.getRect(find.byType(SettingsDetailPage)).width, lessThan(500));
    await event('commitBackGesture', 0.5);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsDetailPage), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('system dynamic palette reaches the actual app theme',
      (tester) async {
    DynamicColorTestingUtils.setMockDynamicColors(
        corePalette: SampleCorePalettes.green);
    await tester.runAsync(() => GStorage.settings.putAll({
          SettingsBoxKey.useMaterial: true,
          SettingsBoxKey.selectedTheme: 1,
        }));
    await tester.pumpWidget(const C001APKAPP());
    await tester.pump(const Duration(milliseconds: 500));
    final context = tester.element(find.byType(Scaffold).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(Theme.of(context).colorScheme.primary, const Color(0xff286c2a));
    await tester.runAsync(
        () => GStorage.settings.put(SettingsBoxKey.useMaterial, false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(Theme.of(context).colorScheme.primary, const Color(0xff64558f));
    await tester.runAsync(
        () => GStorage.settings.put(SettingsBoxKey.useMaterial, true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(Theme.of(context).colorScheme.primary, const Color(0xff286c2a));
    await tester
        .runAsync(() => GStorage.settings.put(SettingsBoxKey.selectedTheme, 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(Theme.of(context).brightness, Brightness.dark);
    await tester.pumpWidget(const SizedBox.shrink());
    DynamicColorTestingUtils.setMockDynamicColors();
  });

  testWidgets(
      'system messages are reached through the inbox alongside private chats',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final adapter = EmptyGuestAdapter()..showInbox = true;
    Request.dio.httpClientAdapter = adapter;
    await tester.runAsync(() => AccountStore().saveLogin(
        uid: '321', username: 'synthetic', token: 'synthetic-token'));
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '我的'));
    await tester.pumpAndSettle();
    expect(find.textContaining('合成系统信息', findRichText: true), findsNothing);
    expect(adapter.notificationPages, isEmpty);
    await tester.ensureVisible(find.text('私信与信息'));
    await tester.tap(find.text('私信与信息'));
    await tester.pumpAndSettle();
    expect(find.text('酷安小秘书'), findsOneWidget);
    expect(find.widgetWithText(Badge, '3'), findsOneWidget);
    expect(find.text('合成联系人'), findsOneWidget);
    await tester.tap(find.text('合成联系人'));
    await tester.pumpAndSettle();
    expect(Get.parameters['ukey'], 'synthetic-conversation');
    Get.back();
    await tester.pumpAndSettle();
    await tester.tap(find.text('酷安小秘书'));
    await tester.pumpAndSettle();
    expect(find.text('合成系统信息1', findRichText: true), findsOneWidget);
    expect(find.text('合成系统信息2', findRichText: true), findsOneWidget);
    expect(adapter.notificationPages, containsAllInOrder([1, 2]));
    Get.back();
    await tester.pumpAndSettle();
    expect(find.text('合成联系人'), findsOneWidget);
    Get.back();
    await tester.pumpAndSettle();
    await tester.tap(find.text('私信与信息'));
    await tester.pumpAndSettle();
    expect(find.text('酷安小秘书'), findsOneWidget);
    expect(find.widgetWithText(Badge, '3'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await finishIo(tester, () => AccountStore().useGuest());
  });

  testWidgets('guest inbox keeps c001apk assistant reachable without account notices',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final adapter = EmptyGuestAdapter();
    Request.dio.httpClientAdapter = adapter;
    await tester.runAsync(() => AccountStore().useGuest());
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '我的'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('私信与信息'));
    await tester.tap(find.text('私信与信息'));
    await tester.pumpAndSettle();
    expect(find.text('c001apk 小助手'), findsOneWidget);
    expect(find.text('登录后查看私信与酷安通知'), findsOneWidget);
    expect(find.text('酷安小秘书'), findsNothing);
    expect(adapter.notificationPages, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'dynamic color disables the entire color picker and restores its selection',
      (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => GStorage.settings.putAll({
          SettingsBoxKey.useMaterial: true,
          SettingsBoxKey.staticColor: 4,
        }));
    await tester.pumpWidget(const C001APKAPP());
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(NavigationDestination, '我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('外观与字号'));
    await tester.pumpAndSettle();
    final picker = find.byWidgetPredicate((widget) =>
        widget is DropDownMenuItem &&
        widget.boxKey == SettingsBoxKey.staticColor);
    final button =
        find.descendant(of: picker, matching: find.byType(DropdownButton<int>));
    final tile = find.descendant(of: picker, matching: find.byType(ListTile));
    expect(find.text('主题颜色'), findsOneWidget);
    expect(tester.widget<DropdownButton<int>>(button).onChanged, isNull);
    expect(tester.widget<ListTile>(tile).enabled, isFalse);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text(Constants.themeType[0]), findsNothing);
    expect(GStorage.staticColor, 4);

    await tester.runAsync(
        () => GStorage.settings.put(SettingsBoxKey.useMaterial, false));
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<int>>(button).onChanged, isNotNull);
    expect(tester.widget<ListTile>(tile).enabled, isTrue);
    expect(tester.widget<DropdownButton<int>>(button).value, 4);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(Constants.themeType[0]), -120,
        scrollable: find.byType(Scrollable).last);
    expect(find.text(Constants.themeType[0]), findsOneWidget);
    expect(
        tester
            .widget<DropdownButton<int>>(button)
            .items!
            .every((item) => item.enabled),
        isTrue);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(GStorage.staticColor, 4);

    await tester.runAsync(
        () => GStorage.settings.put(SettingsBoxKey.useMaterial, true));
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<int>>(button).onChanged, isNull);
    expect(tester.widget<DropdownButton<int>>(button).value, 4);
    await tester.pumpWidget(const SizedBox.shrink());
    // Let the settings page's cache manager finish its scheduled cleanup.
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets(
      'wide home loads the selected feed beside the original list and Esc closes it',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final adapter = EmptyGuestAdapter()
      ..showHomeCards = true
      ..showFeed = true;
    Request.dio.httpClientAdapter = adapter;
    GlobalData().isLogin = false;
    await tester.runAsync(() => GStorage.settings.putAll({
          SettingsBoxKey.recordHistory: false,
          SettingsBoxKey.readingMode: 0,
        }));
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    final card = find.byType(FeedCard).first;
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    final firstPosition = tester.getTopLeft(find.byType(FeedCard).at(0));
    final fourthPosition = tester.getTopLeft(find.byType(FeedCard).at(3));
    expect(fourthPosition.dy, firstPosition.dy);
    expect(fourthPosition.dx, greaterThan(firstPosition.dx));
    final id = tester.widget<FeedCard>(card).data.id.toString();
    await tester.tap(find.descendant(
        of: card, matching: find.text('可正常阅读的合成正文', findRichText: true)));
    await tester.pumpAndSettle();
    expect(tester.widget<FeedPage>(find.byType(FeedPage)).id, id);
    expect(adapter.detailIds, [id]);
    final detailLeft = tester.getTopLeft(find.byType(FeedPage)).dx;
    final listLeft = tester.getTopLeft(find.byType(HomeFeedPage).first).dx;
    expect(detailLeft, lessThan(listLeft));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FeedPage), findsNothing);
    expect(find.text('退出 c001apk？'), findsNothing);
    expect(Get.currentRoute, '/');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'wide navigation remains usable beside a landscape display cutout',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(left: 77);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    Request.dio.httpClientAdapter = EmptyGuestAdapter();
    GlobalData().isLogin = false;
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    final rail = find.byType(NavigationRail);
    final bounds = tester.getRect(rail);
    final home = tester
        .getRect(find.descendant(of: rail, matching: find.byIcon(Icons.home)));
    expect(home.left, greaterThanOrEqualTo(bounds.left));
    expect(home.right, lessThanOrEqualTo(bounds.right));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wide user feed uses multiple columns below its profile header',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Request.dio.httpClientAdapter = EmptyGuestAdapter()..showUser = true;
    GlobalData().isLogin = false;
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    Get.toNamed('/u/10');
    await tester.pumpAndSettle();
    expect(find.text('合成用户'), findsWidgets);
    final cards = find.byType(FeedCard);
    expect(
        tester.getTopLeft(cards.at(0)).dy, tester.getTopLeft(cards.at(3)).dy);
    expect(tester.getTopLeft(cards.at(3)).dx,
        greaterThan(tester.getTopLeft(cards.at(0)).dx));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('guest access error opens identity help and retries after import',
      (tester) async {
    final adapter = EmptyGuestAdapter()
      ..showFeed = true
      ..appOnlyPublic = true;
    Request.dio.httpClientAdapter = adapter;
    GlobalData().isLogin = false;
    await tester.runAsync(
        () => GStorage.settings.put(SettingsBoxKey.recordHistory, false));
    await tester.pumpWidget(const C001APKAPP());
    await tester.pump(const Duration(milliseconds: 500));
    Get.toNamed('/feed/123');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('设备需要验证'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '重试'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '设备标识设置'));
    await tester.pumpAndSettle();
    expect(find.text('减少重复人机验证'), findsOneWidget);
    expect(GlobalData().isLogin, isFalse);
    adapter.accountDetail = true;
    await tester.runAsync(() => GStorage.settings
        .put(SettingsBoxKey.xAppDevice, 'updated-synthetic-device'));
    Get.back();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('可正常阅读的合成正文', findRichText: true), findsOneWidget);
    expect(GlobalData().isLogin, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => GStorage.settings
        .put(SettingsBoxKey.xAppDevice, 'synthetic-test-device'));
  });

  testWidgets(
      'public detail explains account status on demand and clears it on success',
      (tester) async {
    final adapter = EmptyGuestAdapter()..showFeed = true;
    Request.dio.httpClientAdapter = adapter;
    GlobalData().isLogin = true;
    await tester.runAsync(
        () => GStorage.settings.put(SettingsBoxKey.recordHistory, false));
    await tester.pumpWidget(const C001APKAPP());
    await tester.pump(const Duration(milliseconds: 500));
    Get.toNamed('/feed/123');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('可正常阅读的合成正文', findRichText: true), findsOneWidget);
    expect(find.textContaining('正在显示公开正文'), findsNothing);
    expect(find.byTooltip('账号信息暂不可用'), findsOneWidget);
    await tester.tap(find.byTooltip('账号信息暂不可用'));
    await tester.pumpAndSettle();
    expect(find.textContaining('点赞状态暂不可用'), findsOneWidget);
    adapter.accountDetail = true;
    await tester.tap(find.text('重试账号详情'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byTooltip('账号信息暂不可用'), findsNothing);
    expect(find.text('可正常阅读的合成正文', findRichText: true), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox.shrink());
    GlobalData().isLogin = false;
  });

  testWidgets('quoted feed card opens the numeric feed from a shared URL',
      (tester) async {
    final adapter = EmptyGuestAdapter()
      ..showFeed = true
      ..accountDetail = true;
    Request.dio.httpClientAdapter = adapter;
    GlobalData().isLogin = false;
    await tester.runAsync(
        () => GStorage.settings.put(SettingsBoxKey.recordHistory, false));
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    Get.to(() => Scaffold(
          body: FeedCard(
            isFeedContent: true,
            data: Datum.fromJson({
              ...EmptyGuestAdapter.feed,
              'id': 456,
              'message': '引用了另一条动态',
              'extra_title': '@合成作者的动态',
              'extra_url': 'https://www.coolapk.com/feed/123?s=synthetic-share',
            }),
          ),
        ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('@合成作者的动态'));
    await tester.pumpAndSettle();
    expect(Get.parameters['id'], '123');
    expect(adapter.detailIds, ['123']);
    expect(find.text('动态编号无效'), findsNothing);
    expect(find.text('可正常阅读的合成正文', findRichText: true), findsOneWidget);
    Get.back();
    await tester.pumpAndSettle();
    expect(find.text('引用了另一条动态', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('feed links exclude query parameters and fragments from the ID',
      (tester) async {
    final adapter = EmptyGuestAdapter()
      ..showFeed = true
      ..accountDetail = true;
    Request.dio.httpClientAdapter = adapter;
    GlobalData().isLogin = false;
    await tester.runAsync(
        () => GStorage.settings.put(SettingsBoxKey.recordHistory, false));
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    for (final url in [
      '/feed/123',
      '/feed/123?s=synthetic&from=share#reply',
      '/feed/123#reply',
      'https://www.coolapk.com/feed/123',
      'https://www.coolapk.com/feed/123?s=synthetic&from=share#reply',
      'coolmarket://feed/123?s=synthetic#reply',
    ]) {
      adapter.detailIds.clear();
      Utils.onOpenLink(url);
      await tester.pumpAndSettle();
      expect(Get.parameters['id'], '123', reason: url);
      expect(adapter.detailIds, ['123'], reason: url);
      expect(find.text('可正常阅读的合成正文', findRichText: true), findsOneWidget);
      Get.back();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('switching accounts rebuilds mounted pages and closes old routes',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => AccountStore().saveLogin(
        uid: '321',
        username: 'synthetic-current',
        token: 'synthetic-current-token'));
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '关注'));
    await tester.pumpAndSettle();
    expect(find.text('用户关注'), findsOneWidget);
    await tester.tap(find.byTooltip('切换关注内容'));
    await tester.pumpAndSettle();
    await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<FollowFeedSelection>, '悄悄关注'));
    await tester.pumpAndSettle();
    await finishIo(tester, () => GStorage.settings.flush());
    await tester.pumpAndSettle();
    expect(find.text('悄悄关注动态'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, '我的'));
    await tester.pumpAndSettle();
    final oldController = Get.find<MessageController>();
    oldController.firstList.value = [7, 8, 9];
    await tester.pump();
    expect(find.text('粉丝'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.byTooltip('账号管理'), findsOneWidget);
    await tester.tap(find.byTooltip('账号管理'));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, '/accounts');
    await tester.runAsync(() async {
      await tester.tap(find.text('使用游客模式'));
    });
    await finishIo(tester, () => GStorage.settings.flush());
    for (var attempt = 0;
        attempt < 200 && (GlobalData().isLogin || Get.currentRoute != '/');
        attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    await tester.pumpAndSettle();
    expect(Get.currentRoute, '/');
    expect(GlobalData().isLogin, isFalse);
    expect(oldController.isClosed, isTrue);
    expect(identical(oldController, Get.find<MessageController>()), isFalse);
    expect(find.text('点击登录'), findsOneWidget);
    await finishIo(tester, () => AccountStore().switchTo('321'));
    await tester.pumpAndSettle();
    expect(GlobalData().uid, '321');
    expect(GlobalData().isLogin, isTrue);
    expect(find.text('点击登录'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await finishIo(tester, () => AccountStore().useGuest());
  });

  testWidgets(
      'follow menu defaults to users and routes each category separately',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final adapter = EmptyGuestAdapter();
    Request.dio.httpClientAdapter = adapter;
    await tester.runAsync(() async {
      await GStorage.settings.delete('followFeedSelectionV1');
      await GStorage.settings.put(SettingsBoxKey.followType, 0);
      await AccountStore().saveLogin(
          uid: '321', username: 'synthetic', token: 'synthetic-token');
    });
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '关注'));
    await tester.pumpAndSettle();
    expect(adapter.followRequests.first['url'],
        '/page?url=V9_HOME_TAB_FOLLOW&type=circle');
    expect(find.text('合成用户内容', findRichText: true), findsOneWidget);
    expect(
        adapter.followRequests.any((request) => request['page'] == 2), isTrue);
    for (final entry in {
      '话题关注': '&type=topic',
      '数码关注': '&type=product',
      '应用关注': '&type=apk',
      '全部关注': '',
      '用户关注': '&type=circle',
    }.entries) {
      await tester.tap(find.byTooltip('切换关注内容'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(
          CheckedPopupMenuItem<FollowFeedSelection>, entry.key));
      await tester.pumpAndSettle();
      await finishIo(tester, () => GStorage.settings.flush());
      await tester.pumpAndSettle();
      final first = adapter.followRequests.lastWhere((r) => r['page'] == 1);
      expect(first['url'], '/page?url=V9_HOME_TAB_FOLLOW${entry.value}');
      expect(first.containsKey('firstItem'), isFalse);
      expect(first.containsKey('lastItem'), isFalse);
      expect(find.text(entry.key), findsOneWidget);
    }
    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.byTooltip('切换关注内容'));
    await tester.pumpAndSettle();
    await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<FollowFeedSelection>, '话题关注'));
    await tester.pumpAndSettle();
    await finishIo(tester, () => GStorage.settings.flush());
    expect(find.text('合成话题内容', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await finishIo(tester, () => AccountStore().useGuest());
  });

  testWidgets(
      'switching follow categories ignores late responses and remembers source',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gate = Completer<void>();
    final adapter = EmptyGuestAdapter()..topicGate = gate;
    Request.dio.httpClientAdapter = adapter;
    await tester.runAsync(() async {
      await GStorage.settings.delete('followFeedSelectionV1');
      await AccountStore().saveLogin(
          uid: '321', username: 'synthetic', token: 'synthetic-token');
    });
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '关注'));
    await tester.pumpAndSettle();
    Future<void> select(String label, {bool settle = true}) async {
      await tester.tap(find.byTooltip('切换关注内容'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithText(
          CheckedPopupMenuItem<FollowFeedSelection>, label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await finishIo(tester, () => GStorage.settings.flush());
      if (settle) await tester.pumpAndSettle();
    }

    await select('话题关注', settle: false);
    expect(adapter.followRequests.last['url'],
        '/page?url=V9_HOME_TAB_FOLLOW&type=topic');
    await select('用户关注');
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('合成话题内容', findRichText: true), findsNothing);
    expect(find.text('合成用户内容', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
    await select('悄悄关注');
    await tester.pumpWidget(const SizedBox.shrink());
    Get.reset();
    await tester.pumpWidget(const C001APKAPP());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '关注'));
    await tester.pumpAndSettle();
    expect(find.text('悄悄关注动态'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await finishIo(tester, () async {
      await GStorage.settings.delete('followFeedSelectionV1');
      await AccountStore().useGuest();
    });
  });
}
