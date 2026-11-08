import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/cards/search_history_card.dart';
import '../../pages/search/search_page_controller.dart';
import '../../utils/extensions.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final String? _title = Get.parameters['title'];
  final String? _pageType = Get.parameters['pageType'];
  final String? _pageParam = Get.parameters['pageParam'];
  final _clearStream = StreamController<bool>();

  late final _searchPageController =
      Get.put(SearchPageController(), tag: '$_title$_pageType$_pageParam');

  @override
  void dispose() {
    _clearStream.close();
    _controller.dispose();
    _focusNode.dispose();
    Get.delete<SearchPageController>(tag: '$_title$_pageType$_pageParam');
    super.dispose();
  }

  void onSearch(String text) {
    if (text.isNotEmpty) {
      // Clear the route's remembered editor focus before opening results.
      // Returning from a result or detail must not reopen the keyboard.
      _focusNode.unfocus();
      _searchPageController.handleSearch(text);
      Get.toNamed('/searchResult', parameters: {
        'keyword': text,
        if (!_title.isNullOrEmpty) 'title': _title!,
        if (!_pageType.isNullOrEmpty) 'pageType': _pageType!,
        if (!_pageParam.isNullOrEmpty) 'pageParam': _pageParam!,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          focusNode: _focusNode,
          onTap: () => _focusNode.requestFocus(),
          controller: _controller,
          style: const TextStyle(fontSize: 18),
          onChanged: (value) {
            _clearStream.add(value.isNotEmpty);
          },
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: !_title.isNullOrEmpty ? '在 $_title 中搜索' : '搜索',
            hintStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
            ),
          ),
          textInputAction: TextInputAction.search,
          autofocus: true,
          onSubmitted: (value) {
            onSearch(value);
          },
        ),
        actions: [
          StreamBuilder(
            initialData: false,
            stream: _clearStream.stream,
            builder: (_, snapshot) => snapshot.data == true
                ? IconButton(
                    onPressed: () {
                      _controller.clear();
                      _focusNode.requestFocus();
                      _clearStream.add(false);
                    },
                    icon: const Icon(Icons.clear),
                    tooltip: '清除',
                  )
                : const SizedBox.shrink(),
          ),
          IconButton(
            onPressed: () {
              onSearch(_controller.text);
            },
            icon: const Icon(Icons.search),
            tooltip: '搜索',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.zero,
          child: Divider(height: 1),
        ),
      ),
      body: Obx(() => _searchPageController.historyList.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 10),
                    const Expanded(
                      flex: 1,
                      child: Text(
                        '搜索历史',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '清除全部',
                      onPressed: () => showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                                title: const Text('确定清除全部搜索历史？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Get.back(),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Get.back();
                                      _searchPageController.clearAll();
                                    },
                                    child: const Text('确定'),
                                  )
                                ],
                              )),
                      icon: const Icon(Icons.clear_all),
                    )
                  ],
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 10,
                    right: 10,
                    bottom: 10 + MediaQuery.of(context).padding.bottom,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _searchPageController.historyList
                        .map(
                          (text) => SearchHistoryCard(
                            text: text,
                            onTap: () {
                              _controller.text = text;
                              _clearStream.add(true);
                              onSearch(text);
                            },
                            onLongPress: () =>
                                _searchPageController.handleSearch(text, true),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            )
          : const SizedBox()),
    );
  }
}
