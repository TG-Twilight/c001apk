import 'package:c001apk_flutter/components/network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/cards/icon_mini_scroll_card.dart' show miniCardItem;
import '../../components/html_text.dart';
import '../../components/markdown_body.dart';
import '../../components/icon_text.dart';
import '../../components/imageview.dart';
import '../../components/like_button.dart';
import '../../components/no_splash_factory.dart';
import '../feed_navigation.dart';
import '../reading_presentation.dart';
import '../content_filter_gate.dart';
import '../content_filter_text.dart';
import '../../logic/content_filter/content_filter_projection.dart';
import '../../logic/content_filter/content_filter_rule.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/media/feed_media_context.dart';
import '../../utils/date_util.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';
import '../../utils/storage_util.dart';
import '../../utils/utils.dart';
import '../../utils/markdown_content.dart';

class FeedCard extends StatelessWidget {
  const FeedCard({
    super.key,
    required this.data,
    this.isFeedContent = false,
    this.isHistory = false,
    this.onDelete,
    this.onBlock,
    this.onLike,
    this.forcePlain = false,
  });

  final Datum data;
  final bool isFeedContent;
  final bool isHistory;
  final bool forcePlain;
  final Function(dynamic id)? onDelete;
  final Function(dynamic uid)? onBlock;
  final Function(dynamic id, dynamic like)? onLike;

  void _onViewFeed(BuildContext context) {
    FeedNavigation.open(context, '${data.id}');
  }

  @override
  Widget build(BuildContext context) => ContentFilterGate(
      data: data, scope: FilterScope.feed, builder: _buildVisible);

  Widget _buildVisible(BuildContext context) {
    final compact = !isFeedContent && FeedNavigation.compactOf(context);
    return Material(
      shape:
          !isFeedContent && FeedNavigation.selectedOf(context) == '${data.id}'
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.primary, width: 2),
                )
              : null,
      color:
          isFeedContent ? null : Theme.of(context).colorScheme.onInverseSurface,
      borderRadius:
          isFeedContent || FeedNavigation.selectedOf(context) == '${data.id}'
              ? null
              : const BorderRadius.all(Radius.circular(12)),
      child: InkWell(
        highlightColor: isFeedContent ? Colors.transparent : null,
        splashColor: isFeedContent ? Colors.transparent : null,
        splashFactory: isFeedContent ? NoSplashFactory() : null,
        onTap: isFeedContent ? null : () => _onViewFeed(context),
        onLongPress: () => Get.toNamed('/copy',
            parameters: {'text': ContentFilterProjection.displayMessage(data)}),
        borderRadius: isFeedContent ? null : BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.only(bottom: isFeedContent ? 12 : 10),
          child: Column(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header(
                context,
                data,
                isFeedContent,
                isHistory: isHistory,
                onDelete: onDelete,
                onBlock: () {
                  if (onBlock != null) {
                    onBlock!(data.uid);
                  }
                },
              ),
              if (compact)
                _summary(context)
              else ...[
                ..._message(context),
                if (!data.picArr.isNullOrEmpty) _image(),
                if (!data.forwardSourceType.isNullOrEmpty)
                  _forwardSourceFeed(context),
                if (!data.extraUrl.isNullOrEmpty) _extraUrl(context),
                if (!data.replyRows.isNullOrEmpty) _hotReply(context),
              ],
              bottomInfo(
                  context, data, isFeedContent, () => _onViewFeed(context), () {
                if (onLike != null) {
                  onLike!(data.id, data.userAction?.like);
                }
              }),
              if (!compact &&
                  (data.targetRow != null || !data.relationRows.isNullOrEmpty))
                _rows(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final pictures = data.picArr ?? <String>[];
    final media = mediaGalleryArguments(pictures,
        mediaItems: mediaForDatum(data),
        contentId: data.id?.toString())['mediaItems'] as List<FeedMedia>;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!data.messageTitle.isNullOrEmpty)
          Text(Utils.parseHtmlString(data.messageTitle!),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ContentFilterText(
            key: ValueKey('feed-summary:${data.id}'),
            source: data.message ?? '',
            builder: (message) => Text(
                Utils.parseHtmlString(MarkdownContent.parse(message).preview),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.5))),
        if (pictures.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
                height: 72,
                child: Row(children: [
                  for (var i = 0; i < pictures.length && i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                        child: GestureDetector(
                      onTap: () => Get.toNamed('/imageview',
                          arguments: mediaGalleryArguments(pictures,
                              mediaItems: media,
                              contentId: data.id?.toString(),
                              initialPage: i)),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: mediaThumbnail(media[i],
                              width: double.infinity,
                              height: 72,
                              fit: BoxFit.cover)),
                    )),
                  ],
                ])),
          ),
      ]),
    );
  }

  Widget _image() {
    return Padding(
      padding: EdgeInsets.only(
        left: isFeedContent ? 16 : 10,
        top: 10,
        right: isFeedContent ? 16 : 10,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double maxWidth = constraints.maxWidth;
          return image(
            maxWidth,
            data.picArr!,
            mediaItems: mediaForDatum(data),
            contentId: data.id?.toString(),
          );
        },
      ),
    );
  }

  Widget _forwardSourceFeed(BuildContext context) {
    final source = data.forwardSourceFeed;
    if (source == null) return _forwardSourceVisible(context);
    return ContentFilterGate(
        data: source, scope: FilterScope.feed, builder: _forwardSourceVisible);
  }

  Widget _forwardSourceVisible(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: isFeedContent ? 16 : 10,
        top: 10,
        right: isFeedContent ? 16 : 10,
      ),
      child: Material(
        color: isFeedContent
            ? Theme.of(context).colorScheme.onInverseSurface
            : Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: InkWell(
          onTap: data.forwardSourceFeed != null
              ? () =>
                  FeedNavigation.open(context, '${data.forwardSourceFeed?.id}')
              : null,
          onLongPress: data.forwardSourceFeed != null
              ? () => Get.toNamed('/copy', parameters: {
                    'text': ContentFilterProjection.displayMessage(
                        data.forwardSourceFeed!)
                  })
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: data.forwardSourceFeed == null
                ? Text(
                    '动态已被删除',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!data
                          .forwardSourceFeed!.messageTitle.isNullOrEmpty) ...[
                        htmlText(
                            '<a class="feed-link-uname" href="/u/${data.forwardSourceFeed?.uid}">@${data.forwardSourceFeed?.username}</a>: ${data.forwardSourceFeed?.messageTitle}',
                            picArr: data.forwardSourceFeed!.picArr,
                            mediaItems: mediaForDatum(data.forwardSourceFeed!),
                            contentId: data.forwardSourceFeed!.id?.toString()),
                        ContentFilterText(
                            source: data.forwardSourceFeed!.message ?? '',
                            builder: (message) => FeedText(message,
                                preview: true,
                                picArr: data.forwardSourceFeed!.picArr,
                                mediaItems:
                                    mediaForDatum(data.forwardSourceFeed!),
                                contentId:
                                    data.forwardSourceFeed!.id?.toString())),
                      ],
                      if (data.forwardSourceFeed!.messageTitle.isNullOrEmpty)
                        ContentFilterText(
                            source: data.forwardSourceFeed!.message ?? '',
                            builder: (message) => FeedText(
                                '<a class="feed-link-uname" href="/u/${data.forwardSourceFeed?.uid}">@${data.forwardSourceFeed?.username}</a>:\n$message',
                                preview: true,
                                picArr: data.forwardSourceFeed!.picArr,
                                mediaItems:
                                    mediaForDatum(data.forwardSourceFeed!),
                                contentId:
                                    data.forwardSourceFeed!.id?.toString())),
                      if (!data.forwardSourceFeed!.picArr.isNullOrEmpty) ...[
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) => image(
                              constraints.maxWidth,
                              data.forwardSourceFeed!.picArr!,
                              mediaItems:
                                  mediaForDatum(data.forwardSourceFeed!),
                              contentId:
                                  data.forwardSourceFeed!.id?.toString()),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _extraUrl(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: isFeedContent ? 16 : 10,
        top: 10,
        right: isFeedContent ? 16 : 10,
      ),
      child: Material(
        color: isFeedContent
            ? Theme.of(context).colorScheme.onInverseSurface
            : Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: InkWell(
          onTap: () => Utils.onOpenLink(
              data.extraUrl!, data.extraTitle ?? '', true, context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                !data.extraPic.isNullOrEmpty
                    ? clipNetworkImage(
                        data.extraPic!,
                        radius: 8,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: Icon(
                          Icons.link_rounded,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.extraTitle.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        data.extraUrl.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hotReply(BuildContext context) {
    return ContentFilterGate(
        data: data.replyRows!.first,
        scope: FilterScope.comment,
        builder: _hotReplyVisible);
  }

  Widget _hotReplyVisible(BuildContext context) {
    var reply = data.replyRows![0];
    var replyPic = reply.picArr.isNullOrEmpty
        ? ''
        : ''' <a class="feed-forward-pic" href=${reply.pic}>查看图片(${reply.picArr!.length})</a>''';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 10, top: 10, right: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: InkWell(
          onTap: () => _onViewFeed(context),
          onLongPress: () => Get.toNamed('/copy', parameters: {
            'text': ContentFilterProjection.displayMessage(reply)
          }),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ContentFilterText(
                source: reply.message ?? '',
                builder: (message) => htmlText(
                      """<a class="feed-link-uname" href="/u/${reply.uid}">${reply.userInfo?.username}</a>: $message$replyPic""",
                      fontSize: 14,
                      onShowTotalReply: _onViewFeed,
                      picArr: reply.picArr,
                      mediaItems:
                          mediaForDatum(reply, type: MediaContentType.reply),
                      contentId: reply.id?.toString(),
                      contentType: MediaContentType.reply,
                    )),
          ),
        ),
      ),
    );
  }

  Widget _rows(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isFeedContent ? 16 : 10,
        top: 10,
        right: isFeedContent ? 16 : 10,
      ),
      child: Wrap(
        spacing: 5.0,
        runSpacing: 5.0,
        children: [
          if (data.targetRow != null)
            miniCardItem(
              context,
              data.targetRow!.logo!.orEmpty,
              data.targetRow!.title.orEmpty,
              data.targetRow!.url.orEmpty,
              isFeedContent ? false : true,
              false,
            ),
          if (!data.relationRows.isNullOrEmpty)
            ...data.relationRows!.map(
              (item) => miniCardItem(
                context,
                item.logo.orEmpty,
                item.title.orEmpty,
                item.url.orEmpty,
                isFeedContent ? false : true,
                false,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _message(BuildContext context) {
    final reading = isFeedContent && ReadingPresentation.of(context);
    return [
      if (!data.messageTitle.isNullOrEmpty)
        Padding(
          padding: EdgeInsets.only(
            left: isFeedContent ? 16 : 10,
            top: 5,
            right: isFeedContent ? 16 : 10,
          ),
          child: htmlText(
            data.messageTitle.orEmpty,
            fontSize: reading ? 28 : 16,
            isBold: true,
            picArr: data.picArr,
            mediaItems: mediaForDatum(data),
            contentId: data.id?.toString(),
          ),
        ),
      Padding(
        padding: EdgeInsets.only(
          left: isFeedContent ? 16 : 10,
          top: 5,
          right: isFeedContent ? 16 : 10,
        ),
        child: ContentFilterText(
            key: ValueKey('feed-message:${data.id}'),
            source: data.message.orEmpty,
            builder: (message) => FeedText(
                  message,
                  fontSize: reading ? 18 : 16,
                  lineHeight: reading ? 1.7 : 1.5,
                  preview: !isFeedContent,
                  forcePlain: forcePlain,
                  picArr: data.picArr,
                  mediaItems: mediaForDatum(data),
                  contentId: data.id?.toString(),
                )),
      )
    ];
  }
}

Widget header(
  BuildContext context,
  Datum data,
  bool isFeedContent, {
  bool isHeader = false,
  bool isHistory = false,
  Function(dynamic id)? onDelete,
  Function()? onBlock,
}) {
  return Row(
    children: [
      Flexible(
        flex: 1,
        child: Padding(
          padding: EdgeInsets.only(
            left: isHeader
                ? 0
                : isFeedContent
                    ? 16
                    : 10,
            top: isHeader
                ? 0
                : isFeedContent
                    ? 12
                    : 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Get.toNamed('/u/${data.uid}'),
                child: clipNetworkImage(
                  data.userAvatar.orEmpty,
                  radius: 50,
                  width: 35,
                  height: 35,
                  isAvatar: true,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.userInfo?.username ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isFeedContent || !data.infoHtml.isNullOrEmpty) ...[
                          Text(
                            isFeedContent
                                ? DateUtil.fromToday(data.dateline)
                                : Utils.parseHtmlString(data.infoHtml.orEmpty),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (!data.deviceTitle.isNullOrEmpty)
                          Flexible(
                            flex: 1,
                            child: IconText(
                              icon: Icons.smartphone,
                              text: Utils.parseHtmlString(
                                  data.deviceTitle.orEmpty),
                            ),
                          ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      if (!isFeedContent && data.isStickTop == 1)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            border: Border.all(
              width: 1.25,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: Text(
            '置顶',
            style: TextStyle(
              height: 1,
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
            strutStyle: const StrutStyle(
              leading: 0,
              height: 1,
              fontSize: 12,
            ),
          ),
        ),
      if (!isFeedContent)
        IconButton(
          onPressed: () => showModalBottomSheet(
            context: context,
            useRootNavigator: true,
            isScrollControlled: true,
            builder: (context) {
              return _MorePanel(
                id: data.id,
                uid: data.uid,
                isHistory: isHistory,
                onDelete: onDelete,
                onBlock: onBlock,
              );
            },
          ),
          icon: const Icon(Icons.keyboard_arrow_down),
          color: Theme.of(context).colorScheme.outline,
        ),
    ],
  );
}

Widget bottomInfo(
  BuildContext context,
  Datum data,
  bool isFeedContent,
  Function()? onViewFeed,
  Function()? onLike, {
  bool isFeedArticle = false,
}) {
  return Padding(
    padding: EdgeInsets.only(
      left: isFeedContent ? 16 : 10,
      top: isFeedArticle ? 0 : 10,
      right: isFeedContent ? 16 : 10,
    ),
    child: Row(
      children: [
        Expanded(
          flex: 1,
          child: Text(
            isFeedContent
                ? !data.ipLocation.isNullOrEmpty
                    ? '发布于 ${data.ipLocation}'
                    : ''
                : DateUtil.fromToday(data.dateline),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ),
        if (data.replynum != null)
          LikeButton(
            value: data.replynum,
            icon: Icons.message_outlined,
            // onClick: () {
            //   // todo
            //   SmartDialog.showToast('${data.replynum}');
            // },
          ),
        if (data.likenum != null)
          LikeButton(
            value: data.likenum,
            icon: data.userAction?.like == 1
                ? Icons.thumb_up
                : Icons.thumb_up_alt_outlined,
            isLike: data.userAction?.like == 1,
            onClick: () {
              if (GlobalData().isLogin && onLike != null) {
                onLike();
              }
            },
          ),
      ],
    ),
  );
}

enum PanelAction { copy, block, report, delete }

class _MorePanel extends StatelessWidget {
  const _MorePanel({
    required this.id,
    required this.uid,
    required this.isHistory,
    required this.onDelete,
    required this.onBlock,
  });

  final dynamic id;
  final dynamic uid;
  final bool isHistory;
  final Function(dynamic id)? onDelete;
  final Function()? onBlock;

  Future<dynamic> menuActionHandler(PanelAction type) async {
    switch (type) {
      case PanelAction.copy:
        Utils.copyText('https://www.coolapk.com/feed/$id');
        Get.back();
        break;
      case PanelAction.block:
        Get.back();
        GStorage.onBlock(uid);
        if (onBlock != null) {
          onBlock!();
        }
        break;
      case PanelAction.report:
        Get.back();
        Utils.report(id, ReportType.Feed);
        break;
      case PanelAction.delete:
        Get.back();
        if (onDelete != null) {
          onDelete!(id);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            onTap: () => Get.back(),
            child: Container(
              alignment: Alignment.center,
              height: 35,
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          ListTile(
            onTap: () async => await menuActionHandler(PanelAction.copy),
            minLeadingWidth: 0,
            leading: const Icon(Icons.copy_outlined, size: 19),
            title: Text('复制', style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            onTap: () async => await menuActionHandler(PanelAction.block),
            minLeadingWidth: 0,
            leading: const Icon(Icons.block, size: 19),
            title: Text('屏蔽', style: Theme.of(context).textTheme.titleSmall),
          ),
          if (Utils.isSupportWebview())
            ListTile(
              onTap: () async => await menuActionHandler(PanelAction.report),
              minLeadingWidth: 0,
              leading: const Icon(Icons.error_outline, size: 19),
              title: Text('举报', style: Theme.of(context).textTheme.titleSmall),
            ),
          if (isHistory || uid.toString() == GlobalData().uid)
            ListTile(
              onTap: () async => await menuActionHandler(PanelAction.delete),
              minLeadingWidth: 0,
              leading: const Icon(Icons.delete_outline, size: 19),
              title: Text('删除', style: Theme.of(context).textTheme.titleSmall),
            ),
        ],
      ),
    );
  }
}
