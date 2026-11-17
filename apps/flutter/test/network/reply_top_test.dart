import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:c001apk_flutter/logic/model/feed/datum.dart';
import 'package:c001apk_flutter/logic/network/request.dart';
import 'package:c001apk_flutter/logic/state/loading_state.dart';
import 'package:c001apk_flutter/pages/feed/feed_controller.dart';
import 'package:c001apk_flutter/utils/coin_reply.dart';
import 'package:c001apk_flutter/utils/storage_util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _Transport implements HttpClientAdapter {
  Map<String, dynamic> body = {'data': '置顶成功'};
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Datum _reply(int id, [String message = '普通评论']) =>
    Datum(id: id, message: message, entityType: 'feed_reply');

void main() {
  group('coin-only replies', () {
    test('match replies made only of coin emoji', () {
      expect(isCoinOnlyText('[酷币]'), isTrue);
      expect(isCoinOnlyText(' [酷币][酷币]\n[酷币5毛] '), isTrue);
      expect(isCoinOnlyText('[酷币1\$]&nbsp;[新币1分]'), isTrue);
      expect(isCoinOnlyText('<span>[酷币]</span>'), isTrue);
    });
    test('keep replies with any other content', () {
      expect(isCoinOnlyText(''), isFalse);
      expect(isCoinOnlyText('   '), isFalse);
      expect(isCoinOnlyText('[酷币] 支持一下'), isFalse);
      expect(isCoinOnlyText('[酷币][赞]'), isFalse);
      expect(isCoinOnlyText('酷币'), isFalse);
      expect(isCoinOnlyText('[哈哈]'), isFalse);
    });
    test('a coin reply with pictures is not folded', () {
      expect(isCoinOnlyReply(Datum(message: '[酷币]')), isTrue);
      expect(isCoinOnlyReply(Datum(message: '[酷币]', picArr: ['a.jpg'])),
          isFalse);
    });
  });

  group('reply pinning', () {
    late Directory temp;
    late _Transport transport;
    setUpAll(() async {
      temp = await Directory.systemTemp.createTemp('reply-top-test-');
      Hive.init(temp.path);
      GStorage.settings = await Hive.openBox('settings');
      await GStorage.settings.putAll({
        SettingsBoxKey.xAppDevice: 'synthetic-reply-top-device',
        SettingsBoxKey.versionCode: '2604201',
        SettingsBoxKey.recordHistory: false,
      });
      Request();
    });
    setUp(() {
      transport = _Transport();
      Request.dio.httpClientAdapter = transport;
    });
    tearDownAll(() async {
      await Hive.close();
      await temp.delete(recursive: true);
    });

    Future<void> mount(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [FlutterSmartDialog.observer],
        builder: FlutterSmartDialog.init(),
        home: const Scaffold(),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> settleToast(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester
          .runAsync(() => SmartDialog.dismiss(status: SmartStatus.allToast));
      await tester.pump(const Duration(seconds: 1));
    }

    List<dynamic> visibleIds(FeedController controller) =>
        (controller.loadingState.value as Success<dynamic>)
            .response
            .map((item) => (item as Datum).id)
            .toList();

    testWidgets('pin posts a form and moves the reply to the top',
        (tester) async {
      await mount(tester);
      final controller = FeedController(id: '900', recordHistory: false);
      final old = _reply(1);
      controller.topReply = old;
      controller.publishItems([old, _reply(2), _reply(3)]);

      await tester.runAsync(() => controller.toggleReplyTop(_reply(3)));
      await settleToast(tester);

      final request = transport.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v6/feed/addReplyTopToFeed');
      expect(request.contentType, Headers.formUrlEncodedContentType);
      expect(request.data, {'replyId': '3', 'feedId': '900'});
      expect(controller.topReply?.id, 3);
      expect(visibleIds(controller), [3, 1, 2]);
      expect(controller.isPinnedReply(_reply(3)), isTrue);
      expect(controller.isPinnedReply(old), isFalse);
    });

    testWidgets('unpin sends only the feed id and keeps the list order',
        (tester) async {
      await mount(tester);
      transport.body = {'status': 1, 'message': '已取消置顶'};
      final controller = FeedController(id: '900', recordHistory: false);
      final pinned = _reply(5);
      controller.topReply = pinned;
      controller.publishItems([pinned, _reply(6)]);

      await tester.runAsync(() => controller.toggleReplyTop(pinned));
      await settleToast(tester);

      final request = transport.requests.single;
      expect(request.uri.path, '/v6/feed/cancelReplyTopFromFeed');
      expect(request.data, {'feedId': '900'});
      expect(controller.topReply, isNull);
      expect(visibleIds(controller), [5, 6]);
    });

    testWidgets('a rejected pin leaves the current state untouched',
        (tester) async {
      await mount(tester);
      transport.body = {'status': -1, 'message': '无权操作'};
      final controller = FeedController(id: '900', recordHistory: false);
      final pinned = _reply(7);
      controller.topReply = pinned;
      controller.publishItems([pinned, _reply(8)]);

      await tester.runAsync(() => controller.toggleReplyTop(_reply(8)));
      await settleToast(tester);

      expect(controller.topReply?.id, 7);
      expect(visibleIds(controller), [7, 8]);
    });
  });
}
