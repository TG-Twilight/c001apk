import 'package:c001apk_flutter/components/network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../../components/html_text.dart';
import '../content_filter_gate.dart';
import '../content_filter_text.dart';
import '../../logic/content_filter/content_filter_projection.dart';
import '../../logic/content_filter/content_filter_rule.dart';
import '../../components/imageview.dart';
import '../../components/like_button.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/media/feed_media_context.dart';
import '../../pages/feed/reply2reply/reply_2_reply_page.dart';
import '../../utils/date_util.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';
import '../../utils/storage_util.dart';
import '../../utils/utils.dart';

class FeedReplyCard extends StatelessWidget {
  const FeedReplyCard({
    super.key,
    required this.data,
    this.isReply2Reply = false,
    this.isTopReply = false,
    this.uid,
    this.onBlock,
    this.onReply,
    this.onDelete,
    this.onLike,
    this.onToggleTop,
    this.isPinned,
  });

  final Datum data;
  final bool isReply2Reply;
  final bool isTopReply;
  final dynamic uid;
  final Function(dynamic uid, dynamic id)? onBlock;
  final Function(dynamic id, dynamic uname, dynamic fid)? onReply;
  final Function(dynamic id, dynamic fid)? onDelete;
  final Function(dynamic id, dynamic like)? onLike;

  /// Feed author only: pins or unpins this top-level reply.
  final Future<void> Function(Datum reply)? onToggleTop;

  /// Whether the server currently pins this reply, independent of sort order.
  final bool? isPinned;

  @override
  Widget build(BuildContext context) => ContentFilterGate(
        data: data,
        scope: FilterScope.comment,
        builder: _buildVisible,
        hiddenChildren: !isReply2Reply &&
                (!data.replyRows.isNullOrEmpty || (data.replyRowsMore ?? 0) > 0)
            ? _replyRows
            : null,
      );

  Widget _buildVisible(BuildContext context) {
    final isFeedReply = data.fetchType == 'feed_reply';
    return Material(
      color: !isFeedReply || (isReply2Reply && !isTopReply)
          ? Theme.of(context).colorScheme.onInverseSurface
          : Colors.transparent,
      borderRadius:
          !isFeedReply ? const BorderRadius.all(Radius.circular(12)) : null,
      child: InkWell(
        onTap: () {
          if (isFeedReply && onReply != null) {
            onReply!(
              data.id,
              data.userInfo?.username,
              null,
            );
          } else {
            Utils.onOpenLink(data.url ?? '');
          }
        },
        onLongPress: () {
          Get.toNamed('/copy', parameters: {
            'text': ContentFilterProjection.displayMessage(data)
          });
        },
        borderRadius:
            !isFeedReply ? const BorderRadius.all(Radius.circular(12)) : null,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                  onPressed: () => showModalBottomSheet(
                        context: context,
                        useRootNavigator: true,
                        isScrollControlled: true,
                        builder: (context) {
                          return _MorePanel(
                            id: data.id,
                            uid: data.uid,
                            reply: data..fetchType = 'feed_reply',
                            onBlock: onBlock != null
                                ? () => onBlock!(data.uid, null)
                                : null,
                            onDelete: onDelete != null
                                ? () => onDelete!(data.id, null)
                                : null,
                            isTop: isPinned ?? isTopReply,
                            onToggleTop: !isReply2Reply && onToggleTop != null
                                ? () => onToggleTop!(data)
                                : null,
                          );
                        },
                      ),
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: Theme.of(context).colorScheme.outline,
                  )),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: !isFeedReply ? 10 : 16,
                vertical: !isFeedReply ? 10 : 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Get.toNamed('/u/${data.uid}'),
                    child: clipNetworkImage(
                      data.userAvatar ?? '',
                      isAvatar: true,
                      height: 30,
                      width: 30,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _username(),
                        ContentFilterText(
                            key: ValueKey('reply-message:${data.id}'),
                            source: data.message ?? '',
                            builder: (message) => htmlText(message,
                                picArr: data.picArr,
                                contentId: data.id?.toString(),
                                contentType: MediaContentType.reply,
                                mediaItems: mediaForDatum(data,
                                    type: MediaContentType.reply))),
                        if (!data.picArr.isNullOrEmpty) ...[
                          const SizedBox(height: 10),
                          _image(),
                        ],
                        if (!isFeedReply &&
                            data.feed != null &&
                            !isReply2Reply) ...[
                          const SizedBox(height: 10),
                          _feed(context),
                        ],
                        const SizedBox(height: 10),
                        _bottomInfo(context),
                        if (!isReply2Reply &&
                            (!data.replyRows.isNullOrEmpty ||
                                (data.replyRowsMore ?? 0) != 0)) ...[
                          const SizedBox(height: 10),
                          _replyRows(context),
                        ],
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;
        return image(
          maxWidth,
          data.picArr!,
          mediaItems: mediaForDatum(data, type: MediaContentType.reply),
          contentId: data.id?.toString(),
          contentType: MediaContentType.reply,
        );
      },
    );
  }

  Widget _username() {
    return Padding(
      padding: const EdgeInsets.only(right: 15),
      child: htmlText(
        !isReply2Reply
            ? '${data.userInfo?.username}${data.uid == data.feedUid ? ' [楼主]' : ''}${!isReply2Reply && isTopReply ? ' [置顶]' : ''}'
            : () {
                String replyTag = data.uid == data.feedUid
                    ? ' [楼主] '
                    : data.uid == uid && !isTopReply
                        ? ' [层主] '
                        : '';
                if (isTopReply) {
                  return '<a class="feed-link-uname" href="/u/${data.uid}">${data.userInfo?.username}$replyTag</a>';
                }
                String rReplyTag = data.ruid == data.feedUid
                    ? ' [楼主] '
                    : data.ruid == uid
                        ? ' [层主] '
                        : '';
                return data.ruid == 0
                    ? '<a class="feed-link-uname" href="/u/${data.uid}">${data.userInfo?.username}$replyTag</a>'
                    : '<a class="feed-link-uname" href="/u/${data.uid}">${data.userInfo?.username}$replyTag</a>回复<a class="feed-link-uname" href="/u/${data.rusername}">${data.rusername}$rReplyTag</a>';
              }(),
      ),
    );
  }

  Widget _feed(BuildContext context) {
    Datum feed = Datum.fromJson(data.feed);
    return ContentFilterGate(
        data: feed,
        scope: FilterScope.feed,
        builder: (context) => _feedVisible(context, feed));
  }

  Widget _feedVisible(BuildContext context, Datum feed) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: InkWell(
        onTap: () => Utils.onOpenLink(feed.url ?? ''),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (!feed.pic.isNullOrEmpty) ...[
                clipNetworkImage(
                  feed.pic!,
                  radius: 8,
                  fit: BoxFit.cover,
                  width: 40,
                  height: 40,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${feed.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    ContentFilterText(
                        source: feed.message ?? '',
                        builder: (message) => Text(
                              Utils.parseHtmlString(message),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.outline),
                            )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _replyRows(BuildContext context) {
    return Material(
      clipBehavior: Clip.hardEdge,
      color: Theme.of(context).colorScheme.onInverseSurface,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...(data.replyRows ?? <Datum>[])
              .map((item) => _replyRowsItem(context, item)),
          if (data.replyRowsMore != null && data.replyRowsMore! > 0)
            InkWell(
              onTap: () {
                showCupertinoModalBottomSheet(
                  context: context,
                  builder: (context) {
                    return Reply2ReplyPage(
                        id: data.id.toString(),
                        replynum: data.replynum,
                        originReply: data);
                  },
                );
              },
              child: Container(
                width: double.infinity,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '查看更多回复(${data.replynum})',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _replyRowsItem(BuildContext context, Datum reply) {
    return ContentFilterGate(
        data: reply,
        scope: FilterScope.comment,
        builder: (context) => _replyRowsItemVisible(context, reply));
  }

  Widget _replyRowsItemVisible(BuildContext context, Datum reply) {
    return InkWell(
      onTap: () {
        if (onReply != null) {
          onReply!(
            reply.id,
            reply.userInfo?.username,
            data.id,
          );
        }
      },
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          builder: (context) {
            return _MorePanel(
              id: reply.id,
              uid: reply.uid,
              message: ContentFilterProjection.displayMessage(reply),
              fid: data.id,
              reply: reply,
              onBlock:
                  onBlock != null ? () => onBlock!(reply.uid, data.id) : null,
              onDelete:
                  onDelete != null ? () => onDelete!(reply.id, data.id) : null,
            );
          },
        );
      },
      child: Container(
        width: double.infinity,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ContentFilterText(
            source: reply.message ?? '',
            builder: (message) => htmlText(
                  () {
                    String replyTag = reply.uid == data.feedUid
                        ? ' [楼主] '
                        : reply.uid == data.uid
                            ? ' [层主] '
                            : '';
                    String rReplyTag = reply.ruid == data.feedUid
                        ? ' [楼主] '
                        : reply.ruid == data.uid
                            ? ' [层主] '
                            : '';
                    String rReplyUser = reply.ruid == data.uid
                        ? ''
                        : '<a class="feed-link-uname" href="/u/${reply.ruid}">${reply.rusername}$rReplyTag</a>';
                    String replyPic = reply.picArr.isNullOrEmpty
                        ? ''
                        : ' <a class="feed-forward-pic" href=${reply.pic}>查看图片(${reply.picArr!.length})</a>';
                    return '<a class="feed-link-uname" href="/u/${reply.uid}">${reply.userInfo?.username}$replyTag</a>回复$rReplyUser: $message$replyPic';
                  }(),
                  fontSize: 14,
                  onShowTotalReply: () => showCupertinoModalBottomSheet(
                    context: context,
                    builder: (context) {
                      return Reply2ReplyPage(
                        id: data.id.toString(),
                        replynum: data.replynum,
                        originReply: data,
                      );
                    },
                  ),
                  picArr: reply.picArr,
                  mediaItems:
                      mediaForDatum(reply, type: MediaContentType.reply),
                  contentId: reply.id?.toString(),
                  contentType: MediaContentType.reply,
                )),
      ),
    );
  }

  Widget _bottomInfo(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Text(
            DateUtil.fromToday(data.dateline),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ),
        LikeButton(
          value: data.replynum,
          icon: Icons.message_outlined,
        ),
        LikeButton(
          value: data.likenum,
          icon: data.userAction?.like == 1
              ? Icons.thumb_up
              : Icons.thumb_up_alt_outlined,
          isLike: data.userAction?.like == 1,
          onClick: () {
            if (GlobalData().isLogin && onLike != null) {
              onLike!(data.id, data.userAction?.like);
            }
          },
        ),
      ],
    );
  }
}

enum PanelAction { copy, block, delete, report, showReply, top }

class _MorePanel extends StatelessWidget {
  const _MorePanel({
    required this.id,
    required this.uid,
    this.message,
    this.fid,
    this.reply,
    this.onBlock,
    this.onDelete,
    this.isTop = false,
    this.onToggleTop,
  });

  final dynamic id;
  final dynamic uid;
  final String? message;
  final dynamic fid;
  final Datum? reply;
  final Function()? onBlock;
  final Function()? onDelete;
  final bool isTop;
  final Function()? onToggleTop;

  Future<dynamic> menuActionHandler(PanelAction type,
      {BuildContext? context, dynamic rid, dynamic frid}) async {
    switch (type) {
      case PanelAction.copy:
        Get.back();
        Get.toNamed('/copy', parameters: {'text': message.toString()});
        break;
      case PanelAction.block:
        Get.back();
        GStorage.onBlock(uid);
        if (onBlock != null) {
          onBlock!();
        }
        break;
      case PanelAction.delete:
        Get.back();
        if (onDelete != null) {
          onDelete!();
        }
        break;
      case PanelAction.top:
        Get.back();
        onToggleTop?.call();
        break;
      case PanelAction.report:
        Get.back();
        Utils.report(id, ReportType.Reply);
        break;
      case PanelAction.showReply:
        Get.back();
        showCupertinoModalBottomSheet(
          context: context!,
          builder: (context) {
            return Reply2ReplyPage(
                id: id.toString(),
                replynum: reply!.replynum,
                originReply: reply!);
          },
        );
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
          if (message != null)
            ListTile(
              onTap: () async => await menuActionHandler(PanelAction.copy),
              minLeadingWidth: 0,
              leading: const Icon(Icons.copy, size: 19),
              title: Text('复制', style: Theme.of(context).textTheme.titleSmall),
            ),
          if (onToggleTop != null)
            ListTile(
              onTap: () async => await menuActionHandler(PanelAction.top),
              minLeadingWidth: 0,
              leading: Icon(
                  isTop ? Icons.vertical_align_bottom : Icons.vertical_align_top,
                  size: 19),
              title: Text(isTop ? '取消置顶' : '置顶',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
          ListTile(
            onTap: () async => await menuActionHandler(PanelAction.block),
            minLeadingWidth: 0,
            leading: const Icon(Icons.block, size: 19),
            title: Text('屏蔽', style: Theme.of(context).textTheme.titleSmall),
          ),
          if (uid.toString() == GlobalData().uid)
            ListTile(
              onTap: () async => await menuActionHandler(PanelAction.delete),
              minLeadingWidth: 0,
              leading: const Icon(Icons.delete_outline, size: 19),
              title: Text('删除', style: Theme.of(context).textTheme.titleSmall),
            ),
          if (Utils.isSupportWebview())
            ListTile(
              onTap: () async => await menuActionHandler(PanelAction.report),
              minLeadingWidth: 0,
              leading: const Icon(Icons.error_outline, size: 19),
              title: Text('举报', style: Theme.of(context).textTheme.titleSmall),
            ),
          ListTile(
            onTap: () async => await menuActionHandler(PanelAction.showReply,
                context: context, rid: id, frid: fid),
            minLeadingWidth: 0,
            leading: const Icon(Icons.message_outlined, size: 19),
            title: Text('查看回复', style: Theme.of(context).textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}
