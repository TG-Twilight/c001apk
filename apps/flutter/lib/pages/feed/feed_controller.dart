import 'dart:convert';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

import '../../logic/model/fav_history/fav_history.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/model/feed/user_action.dart';
import '../../logic/model/feed_article/feed_article.dart';
import '../../logic/network/network_repo.dart';
import '../../logic/network/api_failure.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/common/common_controller.dart';
import '../../pages/feed/feed_page.dart' show ReplySortType;
import '../../utils/extensions.dart';
import '../../utils/storage_util.dart';

class FeedController extends CommonController {
  FeedController({required this.id, required this.recordHistory});
  final String id;
  final bool recordHistory;

  String listType = 'lastupdate_desc';
  final int _discussMode = 1;
  final String _feedType = 'feed';
  final int _blockStatus = 0;
  int fromFeedAuthor = 0;

  String? feedTypeName;
  int? feedUid;
  String? feedUsername;
  int? replyNum;

  List<FeedArticle>? articleList;
  List<String>? articleImgList;

  Datum? topReply;
  Datum? _replyMe;

  /// Coin-only replies stay folded until the reader expands them on this page.
  final showCoinReplies = false.obs;
  bool _updatingReplyTop = false;

  Rx<LoadingState> feedState = LoadingState.loading().obs;
  final accountDetailNotice = ''.obs;
  final isLoadingDetail = false.obs;
  bool isFav = false;
  bool isBlocked = false;

  Rx<ReplySortType> replySelection = ReplySortType.def.obs;
  final repliesDeferred = GStorage.szlmId.trim().isEmpty.obs;

  @override
  Future<void> onGetData([bool isRefresh = true]) async {
    // All automatic paths (detail, refresh, sort and pagination) share this
    // gate. Only the comment section's explicit action opts into verification.
    if (repliesDeferred.value) return;
    await super.onGetData(isRefresh);
    final result = isRefresh ? loadingState.value : footerState.value;
    if (result is Error && GStorage.szlmId.trim().isEmpty) {
      repliesDeferred.value = true;
    }
  }

  @override
  void onReset() {
    if (repliesDeferred.value) return;
    super.onReset();
  }

  Future<void> loadReplies() async {
    if (isLoading) return;
    repliesDeferred.value = false;
    onReset();
    setLoadingState(LoadingState.loading());
    await onGetData();
  }

  void setFeedState(LoadingState feedState) {
    this.feedState.value = feedState;
  }

  @override
  Future<LoadingState> customGetData() {
    return NetworkRepo.getFeedReply(
      id: id,
      listType: listType,
      page: page,
      firstItem: firstItem,
      lastItem: lastItem,
      discussMode: _discussMode,
      feedType: _feedType,
      blockStatus: _blockStatus,
      fromFeedAuthor: fromFeedAuthor,
    );
  }

  Future<void> getFeedData({bool verify = false}) async {
    if (isLoadingDetail.value) return;
    final previous = feedState.value;
    isLoadingDetail.value = true;
    try {
      await _loadFeedData(verify: verify);
      final result = feedState.value;
      if (verify && result is! Success) {
        accountDetailNotice.value =
            result is Error ? result.errMsg : '账号详情暂不可用，请稍后重试';
        if (previous is Success) feedState.value = previous;
      } else if (result is Success) {
        accountDetailNotice.value =
            result.isPublic ? '正文可正常阅读，当前账号的点赞状态暂不可用。' : '';
      }
    } finally {
      isLoadingDetail.value = false;
    }
  }

  Future<void> _loadFeedData({required bool verify}) async {
    LoadingState<dynamic> response =
        await NetworkRepo.getFeedDetail(id: id, verify: verify);
    if (response is Success) {
      Datum data = (response.response as Datum);
      List<FeedArticle> nextArticles = [];
      List<String> nextImages = [];
      try {
        if (!data.messageRawOutput.isNullOrEmpty &&
            data.messageRawOutput != 'null') {
          List<dynamic> jsonList = jsonDecode(data.messageRawOutput!);
          nextArticles = jsonList
              .map((json) => FeedArticle.fromJson(json))
              .where(
                  (item) => ['text', 'image', 'shareUrl'].contains(item.type))
              .toList();
        }
      } catch (error) {
        feedState.value =
            LoadingState.error(ApiFailure.fromError(error).message);
        return;
      }
      // A public normal feed also has a summary title. Only attach article
      // decoration when there is structured body content to render.
      if (nextArticles.isNotEmpty) {
        if (!data.title.isNullOrEmpty) {
          nextArticles.insert(0, FeedArticle(type: 'title', title: data.title));
        }
        if (!data.messageCover.isNullOrEmpty) {
          nextArticles.insert(
              0, FeedArticle(type: 'image', url: data.messageCover));
        }
        nextImages = nextArticles
            .where((item) => item.type == 'image')
            .map((item) => item.url.orEmpty)
            .toList();
      }
      articleList = nextArticles;
      articleImgList = nextImages;
      topReply = data.topReplyRows?.firstOrNull;
      _replyMe = data.replyMeRows?.firstOrNull;
      feedUsername = data.userInfo?.username;
      feedUid = data.uid;
      feedTypeName = data.feedTypeName;
      replyNum = data.replynum;
      onGetData();

      isFav = GStorage.checkFav(id);
      isBlocked = GStorage.checkUser(feedUid.toString());
      // todo: check
      if (recordHistory && !GStorage.checkHistory(id)) {
        GStorage.historyFeed.put(id, getFeed(data));
      }
    }
    feedState.value = response;
  }

  void onFav() {
    Datum data = (feedState.value as Success).response;
    GStorage.favFeed.put(id, getFeed(data));
  }

  FavHistoryItem getFeed(Datum data) {
    return FavHistoryItem(
      id: data.id.toString(),
      uid: data.uid.toString(),
      username: data.userInfo?.username,
      userAvatar: data.userInfo?.userAvatar,
      message: (data.message ?? '').length <= 150
          ? data.message
          : data.message!.substring(0, 150),
      device: data.deviceTitle,
      dateline: data.dateline.toString(),
      time: DateTime.now().microsecondsSinceEpoch,
    );
  }

  @override
  void onInit() {
    super.onInit();
    getFeedData();
  }

  void onBlockReply(dynamic uid, dynamic id) {
    reapplyFilters();
  }

  @override
  List<Datum>? handleResponse(List<Datum> dataList) {
    List<Datum> filterList = dataList;
    if (page == 1 && listType == 'lastupdate_desc') {
      filterList = [
            if (topReply != null) topReply!,
            if (_replyMe != null) _replyMe!,
          ] +
          filterList;
    }
    for (final item in filterList) {
      item.entityType ??= 'feed_reply';
    }
    return filterList;
  }

  bool isPinnedReply(Datum reply) =>
      listType == 'lastupdate_desc' &&
      topReply != null &&
      topReply!.id == reply.id;

  /// Pins [reply] (or unpins it when already pinned). The server keeps one
  /// pinned reply per feed, so pinning replaces any previous one.
  Future<void> toggleReplyTop(Datum reply) async {
    if (_updatingReplyTop) return;
    _updatingReplyTop = true;
    final cancel = topReply?.id == reply.id;
    try {
      final response = await NetworkRepo.postReplyTop(
          feedId: id, replyId: cancel ? null : reply.id);
      final body = readApiObject(response, allowSuccessWithoutData: true);
      List<Datum> replyList = [...rawItems];
      if (cancel) {
        topReply = null;
      } else {
        topReply = reply;
        replyList = replyList.where((item) => item.id != reply.id).toList();
        if (listType == 'lastupdate_desc') replyList.insert(0, reply);
      }
      publishItems(replyList);
      final receipt = body['data'];
      SmartDialog.showToast(receipt is String && receipt.trim().isNotEmpty
          ? receipt
          : cancel
              ? '已取消置顶'
              : '已置顶');
    } catch (e) {
      SmartDialog.showToast(ApiFailure.fromError(e).message);
    } finally {
      _updatingReplyTop = false;
    }
  }

  void updateReply(bool isReply, Datum data, dynamic id, dynamic fid) {
    List<Datum> replyList = [...rawItems];
    if (isReply) {
      replyList = replyList.map((reply) {
        if (reply.id == (fid ?? id)) {
          return reply..replyRows = (reply.replyRows ?? []) + [data];
        } else {
          return reply;
        }
      }).toList();
    } else {
      replyList.insert(topReply == null ? 0 : 1, data);
    }
    publishItems(replyList);
  }

  @override
  bool handleLike(dynamic like, dynamic likenum) {
    Datum data = (feedState.value as Success).response;
    final isPublic = (feedState.value as Success).isPublic;
    feedState.value = Success(
        data
          ..likenum = likenum
          ..userAction = UserAction(like: like == 1 ? 0 : 1),
        isPublic: isPublic);
    return true;
  }
}
