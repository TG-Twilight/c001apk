import '../../components/expressive_refresh_indicator.dart';
import '../../components/expressive_loading_indicator.dart';
// ignore_for_file: constant_identifier_names

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/dialog/dialog_route.dart';

import '../../components/cards/feed_reply_card.dart';
import '../../components/content_filter_gate.dart';
import '../../components/content_filter_text.dart';
import '../../logic/content_filter/content_filter_projection.dart';
import '../../logic/content_filter/content_filter_rule.dart';
import '../../logic/model/feed_article/feed_article.dart';
import '../../components/feed_article_body.dart';
import '../../components/reading_presentation.dart';
import '../../components/footer.dart';
import '../../components/sliver_pinned_box_adapter.dart';
import '../../components/cards/feed_card.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/media/feed_media_context.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/feed/feed_controller.dart';
import '../../pages/feed/reply/reply_dialog.dart' show ReplyType;
import '../../pages/feed/reply/reply_page.dart';
import '../settings/device_identity_page.dart';
import '../../utils/device_util.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';
import '../../utils/markdown_content.dart';
import '../../components/content_export_button.dart';
import '../../utils/storage_util.dart';
import '../../utils/utils.dart';

enum FeedMenuItem {
  Copy,
  Share,
  Fav,
  Block,
  Source,
  Report;

  String get label => switch (this) {
        FeedMenuItem.Copy => '复制',
        FeedMenuItem.Share => '分享',
        FeedMenuItem.Fav => '收藏',
        FeedMenuItem.Block => '屏蔽',
        FeedMenuItem.Source => '查看原文',
        FeedMenuItem.Report => '举报',
      };
}

enum ReplySortType { def, dateline, hot, author }

class FeedPage extends StatefulWidget {
  const FeedPage({super.key, this.id, this.onClose});

  final String? id;
  final VoidCallback? onClose;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with TickerProviderStateMixin {
  late final String _id = widget.id ?? Get.parameters['id'].orEmpty;
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  AnimationController? _fabAnimationCtr;
  late bool _isFabVisible = true;
  late final _scrollController = ScrollController();
  final _titleVisible = ValueNotifier<bool>(false);
  bool _showSource = false;
  Datum? _supplementData;

  void _updateSupplement(BuildContext context) {
    final state = _feedController.feedState.value;
    if (state is! Success || identical(state.response, _supplementData)) return;
    final data = state.response as Datum;
    _supplementData = data;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      ReadingSupplement(
          _id,
          Card.outlined(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Get.toNamed('/u/${data.uid}'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('本文作者', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                          child: Text(
                              data.userInfo?.username ??
                                  data.username ??
                                  '查看作者',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700))),
                      const Icon(Icons.chevron_right, size: 20),
                    ]),
                  ],
                ),
              ),
            ),
          )).dispatch(context);
    });
  }

  bool get _hasMarkdown {
    final state = _feedController.feedState.value;
    if (state is! Success) return false;
    final data = state.response as Datum;
    return MarkdownContent.parse(data.message.orEmpty).isMarkdown ||
        (_feedController.articleList ?? []).any((part) =>
            part.type == 'text' &&
            MarkdownContent.parse(part.message.orEmpty).isMarkdown);
  }

  @override
  void initState() {
    super.initState();
    if (GlobalData().isLogin) {
      _fabAnimationCtr = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 300));
      _fabAnimationCtr?.forward();
      _scrollController.addListener(() {
        final ScrollDirection direction =
            _scrollController.position.userScrollDirection;
        if (direction == ScrollDirection.forward) {
          _showFab();
        } else if (direction == ScrollDirection.reverse) {
          _hideFab();
        }
      });
    }
  }

  void _showFab() {
    if (!_isFabVisible) {
      _isFabVisible = true;
      _fabAnimationCtr?.forward();
    }
  }

  void _hideFab() {
    if (_isFabVisible) {
      _isFabVisible = false;
      _fabAnimationCtr?.reverse();
    }
  }

  @override
  void dispose() {
    _titleVisible.dispose();
    _scrollController.dispose();
    _fabAnimationCtr?.dispose();
    Get.delete<FeedController>(tag: _id + _random);
    super.dispose();
  }

  late final String _random = DeviceUtil.randHexString(8);
  late final _feedController = Get.put(
    FeedController(
      id: _id,
      recordHistory: GStorage.recordHistory,
    ),
    tag: _id + _random,
  );

  static const List<(ReplySortType, String)> _shirtSizeOptions =
      <(ReplySortType, String)>[
    (ReplySortType.def, '默认'),
    (ReplySortType.dateline, '最新'),
    (ReplySortType.hot, '热门'),
    (ReplySortType.author, '楼主'),
  ];

  Widget _buildFeedContent(LoadingState feedState) {
    switch (feedState) {
      case Empty():
        return GestureDetector(
          onTap: () {
            _feedController.setFeedState(LoadingState.loading());
            _feedController.getFeedData();
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10.0),
            child: const Text('暂无内容'),
          ),
        );
      case Error():
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(feedState.errMsg, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () {
                      _feedController.setFeedState(LoadingState.loading());
                      _feedController.getFeedData(verify: true);
                    },
                    child: const Text('重试'),
                  ),
                  if (feedState.canVerify)
                    TextButton(
                      onPressed: () async {
                        final previousDevice = GStorage.xAppDevice;
                        await Get.to(() => const DeviceIdentityPage());
                        if (!mounted || previousDevice == GStorage.xAppDevice) {
                          return;
                        }
                        _feedController.setFeedState(LoadingState.loading());
                        await _feedController.getFeedData();
                      },
                      child: const Text('设备标识设置'),
                    ),
                ]),
          ]),
        );
      case Success():
        return _feedController.articleList.isNullOrEmpty
            ? FeedCard(
                data: feedState.response!,
                isFeedContent: true,
                forcePlain: _showSource,
                onLike: (id, like) {
                  if (GlobalData().isLogin) {
                    _feedController.onLike(
                      id,
                      like,
                      isFeed: true,
                    );
                  }
                },
              )
            : SliverList.separated(
                itemCount: _feedController.articleList!.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final data = feedState.response as Datum;
                    final wide = ReadingPresentation.of(context);
                    final title = data.messageTitle.isNullOrEmpty
                        ? data.title.orEmpty
                        : data.messageTitle!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (wide && title.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
                            child: ContentFilterText(
                              source: title,
                              builder: (title) => Text(
                                Utils.parseHtmlString(title),
                                style: const TextStyle(
                                    fontSize: 32,
                                    height: 1.25,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        header(
                          context,
                          data,
                          true,
                        ),
                        if (wide) const SizedBox(height: 20),
                      ],
                    );
                  } else if (index == _feedController.articleList!.length + 1) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: bottomInfo(
                        context,
                        feedState.response!,
                        true,
                        null,
                        isFeedArticle: true,
                        () {
                          if (GlobalData().isLogin) {
                            Datum data = feedState.response;
                            _feedController.onLike(
                              data.id,
                              data.userAction?.like,
                              isFeed: true,
                            );
                          }
                        },
                      ),
                    );
                  } else {
                    return LayoutBuilder(builder: (_, constraints) {
                      final article = _feedController.articleList![index - 1];
                      // The controller prepends the feed title for mobile.
                      // Wide reading has already placed it above the author.
                      if (ReadingPresentation.of(context) &&
                          article.type == 'title' &&
                          article.title ==
                              (feedState.response as Datum).title) {
                        return const SizedBox.shrink();
                      }
                      return ContentFilterText(
                          key: ValueKey('article:$_id:$index'),
                          source: article.type == 'title' ||
                                  article.type == 'shareUrl'
                              ? article.title.orEmpty
                              : article.type == 'image'
                                  ? article.description.orEmpty
                                  : article.message.orEmpty,
                          builder: (message) => feedArticleBody(
                                constraints.maxWidth,
                                FeedArticle.fromJson({
                                  ...article.toJson(),
                                  if (article.type == 'title' ||
                                      article.type == 'shareUrl')
                                    'title': message
                                  else if (article.type == 'image')
                                    'description': message
                                  else
                                    'message': message
                                }),
                                _feedController.articleImgList!,
                                forcePlain: _showSource,
                                wideReading: ReadingPresentation.of(context),
                                mediaItems: mediaForDatum(feedState.response!),
                                contentId: feedState.response!.id?.toString(),
                              ));
                    });
                  }
                },
                separatorBuilder: (_, index) => const SizedBox(height: 12),
              );
    }
    return const ExpressiveLoadingIndicator();
  }

  Future<void> _showAccountDetailStatus() async {
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('账号信息暂不可用'),
        content: Text(_feedController.accountDetailNotice.value),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重试账号详情'),
          ),
        ],
      ),
    );
    if (retry != true || !mounted) return;
    await _feedController.getFeedData(verify: true);
    if (!mounted) return;
    final notice = _feedController.accountDetailNotice.value;
    SmartDialog.showToast(notice.isEmpty ? '账号详情已更新' : notice);
  }

  void _changeReplySort(ReplySortType selection) {
    _feedController.replySelection.value = selection;
    _feedController.fromFeedAuthor = selection == ReplySortType.author ? 1 : 0;
    _feedController.listType = switch (selection) {
      ReplySortType.def => 'lastupdate_desc',
      ReplySortType.dateline => 'dateline_desc',
      ReplySortType.hot => 'popular',
      ReplySortType.author => '',
    };
    _refreshKey.currentState?.show();
  }

  Widget _buildPinWidget(BuildContext context) {
    if (ReadingPresentation.of(context)) {
      return SliverPinnedBoxAdapter(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(
                  child: Text('评论 · ${_feedController.replyNum}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700))),
              Obx(() => PopupMenuButton<ReplySortType>(
                    tooltip: '评论排序',
                    initialValue: _feedController.replySelection.value,
                    onSelected: _changeReplySort,
                    itemBuilder: (_) => [
                      for (final option in _shirtSizeOptions)
                        CheckedPopupMenuItem(
                            value: option.$1,
                            checked: option.$1 ==
                                _feedController.replySelection.value,
                            child: Text(option.$2))
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_shirtSizeOptions
                            .firstWhere((option) =>
                                option.$1 ==
                                _feedController.replySelection.value)
                            .$2),
                        const Icon(Icons.expand_more, size: 20),
                      ]),
                    ),
                  )),
              if (GlobalData().isLogin)
                IconButton(
                    tooltip: '回复',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _onReply(
                        ReplyType.feed,
                        _feedController.id,
                        _feedController.feedUsername,
                        null)),
            ]),
          ),
        ),
      );
    }
    return SliverPinnedBoxAdapter(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Text('共 ${_feedController.replyNum} 回复'),
                  ),
                  Obx(
                    () => SegmentedButton<ReplySortType>(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                      ),
                      showSelectedIcon: false,
                      selected: <ReplySortType>{
                        _feedController.replySelection.value
                      },
                      segments: _shirtSizeOptions
                          .map<ButtonSegment<ReplySortType>>(
                              ((ReplySortType, String) shirt) {
                        return ButtonSegment<ReplySortType>(
                            value: shirt.$1, label: Text(shirt.$2));
                      }).toList(),
                      onSelectionChanged: (Set<ReplySortType> newSelection) {
                        _changeReplySort(newSelection.first);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }

  Future<void> _onReply(
    ReplyType type,
    dynamic id,
    dynamic uname,
    dynamic fid,
  ) async {
    Navigator.of(context)
        .push(
      GetDialogRoute(
        pageBuilder: (buildContext, animation, secondaryAnimation) {
          return ReplyPage(
            type: type,
            username: uname,
            id: id,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.linear;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    )
        .then(
      (result) {
        if (result != null && result['data'] != null) {
          _feedController.updateReply(
            type == ReplyType.reply,
            result['data'] as Datum,
            id,
            fid,
          );
        }
      },
    );

    // dynamic result = await showModalBottomSheet<dynamic>(
    //   context: context,
    //   isScrollControlled: true,
    //   builder: (context) => ReplyDialog(
    //     type: type,
    //     username: uname,
    //     id: id,
    //   ),
    // );
    // if (result != null && result['data'] != null) {
    //   _feedController.updateReply(
    //     type == ReplyType.reply,
    //     result['data'] as Datum,
    //     id,
    //     fid,
    //   );
    // }
  }

  Widget _buildDeferredReplyPrompt(LoadingState replyState,
      {bool hasReplies = false}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined),
          const SizedBox(height: 12),
          Text(hasReplies ? '评论加载已暂停' : '评论尚未加载'),
          const SizedBox(height: 8),
          const Text(
            '设备标识尚未取得（可能离线或取号失败），加载评论可能需要验证码验证。'
            '可在设置中自动获取或手动导入后再加载。',
            textAlign: TextAlign.center,
          ),
          if (replyState is Error) ...[
            const SizedBox(height: 8),
            Text(replyState.errMsg, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _feedController.loadReplies,
            icon: const Icon(Icons.download_outlined),
            label: const Text('加载评论并验证'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedReply(LoadingState replyState) {
    if (_feedController.repliesDeferred.value && replyState is! Success) {
      return SliverToBoxAdapter(child: _buildDeferredReplyPrompt(replyState));
    }
    switch (replyState) {
      case Empty():
        return SliverToBoxAdapter(
          child: Container(
            height: 80,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10.0),
            child: const Text('暂无内容'),
          ),
        );
      case Error():
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(replyState.errMsg, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _feedController.loadReplies,
                child: const Text('重新加载评论'),
              ),
            ]),
          ),
        );
      case Success():
        List<Datum> dataList = replyState.response;
        return SliverPadding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          sliver: SliverList.separated(
            itemCount: dataList.length + 1,
            itemBuilder: (_, index) {
              if (index == dataList.length) {
                if (!_feedController.repliesDeferred.value &&
                    !_feedController.isEnd &&
                    !_feedController.automaticLoadPaused &&
                    !_feedController.isLoading) {
                  _feedController.setFooterState(LoadingState.loading());
                  _feedController.onGetData(false);
                }
                return Obx(
                  () => _feedController.repliesDeferred.value
                      ? _buildDeferredReplyPrompt(
                          _feedController.footerState.value,
                          hasReplies: true)
                      : footerWidget(
                          _feedController.footerState.value,
                          () {
                            _feedController
                              ..isEnd = false
                              ..setFooterState(LoadingState.loading())
                              ..onGetData(false);
                          },
                        ),
                );
              } else {
                return FeedReplyCard(
                  data: dataList[index],
                  isTopReply: _feedController.topReply != null &&
                      index == 0 &&
                      _feedController.listType == 'lastupdate_desc',
                  onBlock: _feedController.onBlockReply,
                  onReply: (id, uname, fid) {
                    if (GlobalData().isLogin) {
                      _onReply(ReplyType.reply, id, uname, fid);
                    }
                  },
                  onDelete: (id, fid) {
                    _feedController.postLikeDeleteFollow(id, fid,
                        isReply: true);
                  },
                  onLike: (id, like) {
                    _feedController.onLike(id, like, isReply: true);
                  },
                );
              }
            },
            separatorBuilder: (_, index) => const Divider(height: 1),
          ),
        );
    }
    return SliverToBoxAdapter(
      child: Container(
        height: 80,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(10.0),
        child: const ExpressiveLoadingIndicator(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = _feedController.feedState.value;
      if (state is! Success) return _buildScreen(context);
      final data = state.response as Datum;
      return ContentFilterRevealScope(
        contentKeys: _feedController.revealedContentKeys,
        authorUids: _feedController.revealedAuthorUids,
        child: ContentFilterGate(
            data: data,
            scope: FilterScope.feed,
            page: true,
            onClose: widget.onClose,
            onReveal: () => _feedController.revealItem(data),
            builder: _buildScreen),
      );
    });
  }

  Widget _buildScreen(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 600 &&
          MediaQuery.sizeOf(context).shortestSide >= 600;
      return ReadingPresentation(
        wide: wide,
        child: Builder(builder: _buildReadingScreen),
      );
    });
  }

  Widget _buildReadingScreen(BuildContext context) {
    final wide = ReadingPresentation.of(context);
    _updateSupplement(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      floatingActionButton: Obx(
        () => _feedController.feedState.value is Success &&
                !wide &&
                GlobalData().isLogin
            ? SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 2),
                  end: const Offset(0, 0),
                ).animate(CurvedAnimation(
                  parent: _fabAnimationCtr!,
                  curve: Curves.easeInOut,
                )),
                child: FloatingActionButton(
                  heroTag: null,
                  tooltip: '回复',
                  onPressed: () {
                    _onReply(
                      ReplyType.feed,
                      _feedController.id,
                      _feedController.feedUsername,
                      null,
                    );
                  },
                  child: const Icon(Icons.reply),
                ),
              )
            : const SizedBox(),
      ),
      appBar: PreferredSize(
        preferredSize: const Size(double.infinity, 56),
        child: Obx(
          () => AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: wide ? Colors.transparent : null,
            shape: wide
                ? Border(
                    bottom: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: .5)))
                : null,
            leading: widget.onClose == null
                ? null
                : BackButton(onPressed: widget.onClose),
            titleSpacing: 0,
            title: ValueListenableBuilder<bool>(
              valueListenable: _titleVisible,
              builder: (context, visible, _) {
                return GestureDetector(
                  onTap: () {
                    if (_scrollController.hasClients &&
                        _scrollController.offset != 0) {
                      _scrollController.animToTop();
                    }
                  },
                  child: Container(
                    color: Colors.transparent,
                    width: double.infinity,
                    child: visible && _feedController.feedState.value is Success
                        ? header(
                            context,
                            (_feedController.feedState.value as Success)
                                .response,
                            true,
                            isHeader: true,
                          )
                        : _feedController.feedState.value is Success
                            ? Text(
                                wide
                                    ? (_feedController.articleList.isNullOrEmpty
                                        ? '帖子'
                                        : '文章')
                                    : _feedController.feedTypeName ?? '动态',
                                textAlign: Platform.isIOS
                                    ? TextAlign.center
                                    : TextAlign.start,
                              )
                            : null,
                  ),
                );
              },
            ),
            actions: _feedController.feedState.value is Success
                ? [
                    if (wide)
                      IconButton(
                        tooltip: '查看作者',
                        onPressed: () =>
                            Get.toNamed('/u/${_feedController.feedUid}'),
                        icon: const Icon(Icons.person_outline),
                      ),
                    if ((_feedController.feedState.value as Success).isPublic &&
                        GlobalData().isLogin)
                      IconButton(
                        tooltip: '账号信息暂不可用',
                        onPressed: _feedController.isLoadingDetail.value
                            ? null
                            : _showAccountDetailStatus,
                        icon: _feedController.isLoadingDetail.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.info_outline),
                      ),
                    ContentExportButton(
                      feed: (_feedController.feedState.value as Success)
                          .response as Datum,
                      articles: _feedController.articleList ?? const [],
                    ),
                    PopupMenuButton(
                      onSelected: (FeedMenuItem item) {
                        switch (item) {
                          case FeedMenuItem.Copy:
                            Utils.copyText(
                                Utils.getShareUrl(_id, ShareType.feed));
                            break;
                          case FeedMenuItem.Share:
                            final data =
                                (_feedController.feedState.value as Success)
                                    .response as Datum;
                            Utils.shareContent(_id, ShareType.feed,
                                title:
                                    data.messageTitle?.trim().isNotEmpty == true
                                        ? data.messageTitle
                                        : data.title,
                                message: ContentFilterProjection.displayMessage(
                                    data),
                                context: context);
                            break;
                          case FeedMenuItem.Fav:
                            if (_feedController.isFav) {
                              GStorage.onDeleteFeed(_id, isHistory: false);
                            } else {
                              _feedController.onFav();
                            }
                            _feedController.isFav = !_feedController.isFav;
                            break;
                          case FeedMenuItem.Block:
                            GStorage.onBlock(
                              _feedController.feedUid.toString(),
                              isDelete: _feedController.isBlocked,
                            );
                            _feedController.isBlocked =
                                !_feedController.isBlocked;
                            break;
                          case FeedMenuItem.Report:
                            if (Utils.isSupportWebview()) {
                              Utils.report(_id, ReportType.Feed);
                            } else {
                              SmartDialog.showToast('当前平台暂不支持此功能');
                            }
                            break;
                          case FeedMenuItem.Source:
                            setState(() => _showSource = !_showSource);
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) => FeedMenuItem.values
                          .where((item) =>
                              item != FeedMenuItem.Source || _hasMarkdown)
                          .map((item) => PopupMenuItem<FeedMenuItem>(
                                value: item,
                                child: item == FeedMenuItem.Fav
                                    ? Text(
                                        _feedController.isFav ? '取消收藏' : '收藏',
                                      )
                                    : item == FeedMenuItem.Block
                                        ? Text(
                                            _feedController.isBlocked
                                                ? '取消屏蔽'
                                                : '屏蔽',
                                          )
                                        : item == FeedMenuItem.Source
                                            ? Text(
                                                _showSource ? '格式化显示' : '查看原文')
                                            : Text(item.label),
                              ))
                          .toList(),
                    )
                  ]
                : null,
          ),
        ),
      ),
      body: Obx(
        () => _feedController.feedState.value is Success
            ? ExpressiveRefreshIndicator(
                notificationPredicate: (notification) {
                  if (notification.depth != 0 ||
                      notification.metrics.axis != Axis.vertical) {
                    return false;
                  }
                  final double offset = notification.metrics.pixels;
                  _titleVisible.value = offset > 50;
                  return true;
                },
                refreshKey: _refreshKey,
                onRefresh: () async {
                  _feedController.onReset();
                  await _feedController.onGetData();
                },
                child: CustomScrollView(
                  key: PageStorageKey('feed-reading:$_id'),
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    if (wide)
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    _feedController.articleList.isNullOrEmpty
                        ? SliverToBoxAdapter(
                            child: _buildFeedContent(
                                _feedController.feedState.value))
                        : _buildFeedContent(_feedController.feedState.value),
                    _buildPinWidget(context),
                    _buildFeedReply(_feedController.loadingState.value),
                  ],
                ),
              )
            : Center(child: _buildFeedContent(_feedController.feedState.value)),
      ),
    );
  }
}
