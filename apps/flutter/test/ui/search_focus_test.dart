import 'dart:io';

import 'package:c001apk_flutter/pages/search/search_page.dart';
import 'package:c001apk_flutter/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory temp;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('search-focus-');
    Hive.init(temp.path);
    GStorage.searchHistory = await Hive.openBox('searchHistory');
  });
  tearDown(Get.reset);
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  testWidgets('search navigation releases the editor and does not reopen it',
      (tester) async {
    await tester.pumpWidget(GetMaterialApp(
      home: const SearchPage(),
      getPages: [
        GetPage(
          name: '/searchResult',
          page: () => Scaffold(
            appBar: AppBar(title: const Text('搜索结果')),
            body: TextButton(
              onPressed: () => Get.to(() => Scaffold(
                    appBar: AppBar(title: const Text('详情')),
                  )),
              child: const Text('打开动态'),
            ),
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '测试');
    final editor = tester.widget<TextField>(find.byType(TextField));
    expect(editor.focusNode!.hasFocus, isTrue);
    // The toolbar action keeps the editor focused unless search releases it.
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('搜索'));
      await GStorage.searchHistory.flush();
    });
    await tester.pumpAndSettle();
    expect(editor.focusNode!.hasFocus, isFalse);
    await tester.tap(find.text('打开动态'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('搜索结果'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(editor.focusNode!.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(editor.focusNode!.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
