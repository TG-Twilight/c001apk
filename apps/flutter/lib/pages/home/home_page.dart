// ignore_for_file: constant_identifier_names

import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/mouse_drag_scroll.dart';
import '../../components/feed_navigation.dart';
import '../../components/liquid_top_bar.dart';
import '../../components/liquid_navigation_bar.dart';
import '../../utils/storage_util.dart';
import '../../constants/home_tab.dart';
import 'home_tabs_page.dart';
export '../../constants/home_tab.dart' show TabType;
import '../../pages/home/app/app_list_page.dart';
import '../../pages/home/feed/home_feed_page.dart';
import '../../pages/home/return_top_controller.dart';
import '../../pages/home/topic/home_topic_page.dart';

class HomePage extends StatefulWidget {
  const HomePage(
      {super.key,
      this.useRail = false,
      this.onFeedSelected,
      this.onPublishVisibilityChanged});

  final bool useRail;
  final ValueChanged<bool>? onFeedSelected, onPublishVisibilityChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final _bodyKey = GlobalKey();
  late TabController _tabController;
  StreamSubscription<int>? _returnTopSubscription;
  final ReturnTopController _pageScrollController =
      Get.find<ReturnTopController>(tag: 'home');
  // late final _config = Provider.of<AppConfigProvider>(context, listen: false);
  // late bool _showFab = true; //_config.isLogin;

  late List<TabType> _tabTypes = HomeTabConfiguration.fromStored(
          GStorage.settings.get(HomeTabConfiguration.storageKey))
      .visible(android: Platform.isAndroid);

  // TabBarView wraps children in index-keyed semantics. Global keys preserve
  // the existing page state when a category moves across those wrappers.
  final _pageKeys = {
    for (final tab in HomeTabConfiguration.defaultOrder) tab: GlobalKey(),
  };

  List<Widget> get _pages => _tabTypes
      .map((tab) => KeyedSubtree(
          key: _pageKeys[tab],
          child: switch (tab) {
            TabType.APP => const AppListPage(),
            TabType.FEED => HomeFeedPage(
                tabType: TabType.FEED,
                useRail: widget.useRail,
                onPublishVisibilityChanged: widget.onPublishVisibilityChanged),
            TabType.HOT => const HomeFeedPage(tabType: TabType.HOT),
            TabType.TOPIC => const HomeTopicPage(tabType: TabType.TOPIC),
            TabType.PRODUCT => const HomeTopicPage(tabType: TabType.PRODUCT),
            TabType.COOLPIC => const HomeFeedPage(tabType: TabType.COOLPIC),
            _ => throw StateError('Unsupported home tab'),
          }))
      .toList();

  void _onTabChanged() => widget.onFeedSelected
      ?.call(_tabTypes[_tabController.index] == TabType.FEED);

  Future<void> _editTabs() async {
    final configuration = await Navigator.of(context)
        .push<HomeTabConfiguration>(
            MaterialPageRoute(builder: (_) => const HomeTabsPage()));
    if (!mounted || configuration == null) return;
    final selected = _tabTypes[_tabController.index];
    final tabs = configuration.visible(android: Platform.isAndroid);
    if (tabs.length == _tabTypes.length &&
        List.generate(tabs.length, (i) => tabs[i] == _tabTypes[i])
            .every((v) => v)) {
      return;
    }
    final oldController = _tabController;
    oldController.removeListener(_onTabChanged);
    setState(() {
      _tabTypes = tabs;
      _tabController = TabController(
        vsync: this,
        length: tabs.length,
        initialIndex:
            tabs.indexOf(tabs.contains(selected) ? selected : TabType.FEED),
      )..addListener(_onTabChanged);
    });
    _onTabChanged();
    // Let TabBar and TabBarView detach their listeners before disposal.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => oldController.dispose());
  }

  void scrollToTop(int index) {
    _pageScrollController.setIndex(_tabTypes[index].index);
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      vsync: this,
      initialIndex: _tabTypes.indexOf(TabType.FEED),
      length: _tabTypes.length,
    );
    _tabController.addListener(_onTabChanged);

    _returnTopSubscription = _pageScrollController.index.listen((index) {
      if (index == 998) {
        scrollToTop(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _returnTopSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = KeyedSubtree(
        key: _bodyKey,
        child: TabBarView(controller: _tabController, children: _pages));
    // Reparent the keyed body so the original controllers and scroll positions
    // survive removing the home toolbar from the reading supplement.
    if (FeedNavigation.compactOf(context)) return Material(child: body);
    return LiquidTopBarScaffold(
      actions: [
        IconButton(
            onPressed: _editTabs,
            tooltip: '编辑主页分类',
            icon: const Icon(Icons.tune))
      ],
      glassActions: (_) => [
        const SizedBox(width: 8),
        LiquidGlassButton(
            level: GStorage.liquidGlassLevel,
            enabled: GStorage.liquidGlass,
            tooltip: '编辑主页分类',
            height: 48,
            width: 48,
            onPressed: _editTabs,
            child: const Icon(Icons.tune)),
      ],
      glassTitle: (context) => SizedBox(
          width: _tabTypes.length *
                  (MediaQuery.textScalerOf(context).scale(14) * 2 + 28) +
              8,
          child: AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) => LiquidNavigationBar.tabs(
              key: ValueKey(_tabTypes.map((tab) => tab.storageId).join(',')),
              selectedIndex: _tabController.index,
              labels: _tabTypes.map((type) => type.label).toList(),
              level: GStorage.liquidGlassLevel,
              onDestinationSelected: (index) {
                if (_tabController.index == index) {
                  scrollToTop(index);
                } else {
                  _tabController.animateTo(index);
                }
              },
            ),
          )),
      title: MouseDragScroll(
        child: TabBar(
          controller: _tabController,
          tabs: _tabTypes.map((type) => Tab(text: type.label)).toList(),
          isScrollable: true,
          dividerColor: Theme.of(context).platform == TargetPlatform.android
              ? Colors.transparent
              : null,
          tabAlignment: Theme.of(context).platform == TargetPlatform.android
              ? TabAlignment.start
              : null,
          onTap: (index) {
            if (!_tabController.indexIsChanging) {
              scrollToTop(index);
            }
          },
        ),
      ),
      onSearch: () => Get.toNamed('/search'),
      body: body,
    );
  }
}
