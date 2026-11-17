import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData;

import '../../constants/constants.dart';
import '../../logic/model/feed/data_list_model.dart';
import '../../logic/model/feed/data_model.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/network/api.dart';
import '../../logic/network/api_failure.dart';
import '../../logic/network/request.dart';
import '../../logic/state/loading_state.dart';
import '../../utils/extensions.dart';
import '../../utils/storage_util.dart';
import '../../utils/token_util.dart';

class NetworkRepo {
  static void requireMessageMutation(Response response) {
    final data = readApiObject(response)['data'];
    final count = data is Map ? data['count'] : data;
    if (count == null || count == false || count.toString().trim().isEmpty) {
      throw const ApiFailure(
          ApiFailureKind.invalidResponse, '服务端未确认操作结果，请刷新后查看');
    }
  }

  static Future<LoadingState<Map<String, dynamic>>> getEventDetail(
      String id) async {
    if (!RegExp(r'^[0-9]+$').hasMatch(id)) {
      return LoadingState.error('活动编号无效');
    }
    try {
      final response = await Request().get(
        Api.getDataFromUrl('/v6/event/detail'),
        queryParameters: {'id': id},
      );
      final data = readApiObject(response)['data'];
      if (data == null) return LoadingState.empty();
      if (data is! Map<String, dynamic> || data['title'] is! String) {
        throw const ApiFailure(ApiFailureKind.parsing, '活动数据格式异常，请稍后重试');
      }
      return LoadingState.success(data);
    } catch (error) {
      return LoadingState.error(ApiFailure.fromError(error).message);
    }
  }

  static Future<Response> postOSSUploadPrepare({
    required FormData data,
  }) async {
    return Request().post(Api.getDataFromUrl('/v6/upload/ossUploadPrepare'),
        data: data,
        options: Options(contentType: Headers.multipartFormDataContentType));
  }

  static Future<Response> sendMessage({
    required dynamic uid,
    required FormData data,
  }) async {
    return Request().post(
      Api.getDataFromUrl('/v6/message/send'),
      queryParameters: {
        'uid': uid,
      },
      data: data,
      options: Options(
          contentType: Headers.multipartFormDataContentType,
          extra: {'silentError': true}),
    );
  }

  static Future<Response> getImageUrl({
    required dynamic id,
  }) async {
    return Request().get(
      Api.getDataFromUrl('/v6/message/showImage'),
      queryParameters: {
        'id': id,
        'type': 's',
      },
      options: Options(followRedirects: false),
    );
  }

  static Future<Response> deleteMsg(
    String url, {
    dynamic ukey,
    dynamic id,
  }) async {
    return Request().get(
      Api.getDataFromUrl(url),
      queryParameters: {
        if (ukey != null) 'ukey': ukey,
        if (id != null) 'id': id,
      },
    );
  }

  static Future<LoadingState> messageOperation(
    String url, {
    String? ukey,
    String? uid,
    int? page,
    dynamic firstItem,
    dynamic lastItem,
  }) async {
    return getListData(
      () => Request().get(
        Api.getDataFromUrl(url),
        queryParameters: {
          if (ukey != null) 'ukey': ukey,
          if (uid != null) 'uid': uid,
          if (page != null) 'page': page,
          if (firstItem != null) 'firstItem': firstItem,
          if (lastItem != null) 'lastItem': lastItem,
        },
      ),
    );
  }

  static Future<Response> getFollow(
    String url, {
    String? tag,
    String? id,
  }) async {
    return Request().get(
      Api.getDataFromUrl(url),
      queryParameters: {
        if (tag != null) 'tag': tag,
        if (id != null) 'id': id,
      },
    );
  }

  /// Feed author pins or unpins one top-level reply. Mirrors the official
  /// client: form-encoded POST, replyId+feedId to pin, feedId alone to unpin
  /// (a feed holds at most one pinned reply).
  static Future<Response> postReplyTop({
    required String feedId,
    dynamic replyId,
  }) {
    final pin = replyId != null;
    return Request().post(
      Api.getDataFromUrl(pin
          ? '/v6/feed/addReplyTopToFeed'
          : '/v6/feed/cancelReplyTopFromFeed'),
      data: {
        if (pin) 'replyId': '$replyId',
        'feedId': feedId,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
  }

  static Future<Response> postLikeDeleteFollow(
    String url, {
    dynamic id,
    dynamic uid,
    FormData? data,
  }) async {
    final isLike = [
      '/v6/feed/like',
      '/v6/feed/unlike',
      '/v6/feed/likeReply',
      '/v6/feed/unLikeReply'
    ].contains(url);
    return Request().post(
      Api.getDataFromUrl(url),
      queryParameters: {
        if (id != null) 'id': id,
        if (uid != null) 'uid': uid,
        if (isLike) 'detail': 0,
      },
      data: isLike ? {'trace': ''} : data,
      options: isLike
          ? Options(contentType: Headers.formUrlEncodedContentType)
          : null,
    );
  }

  static Future<Response> postRequestValidate(
    FormData data,
  ) async {
    return Request().post(
      Api.postRequestValidate,
      data: data,
    );
  }

  static Future<Response> getValidateCaptcha() async {
    return Request().get(
      '${Constants.URL_API_SERVICE}/v6/account/captchaImage',
      queryParameters: {
        '_': DateTime.now().millisecondsSinceEpoch,
        'w': 270,
        'h': 113,
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  static Future<Response> postCreateFeed(
    FormData data,
  ) async {
    final body = Map<String, dynamic>.fromEntries(data.fields);
    body['publish_status'] ??= body['status'] == '-1' ? '1' : '0';
    body['status'] = '1';
    final multipart = data.clone();
    multipart.fields
      ..clear()
      ..addAll(body.entries.map((e) => MapEntry(e.key, e.value.toString())));
    return Request().post(
      Api.postCreateFeed,
      data: data.files.isEmpty ? body : multipart,
      options: data.files.isEmpty
          ? Options(contentType: Headers.formUrlEncodedContentType)
          : null,
    );
  }

  static Future<Response> postReply(
    FormData data,
    dynamic id,
    String type,
  ) async {
    return Request().post(
      Api.postReply,
      data: data.files.isEmpty
          ? Map<String, dynamic>.fromEntries(data.fields)
          : data,
      options: data.files.isEmpty
          ? Options(contentType: Headers.formUrlEncodedContentType)
          : null,
      queryParameters: {'id': id, 'type': type},
    );
  }

  static Future<Response> checkCount() async {
    return Request().get(Api.checkCount);
  }

  static Future<Response> getProfile(String uid) async {
    return Request().get(Api.getProfile,
        queryParameters: {'uid': uid},
        options: Options(extra: {'skipCaptcha': true}));
  }

  static Future<Response> onLogin(
    String requestHash,
    String account,
    String pwd,
    String captcha,
  ) async {
    return Request().post(Api.onLogin,
        data: {
          'submit': '1',
          'randomNumber': TokenUtils.createRandomNumber(),
          'requestHash': requestHash,
          'login': account,
          'password': pwd,
          'captcha': captcha,
          'code': '',
        },
        options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.plain));
  }

  static Future<Response> getLoginParam(String url, [Options? options]) async {
    return Request().get(Api.getLoginParam(url), options: options);
  }

  static Future<LoadingState> getReply2Reply({
    required String id,
    required int page,
    required String? firstItem,
    required String? lastItem,
  }) async {
    return getListData(
      () => Request().get(Api.getReply2Reply, queryParameters: {
        'id': id,
        'page': page,
        'listType': '',
        'discussMode': 0,
        'feedType': 'feed_reply',
        'blockStatus': 0,
        'fromFeedAuthor': 0,
        if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
        if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
      }),
    );
  }

  static Future<LoadingState> getCoolPic({
    required String tag,
    required String type,
    required int page,
    required String? firstItem,
    required String? lastItem,
  }) async {
    return getListData(
      () => Request().get(Api.getCoolPic, queryParameters: {
        'tag': tag,
        'type': type,
        'page': page,
        if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
        if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
      }),
    );
  }

  static Future<LoadingState> getDyhDetail({
    required String dyhId,
    required String type,
    required int page,
    required String? firstItem,
    required String? lastItem,
  }) async {
    return getListData(
      () => Request().get(Api.getDyhDetail, queryParameters: {
        'dyhId': dyhId,
        'type': type,
        'page': page,
        if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
        if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
      }),
    );
  }

  static Future<Response> getAppsUpdate(
    String pkgs,
  ) async {
    return Request().post(
      Api.getAppsUpdate,
      queryParameters: {'coolmarket_beta': '0'},
      data: FormData.fromMap({
        'pkgs': pkgs,
      }),
    );
  }

  static Future<Response> checkLoginInfo() async {
    return Request().get(Api.checkLoginInfo,
        options: Options(extra: {'skipCaptcha': true}));
  }

  static Future<LoadingState> getSearch({
    required String type,
    required String feedType,
    required String sort,
    required String searchValue,
    required int isStrict,
    required String? pageType,
    required String? pageParam,
    required int page,
    required String? firstItem,
    required String? lastItem,
  }) async {
    return getListData(
      () => Request().get(Api.getSearch, queryParameters: {
        'type': type,
        'feedType': feedType,
        'sort': sort,
        'searchValue': searchValue,
        'isStrict': isStrict,
        if (!pageType.isNullOrEmpty) 'pageType': pageType,
        if (!pageParam.isNullOrEmpty) 'pageParam': pageParam,
        'page': page,
        if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
        if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
        'showAnonymous': -1,
      }),
    );
  }

  static Future<Response> getAppDownloadUrl({
    required String packageName,
    required int id,
    required int versionCode,
  }) async {
    return Request().get(
      Api.getAppDownloadUrl,
      queryParameters: {
        'pn': packageName,
        'aid': id,
        'vc': versionCode,
        'extra': '',
      },
      options: Options(followRedirects: false),
    );
  }

  static Future<LoadingState> getAppInfo({
    required String id,
  }) async {
    return getData(
      () => Request().get(Api.getAppInfo, queryParameters: {
        'id': id,
        'installed': 1,
      }),
    );
  }

  static Future<LoadingState> getUserFeed({
    required String uid,
    required int page,
    required String? firstItem,
    required String? lastItem,
    bool includeTop = true,
  }) async {
    return getListData(
      () => Request().get(Api.getUserFeed, queryParameters: {
        'uid': uid,
        'page': page,
        if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
        if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
        'showAnonymous': 0,
        'isIncludeTop': includeTop ? 1 : 0,
        'showDoing': 0,
      }),
    );
  }

  static Future<LoadingState> getFeedReply({
    required String id,
    required String listType,
    required int page,
    required String? firstItem,
    required String? lastItem,
    required int discussMode,
    required String feedType,
    required int blockStatus,
    required int fromFeedAuthor,
    bool verify = true,
  }) async {
    return getListData(
      () => Request().get(Api.getFeedReply,
          options: Options(extra: {'skipCaptcha': !verify}),
          queryParameters: {
            'id': id,
            'listType': listType,
            'page': page,
            if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
            if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
            'discussMode': discussMode,
            'feedType': feedType,
            'blockStatus': blockStatus,
            'fromFeedAuthor': fromFeedAuthor,
          }),
    );
  }

  static Future<LoadingState> getDataFromUrl({
    required String url,
    Map<String, dynamic>? data,
  }) async {
    return getData(
      () => Request().get(Api.getDataFromUrl(url), queryParameters: data),
    );
  }

  static Future<LoadingState> getDataListFromUrl({
    required String url,
    Map<String, dynamic>? data,
  }) async {
    return getListData(
      () => Request().get(
        Api.getDataFromUrl(url),
        queryParameters: data,
      ),
    );
  }

  static Future<LoadingState> getHomeFeed({
    required int page,
    required int firstLaunch,
    required String installTime,
    required String? firstItem,
    required String? lastItem,
  }) async {
    return getListData(
      () => Request().get(
        Api.getHomeFeed,
        queryParameters: {
          'page': page,
          'firstLaunch': firstLaunch,
          'installTime': installTime,
          if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
          if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
          'ids': '',
        },
      ),
    );
  }

  static Future<LoadingState> getDataList({
    required String url,
    required String title,
    required String subTitle,
    required String? firstItem,
    required String? lastItem,
    required int page,
    bool inCluldeConfigCard = false,
  }) async {
    return getListData(
      () => Request().get(
        Api.getDataList,
        queryParameters: {
          'url': url,
          'title': title,
          'subTitle': subTitle,
          if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
          if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
          'page': page,
        },
      ),
      inCluldeConfigCard: inCluldeConfigCard,
    );
  }

  static Future<LoadingState> getFeedDetail(
      {required String id, bool verify = false}) async {
    if (!RegExp(r'^[0-9]+$').hasMatch(id)) {
      return LoadingState.error('动态编号无效');
    }
    String? captchaVerification;
    try {
      final response = await Request().get(
        Api.getDataFromUrl('/v6/feed/detail'),
        queryParameters: {'id': id},
        options: Options(extra: {'skipCaptcha': !verify}),
      );
      captchaVerification = response.extra['captchaVerification'] as String?;
      // Only access challenges permit the official public representation.
      readApiObject(response);
      return await handleDataResponse(response);
    } catch (error) {
      final failure = ApiFailure.fromError(error);
      if (verify) {
        if (captchaVerification == 'cancelled') {
          return LoadingState.error('已取消验证，可重试或导入官方设备标识', canVerify: true);
        }
        if (captchaVerification == 'submitted' &&
            failure.kind == ApiFailureKind.captcha) {
          return LoadingState.error('验证已完成，但服务端仍未允许读取详情，可稍后重试或导入官方设备标识',
              canVerify: true);
        }
        return LoadingState.error(failure.message,
            canVerify: failure.kind == ApiFailureKind.captcha ||
                failure.kind == ApiFailureKind.authentication);
      }
      if ([ApiFailureKind.captcha, ApiFailureKind.authentication]
          .contains(failure.kind)) {
        try {
          final publicResponse = await Request().get(
            '${Constants.URL_COOLAPK}feed/$id',
            options: Options(responseType: ResponseType.plain),
          );
          // The official web endpoint can stop serving its JSON representation
          // and return an app-only landing page. That page has no feed body;
          // keep the original access reason instead of treating it as bad JSON.
          final body = publicResponse.data;
          if (body is String &&
              body.trimLeft().startsWith('<') &&
              body.contains('请用酷安手机APP扫码查看详情')) {
            return LoadingState.error(
                failure.kind == ApiFailureKind.captcha
                    ? '当前设备需要验证，公开分享页暂不提供正文。可重试验证，或导入官方设备标识后重试。'
                    : '此内容需要登录，公开分享页暂不提供正文。可重试或检查登录状态。',
                canVerify: true);
          }
          final public = await handleDataResponse(publicResponse);
          if (public is Success) {
            final data = public.response as Datum;
            // A public response cannot establish this account's like state.
            data.userAction = null;
            return Success(data, isPublic: true);
          }
          return public;
        } catch (publicError) {
          return LoadingState.error(ApiFailure.fromError(publicError).message);
        }
      }
      return LoadingState.error(failure.message);
    }
  }

  static Future<LoadingState> getData(
      Future<Response<dynamic>> Function() get) async {
    try {
      var response = await get();
      return await handleDataResponse(response);
    } catch (err) {
      return LoadingState.error(ApiFailure.fromError(err).message);
    }
  }

  static Future<LoadingState> getListData(
    Future<Response<dynamic>> Function() get, {
    bool inCluldeConfigCard = false,
  }) async {
    try {
      var response = await get();
      return await handleListResponse(
        response,
        inCluldeConfigCard: inCluldeConfigCard,
      );
    } catch (err) {
      return LoadingState.error(ApiFailure.fromError(err).message);
    }
  }

  static Future<LoadingState> handleDataResponse(
      Response<dynamic> response) async {
    try {
      DataModel responseData = DataModel.fromJson(readApiObject(response));
      if (responseData.data != null) {
        return LoadingState.success(responseData.data);
      } else {
        return LoadingState.empty();
      }
    } catch (error) {
      return LoadingState.error(ApiFailure.fromError(error).message);
    }
  }

  static Future<LoadingState> handleListResponse(
    Response<dynamic> response, {
    bool inCluldeConfigCard = false,
  }) async {
    try {
      final object = readApiObject(response);
      final raw = object['data'];
      DataListModel responseData = DataListModel.fromJson({
        ...object,
        if (raw is List) 'data': _expandListCards(raw).toList(),
      });
      if (!responseData.data.isNullOrEmpty) {
        List<String> userBlackList = GStorage.blackList
            .get(BlackListBoxKey.userBlackList, defaultValue: <String>[]);
        List<String> topicBlackList = GStorage.blackList
            .get(BlackListBoxKey.topicBlackList, defaultValue: <String>[]);
        List<Datum> accepted = responseData.data!.where((item) {
          return item.entityTemplate == 'refreshCard' &&
                  item.title.orEmpty.contains('没有')
              ? true
              : (Constants.entityTypeList.contains(item.entityType) ||
                  (Constants.entityTemplateList +
                          (inCluldeConfigCard ? ['configCard'] : []))
                      .contains(item.entityTemplate));
        }).toList();
        final filterList = accepted
            .where((item) =>
                !userBlackList.contains(item.uid.toString()) &&
                topicBlackList.firstWhereOrNull((keyword) =>
                        '${item.tags},${item.ttitle},${item.relationRows?.getOrNull(0)?.title}'
                            .contains(keyword)) ==
                    null)
            .toList();
        final cursorRows = responseData.data!.where((item) => item.id != null);
        return Success(filterList,
            rawResponse: accepted,
            firstItem: cursorRows.firstOrNull?.id.toString(),
            lastItem: cursorRows.lastOrNull?.id.toString());
      } else {
        return LoadingState.empty();
      }
    } catch (error) {
      return LoadingState.error(ApiFailure.fromError(error).message);
    }
  }

  /// Search results group normal entities inside listCard containers. Expand
  /// before model parsing so child IDs, messages and pagination remain intact.
  static Iterable<dynamic> _expandListCards(List<dynamic> items,
      [int depth = 0]) sync* {
    if (depth > 20) {
      throw const ApiFailure(ApiFailureKind.invalidResponse, '服务器响应结构异常，请稍后重试');
    }
    for (final item in items) {
      if (item is Map<String, dynamic> &&
          item['entityType'] == 'card' &&
          item['entityTemplate'] == 'listCard') {
        final children = item['entities'];
        if (children is List) yield* _expandListCards(children, depth + 1);
      } else {
        yield item;
      }
    }
  }
}
