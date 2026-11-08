import 'package:c001apk_flutter/components/app_keyboard_navigation.dart';
import 'package:c001apk_flutter/components/app_navigation_history.dart';
import 'package:c001apk_flutter/components/adaptive_reading_pane.dart';
import 'package:c001apk_flutter/components/feed_navigation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> side(WidgetTester tester, int buttons) async {
  final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: buttons);
  await mouse.down(const Offset(200, 200));
  await mouse.up();
  await tester.pumpAndSettle();
  await mouse.removePointer();
}

void main() {
  testWidgets('rapid forward waits until the old route has released its state',
      (tester) async {
    final key = GlobalKey<NavigatorState>();
    final history = AppNavigationHistory();
    var alive = 0;
    var overlapping = false;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [history],
      builder: (_, child) => AppKeyboardNavigation(
          navigatorKey: key, history: history, child: child!),
      routes: {
        '/article': (_) => _LifetimePage(
              onMount: () {
                alive++;
                if (alive > 1) overlapping = true;
              },
              onDispose: () => alive--,
            )
      },
      home: const Scaffold(body: Text('首页')),
    ));
    key.currentState!.pushNamed('/article');
    await tester.pumpAndSettle();
    key.currentState!.pop();
    await tester.pump(const Duration(milliseconds: 20));
    history.forward();
    await tester.pumpAndSettle();
    expect(find.text('有状态页面'), findsOneWidget);
    expect(overlapping, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'interacting with one restored article keeps later forward scroll snapshots',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final key = GlobalKey<NavigatorState>();
    final history = AppNavigationHistory();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [history],
      builder: (_, child) => AppKeyboardNavigation(
          navigatorKey: key, history: history, child: child!),
      routes: {
        '/reader': (_) => AdaptiveReadingPane(
              detailBuilder: (_, id, close) => Material(
                  child: ListView(key: ValueKey('saved-$id'), children: [
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 80, child: Text('文章 $id-$i')),
              ])),
              child: Material(
                  child: Builder(
                      builder: (context) => Column(children: [
                            for (var i = 0; i < 2; i++)
                              TextButton(
                                  onPressed: () =>
                                      FeedNavigation.open(context, '$i'),
                                  child: Text('帖子 $i')),
                          ]))),
            )
      },
      home: const Scaffold(body: Text('首页')),
    ));
    key.currentState!.pushNamed('/reader');
    await tester.pumpAndSettle();
    await tester.tap(find.text('帖子 0'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const ValueKey('saved-0')), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('帖子 1'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const ValueKey('saved-1')), const Offset(0, -800));
    await tester.pumpAndSettle();
    final before = tester
        .state<ScrollableState>(find
            .descendant(
                of: find.byKey(const ValueKey('saved-1')),
                matching: find.byType(Scrollable))
            .first)
        .position
        .pixels;
    for (var i = 0; i < 3; i++) {
      await side(tester, kBackMouseButton);
    }
    await side(tester, kForwardMouseButton);
    await side(tester, kForwardMouseButton);
    await tester.drag(
        find.byKey(const ValueKey('saved-0')), const Offset(0, -100));
    await tester.pumpAndSettle();
    await side(tester, kForwardMouseButton);
    expect(
        tester
            .state<ScrollableState>(find
                .descendant(
                    of: find.byKey(const ValueKey('saved-1')),
                    matching: find.byType(Scrollable))
                .first)
            .position
            .pixels,
        closeTo(before, 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('manual touch scrolling cancels delayed embedded restoration',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final count = ValueNotifier(60);
    addTearDown(count.dispose);
    final key = GlobalKey<NavigatorState>();
    final history = AppNavigationHistory();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [history],
      builder: (_, child) => AppKeyboardNavigation(
          navigatorKey: key, history: history, child: child!),
      routes: {
        '/reader': (_) => AdaptiveReadingPane(
              detailBuilder: (_, id, close) => Material(
                  child: ValueListenableBuilder<int>(
                valueListenable: count,
                builder: (_, n, __) => ListView.builder(
                    key: const ValueKey('delayed-article'),
                    itemCount: n,
                    itemBuilder: (_, i) =>
                        SizedBox(height: 80, child: Text('正文 $i'))),
              )),
              child: Material(
                  child: Builder(
                      builder: (context) => TextButton(
                          onPressed: () => FeedNavigation.open(context, '1'),
                          child: const Text('打开')))),
            )
      },
      home: const Scaffold(body: Text('首页')),
    ));
    key.currentState!.pushNamed('/reader');
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const ValueKey('delayed-article')), const Offset(0, -1500));
    await tester.pumpAndSettle();
    await side(tester, kBackMouseButton);
    await side(tester, kBackMouseButton);
    count.value = 14;
    await side(tester, kForwardMouseButton);
    await side(tester, kForwardMouseButton);
    await tester.drag(
        find.byKey(const ValueKey('delayed-article')), const Offset(0, 100));
    await tester.pumpAndSettle();
    final before =
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
    count.value = 60;
    await tester.pumpAndSettle();
    expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        closeTo(before, 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pending feed restoration cannot move a newly selected article',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final count = ValueNotifier(60);
    addTearDown(count.dispose);
    final key = GlobalKey<NavigatorState>();
    final history = AppNavigationHistory();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [history],
      builder: (_, child) => AppKeyboardNavigation(
          navigatorKey: key, history: history, child: child!),
      routes: {
        '/reader': (_) => AdaptiveReadingPane(
              detailBuilder: (_, id, close) => Material(
                  child: ListView(
                key: const ValueKey('new-article'),
                children: [
                  for (var i = 0; i < 60; i++)
                    SizedBox(height: 80, child: Text('文章 $i'))
                ],
              )),
              child: Material(
                  child: Builder(
                      builder: (context) => Column(children: [
                            TextButton(
                                onPressed: () =>
                                    FeedNavigation.open(context, '1'),
                                child: const Text('打开')),
                            Expanded(
                                child: ValueListenableBuilder<int>(
                                    valueListenable: count,
                                    builder: (_, n, __) => ListView.builder(
                                        key: const ValueKey('delayed-feed'),
                                        itemCount: n,
                                        itemBuilder: (_, i) => SizedBox(
                                            height: 80,
                                            child: Text('摘要 $i'))))),
                          ]))),
            )
      },
      home: const Scaffold(body: Text('首页')),
    ));
    key.currentState!.pushNamed('/reader');
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const ValueKey('delayed-feed')), const Offset(0, -1500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await side(tester, kBackMouseButton);
    await side(tester, kBackMouseButton);
    count.value = 14;
    await side(tester, kForwardMouseButton);
    await side(tester, kForwardMouseButton);
    count.value = 60;
    await tester.pumpAndSettle();
    expect(
        tester
            .state<ScrollableState>(find.descendant(
                of: find.byKey(const ValueKey('new-article')),
                matching: find.byType(Scrollable)))
            .position
            .pixels,
        0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('forward reaches saved positions beyond the first loaded page',
      (tester) async {
    final key = GlobalKey<NavigatorState>();
    final history = AppNavigationHistory();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [history],
      builder: (_, child) => AppKeyboardNavigation(
          navigatorKey: key, history: history, child: child!),
      routes: {'/paged': (_) => const _PagedArticles()},
      home: const Scaffold(body: Text('首页')),
    ));
    key.currentState!.pushNamed('/paged');
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -650));
      await tester.pumpAndSettle();
    }
    final before =
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
    expect(before, greaterThan(1000));
    await side(tester, kBackMouseButton);
    await side(tester, kForwardMouseButton);
    expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        closeTo(before, 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'account reset does not repopulate history during deferred route cleanup',
      (tester) async {
    final key = GlobalKey<NavigatorState>();
    final history = AppNavigationHistory();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [history],
      builder: (_, child) => AppKeyboardNavigation(
          navigatorKey: key, history: history, child: child!),
      routes: {'/private': (_) => const Scaffold(body: Text('旧账号内容'))},
      home: const Scaffold(body: Text('首页')),
    ));
    key.currentState!.pushNamed('/private');
    await tester.pumpAndSettle();
    history.clear();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => key.currentState!.popUntil((route) => route.isFirst));
    await tester.pumpAndSettle();
    await side(tester, kForwardMouseButton);
    expect(find.text('旧账号内容'), findsNothing);
    expect(find.text('首页'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'forward restores embedded reading after its owning route was disposed',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final key = GlobalKey<NavigatorState>();
    final history = AppNavigationHistory();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [history],
      builder: (_, child) => AppKeyboardNavigation(
          navigatorKey: key, history: history, child: child!),
      routes: {
        '/reader': (_) => AdaptiveReadingPane(
              detailBuilder: (_, id, close) =>
                  Material(child: ListView(children: [Text('阅读 $id')])),
              child: Material(
                  child: Builder(
                      builder: (context) => ListView(children: [
                            TextButton(
                                onPressed: () =>
                                    FeedNavigation.open(context, '1'),
                                child: const Text('帖子')),
                          ]))),
            )
      },
      home: const Scaffold(body: Text('首页')),
    ));
    key.currentState!.pushNamed('/reader');
    await tester.pumpAndSettle();
    await tester.tap(find.text('帖子'));
    await tester.pumpAndSettle();
    await side(tester, kBackMouseButton); // close article, retain local forward
    await side(tester, kBackMouseButton); // dispose reader route
    await side(tester, kForwardMouseButton); // recreate reader
    await side(tester, kForwardMouseButton); // restore local article
    expect(find.text('阅读 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('forward can traverse several recreated routes in order',
      (tester) async {
    final key = GlobalKey<NavigatorState>();
    final history = AppNavigationHistory();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [history],
      builder: (_, child) => AppKeyboardNavigation(
          navigatorKey: key, history: history, child: child!),
      routes: {
        '/a': (_) => const Scaffold(body: Text('文章 A')),
        '/b': (_) => const Scaffold(body: Text('文章 B'))
      },
      home: const Scaffold(body: Text('首页')),
    ));
    key.currentState!.pushNamed('/a');
    await tester.pumpAndSettle();
    key.currentState!.pushNamed('/b');
    await tester.pumpAndSettle();
    await side(tester, kBackMouseButton);
    await side(tester, kBackMouseButton);
    await side(tester, kForwardMouseButton);
    expect(find.text('文章 A'), findsOneWidget);
    await side(tester, kForwardMouseButton);
    expect(find.text('文章 B'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mouse back and forward restore a named route and its scroll',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final history = AppNavigationHistory();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [history],
      builder: (_, child) => AppKeyboardNavigation(
          navigatorKey: navigatorKey, history: history, child: child!),
      routes: {
        '/article': (_) => Scaffold(
                body: ListView(
              children: [
                for (var i = 0; i < 80; i++)
                  SizedBox(height: 80, child: Text('段落 $i'))
              ],
            ))
      },
      home: const Scaffold(body: Text('首页')),
    ));
    navigatorKey.currentState!.pushNamed('/article');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('段落 8')).dy;
    await side(tester, kBackMouseButton);
    expect(find.text('首页'), findsOneWidget);
    await side(tester, kForwardMouseButton);
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.getTopLeft(find.text('段落 8')).dy, closeTo(before, 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dialogs close first and a new route discards the forward branch',
      (tester) async {
    final key = GlobalKey<NavigatorState>();
    final history = AppNavigationHistory();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [history],
      builder: (_, child) => AppKeyboardNavigation(
          navigatorKey: key, history: history, child: child!),
      routes: {
        '/a': (_) => const Scaffold(body: Text('文章 A')),
        '/b': (_) => const Scaffold(body: Text('文章 B'))
      },
      home: const Scaffold(body: Text('首页')),
    ));
    key.currentState!.pushNamed('/a');
    await tester.pumpAndSettle();
    showDialog<void>(
        context: key.currentState!.overlay!.context,
        builder: (_) => const AlertDialog(title: Text('菜单')));
    await tester.pumpAndSettle();
    await side(tester, kBackMouseButton);
    expect(find.text('菜单'), findsNothing);
    expect(find.text('文章 A'), findsOneWidget);
    await side(tester, kBackMouseButton);
    key.currentState!.pushNamed('/b');
    await tester.pumpAndSettle();
    await side(tester, kForwardMouseButton);
    expect(find.text('文章 B'), findsOneWidget);
    expect(find.text('文章 A'), findsNothing);
    await side(tester, kBackMouseButton);
    history.clear();
    await side(tester, kForwardMouseButton);
    expect(find.text('首页'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'embedded reading goes back and forward without losing its scroll',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final key = GlobalKey<NavigatorState>();
    final history = AppNavigationHistory();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [history],
      builder: (_, child) => AppKeyboardNavigation(
          navigatorKey: key, history: history, child: child!),
      home: AdaptiveReadingPane(
        detailBuilder: (_, id, close) => Material(
            child: ListView(key: ValueKey('article-$id'), children: [
          for (var i = 0; i < 80; i++)
            SizedBox(height: 80, child: Text('阅读 $id-$i')),
        ])),
        child: Material(
            child: Builder(
                builder: (context) => ListView(children: [
                      for (var i = 0; i < 3; i++)
                        TextButton(
                            onPressed: () => FeedNavigation.open(context, '$i'),
                            child: Text('帖子 $i')),
                    ]))),
      ),
    ));
    await tester.tap(find.text('帖子 0'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const ValueKey('article-0')), const Offset(0, -420));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('阅读 0-8')).dy;
    await tester.tap(find.text('帖子 1'));
    await tester.pumpAndSettle();
    await side(tester, kBackMouseButton);
    expect(tester.getTopLeft(find.text('阅读 0-8')).dy, closeTo(before, 1));
    await side(tester, kForwardMouseButton);
    expect(find.text('阅读 1-0'), findsOneWidget);
    await side(tester, kBackMouseButton);
    await tester.tap(find.text('帖子 2'));
    await tester.pumpAndSettle();
    await side(tester, kForwardMouseButton);
    expect(find.text('阅读 2-0'), findsOneWidget);
    history.clear();
    await tester.pumpAndSettle();
    expect(find.text('阅读 2-0'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _PagedArticles extends StatefulWidget {
  const _PagedArticles();
  @override
  State<_PagedArticles> createState() => _PagedArticlesState();
}

class _LifetimePage extends StatefulWidget {
  const _LifetimePage({required this.onMount, required this.onDispose});
  final VoidCallback onMount;
  final VoidCallback onDispose;
  @override
  State<_LifetimePage> createState() => _LifetimePageState();
}

class _LifetimePageState extends State<_LifetimePage> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('有状态页面'));
}

class _PagedArticlesState extends State<_PagedArticles> {
  int count = 12;
  bool queued = false;
  @override
  Widget build(BuildContext context) => Scaffold(
          body: ListView.builder(
        itemCount: count,
        itemBuilder: (_, index) {
          if (index == count - 1 && count < 60 && !queued) {
            queued = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  count += 12;
                  queued = false;
                });
              }
            });
          }
          return SizedBox(height: 80, child: Text('分页文章 $index'));
        },
      ));
}
