import 'dart:async';
import 'dart:io';

import 'package:c001apk_flutter/components/device_identity_action.dart';
import 'package:c001apk_flutter/logic/content_filter/content_filter_rule.dart';
import 'package:c001apk_flutter/logic/content_filter/content_filter_service.dart';
import 'package:c001apk_flutter/logic/onboarding/onboarding_state.dart';
import 'package:c001apk_flutter/logic/szlm_identity_service.dart';
import 'package:c001apk_flutter/pages/onboarding/onboarding_page.dart';
import 'package:c001apk_flutter/utils/storage_util.dart';
import 'package:c001apk_flutter/utils/szlm_duid_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _OfflineRules implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString('offline', 404);
  @override
  void close({bool force = false}) {}
}

class _IdentityService extends ChangeNotifier implements SzlmIdentityService {
  int calls = 0;
  Completer<String>? pending;
  @override
  bool isFetching = false;
  @override
  DateTime? nextAllowedAt;
  @override
  String? unavailableReason;

  @override
  Future<String> renewNow() async {
    calls++;
    isFetching = true;
    notifyListeners();
    try {
      return await pending!.future;
    } finally {
      isFetching = false;
      notifyListeners();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late Box<dynamic> filterBox;
  late ContentFilterService filter;
  late OnboardingState state;
  late _IdentityService identity;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('onboarding-ui-');
    Hive.init(directory.path);
    GStorage.settings = await Hive.openBox<dynamic>('settings');
    filterBox = await Hive.openBox<dynamic>('filter');
  });
  setUp(() async {
    await GStorage.settings.clear();
    await filterBox.clear();
    filter = ContentFilterService(filterBox,
        dio: Dio()..httpClientAdapter = _OfflineRules());
    state = OnboardingState(settings: GStorage.settings, filter: filter);
    identity = _IdentityService();
  });
  tearDown(() {
    state.dispose();
    filter.dispose();
    identity.dispose();
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> show(WidgetTester tester,
      {double scale = 1, VoidCallback? onFinished}) async {
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: OnboardingPage(
                state: state,
                initial: true,
                identityService: identity,
                onFinished: onFinished))));
    await tester.pumpAndSettle();
  }

  // Saving writes Hive on real IO; wait for the save's own notification
  // instead of a fixed delay so slower CI runners do not race the assertion.
  Future<void> tapAndAwaitSave(WidgetTester tester, Finder finder) async {
    final saved = Completer<void>();
    void changed() {
      if (!saved.isCompleted) saved.complete();
    }

    state.addListener(changed);
    try {
      await tester.runAsync(() async {
        await tester.tap(finder);
        await saved.future.timeout(const Duration(seconds: 5));
      });
    } finally {
      state.removeListener(changed);
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder,
      {bool persist = false}) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    if (persist) {
      await tapAndAwaitSave(tester, finder);
    } else {
      await tester.tap(finder);
    }
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) =>
      tap(tester, find.byKey(const ValueKey('onboarding-next')));

  testWidgets(
      'four steps keep draft local then finish applies explicit choices',
      (tester) async {
    var finished = 0;
    await show(tester, onFinished: () => finished++);
    expect(state.active, isTrue);
    expect(find.text('1 / 4'), findsOneWidget);
    await tap(tester, find.text('我也会发布'));
    expect(GStorage.hideHomePublishButton, isTrue);
    await next(tester);
    expect(find.text('2 / 4'), findsOneWidget);
    await tap(tester, find.text('M3E'));
    await next(tester);
    expect(find.text('3 / 4'), findsOneWidget);
    final enabled = find.byKey(const ValueKey('onboarding-filter-enabled'));
    expect(tester.widget<SwitchListTile>(enabled).value, isFalse);
    await tap(tester, enabled);
    expect(filter.enabled, isFalse);
    expect(find.text('标准'), findsOneWidget);
    await next(tester);
    expect(find.text('4 / 4'), findsOneWidget);
    expect(identity.calls, 0);
    await tap(tester, find.byKey(const ValueKey('onboarding-next')),
        persist: true);
    expect(GStorage.hideHomePublishButton, isFalse);
    expect(GStorage.floatingNavigation, isFalse);
    expect(filter.enabled, isTrue);
    expect(filter.level, FilterLevel.standard);
    expect(state.completed, isTrue);
    expect(state.active, isFalse);
    expect(finished, 1);
    expect(identity.calls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('skip discards changed choices and marks the introduction seen',
      (tester) async {
    await show(tester);
    await tap(tester, find.text('我也会发布'));
    await tap(tester, find.text('跳过引导'), persist: true);
    expect(GStorage.hideHomePublishButton, isTrue);
    expect(filter.enabled, isFalse);
    expect(state.completed, isTrue);
    expect(identity.calls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('custom appearance and disabled strict filter survive completion',
      (tester) async {
    await tester.runAsync(() async {
      await GStorage.settings.putAll({
        SettingsBoxKey.floatingNavigation: true,
        SettingsBoxKey.liquidGlass: false,
      });
      await filter.setLevel(FilterLevel.strict);
      await filter.setListEnabled(FilterRuleKind.author, false);
    });
    await show(tester);
    await next(tester);
    expect(find.text('当前自定义外观'), findsOneWidget);
    await next(tester);
    await tap(tester, find.byKey(const ValueKey('onboarding-filter-enabled')));
    expect(
        tester
            .widget<Semantics>(
                find.byKey(const ValueKey('onboarding-filter-strict')))
            .properties
            .selected,
        isTrue);
    await tap(tester, find.byKey(const ValueKey('onboarding-filter-enabled')));
    await next(tester);
    await tap(tester, find.byKey(const ValueKey('onboarding-next')),
        persist: true);
    expect(GStorage.floatingNavigation, isTrue);
    expect(GStorage.liquidGlass, isFalse);
    expect(filter.enabled, isFalse);
    expect(filter.level, FilterLevel.strict);
    expect(filter.isListEnabled(FilterRuleKind.author), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Escape returns one step and reopened cancel returns to settings',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => OnboardingPage(
                                state: state, identityService: identity))),
                    child: const Text('重新打开'))))));
    await tap(tester, find.text('重新打开'));
    await next(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('1 / 4'), findsOneWidget);
    await tap(tester, find.text('我也会发布'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('重新打开'), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
    expect(GStorage.hideHomePublishButton, isTrue);
    expect(state.active, isFalse);
    expect(state.completed, isFalse);
  });

  testWidgets('320 wide short viewport with large text can reach every action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await show(tester, scale: 2);
    for (var step = 0; step < 3; step++) {
      expect(tester.takeException(), isNull);
      await next(tester);
    }
    expect(find.text('4 / 4'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('onboarding-next')),
        persist: true);
    expect(state.completed, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final fixture in [
    (size: const Size(1600, 420), scale: 2.0),
    (size: const Size(1600, 540), scale: 3.0),
  ]) {
    testWidgets(
        'wide short viewport at ${fixture.scale}x text keeps every step reachable',
        (tester) async {
      await tester.binding.setSurfaceSize(fixture.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await show(tester, scale: fixture.scale);
      expect(tester.takeException(), isNull);
      await tap(tester, find.text('我也会发布'));
      for (var step = 0; step < 3; step++) {
        await next(tester);
        expect(tester.takeException(), isNull);
      }
      await tap(tester, find.byKey(const ValueKey('onboarding-next')),
          persist: true);
      expect(state.completed, isTrue);
      expect(GStorage.hideHomePublishButton, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final finish in [false, true]) {
    testWidgets(
        'reopened ${finish ? 'finish' : 'cancel'} pauses startup work through exit transition',
        (tester) async {
      await tester.runAsync(state.skip);
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => OnboardingPage(
                                  state: state, identityService: identity))),
                      child: const Text('重新打开'))))));
      await tap(tester, find.text('重新打开'));
      if (finish) {
        await next(tester);
        await next(tester);
        await next(tester);
        await tapAndAwaitSave(
            tester, find.byKey(const ValueKey('onboarding-next')));
      } else {
        await tester.tap(find.text('取消'));
      }
      await tester.pump();
      expect(state.active, isTrue);
      await tester.pumpAndSettle();
      expect(state.active, isFalse);
      expect(find.text('重新打开'), findsOneWidget);
    });
  }

  testWidgets('identity action registers only on tap and never renders the ID',
      (tester) async {
    identity.pending = Completer<String>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DeviceIdentityAction(service: identity))));
    await tester.pumpAndSettle();
    expect(identity.calls, 0);
    await tester.tap(find.text('获取数盟 ID'));
    await tester.pump();
    expect(identity.calls, 1);
    expect(find.text('正在获取…'), findsOneWidget);
    identity.nextAllowedAt = DateTime.now().add(const Duration(days: 7));
    identity.unavailableReason = '成功获取后需间隔 7 天';
    identity.pending!.complete('synthetic_secret_identity');
    await tester.pumpAndSettle();
    expect(find.textContaining('synthetic_secret_identity'), findsNothing);
    expect(find.textContaining('已获取并保存'), findsOneWidget);
    expect(find.textContaining('可再次获取时间'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'shared identity action displays safe failure and refreshes limits',
      (tester) async {
    identity.pending = Completer<String>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DeviceIdentityAction(service: identity))));
    await tester.tap(find.text('获取数盟 ID'));
    await tester.pump();
    identity.pending!.completeError(const SzlmDuidException('网络暂不可用'));
    await tester.pumpAndSettle();
    expect(find.text('网络暂不可用'), findsOneWidget);
    expect(identity.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
