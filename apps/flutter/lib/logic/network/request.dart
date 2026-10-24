import 'dart:async';
import 'package:dio/dio.dart';

import '../../logic/network/interceptor.dart';
import '../../utils/global_data.dart';
import '../../utils/storage_util.dart';
import '../szlm_identity_service.dart';
import 'captcha_challenge.dart';
import 'api_session_store.dart';
import 'api_failure.dart';

class Request {
  static final Request _instance = Request._internal();
  static late final Dio dio;
  factory Request() => _instance;
  Future<String?> Function(CaptchaChallenge)? captchaVerifier;
  bool _verifying = false;
  int _verificationEpoch = 0;

  Request._internal() {
    dio = Dio()
      ..options.connectTimeout = const Duration(milliseconds: 5000)
      ..options.receiveTimeout = const Duration(milliseconds: 5000)
      ..interceptors.add(ApiInterceptor());
  }

  Future<Response<dynamic>> get(
    url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    extra,
  }) async {
    final generation = GlobalData().sessionGeneration;
    final verificationEpoch = _verificationEpoch;
    options = (options ?? Options()).copyWith(extra: {
      ...?options?.extra,
      'sessionGeneration': generation,
    });
    final session =
        (GlobalData().isLogin, GlobalData().uid, GlobalData().token);
    // A recorded challenge rotates the device identity before this request, so
    // the headers are signed with the new one instead of the stale one.
    await SzlmIdentityService.instance.beforeRequest();
    final response = await dio.get(
      url,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
    _checkSession(generation, response);
    final verified = await _verifyAndRetry(
        response,
        session,
        generation,
        verificationEpoch,
        options.extra?['skipCaptcha'] == true,
        (proof, challenge) => dio.get(url,
            queryParameters: challenge.field.isEmpty
                ? queryParameters
                : {...?queryParameters, challenge.field: proof},
            options: options,
            cancelToken: cancelToken));
    _checkSession(generation, verified);
    return verified;
  }

  Future<Response<dynamic>> post(
    url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    extra,
  }) async {
    final generation = GlobalData().sessionGeneration;
    final verificationEpoch = _verificationEpoch;
    options = (options ?? Options()).copyWith(extra: {
      ...?options?.extra,
      'sessionGeneration': generation,
    });
    final session =
        (GlobalData().isLogin, GlobalData().uid, GlobalData().token);
    // A multipart body becomes finalized during its first send; retain a copy
    // before sending so a server-rejected write can be retried exactly once.
    final retryData = data is FormData ? data.clone() : data;
    await SzlmIdentityService.instance.beforeRequest();
    final response = await dio.post(
      url,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
    _checkSession(generation, response);
    final verified = await _verifyAndRetry(
        response,
        session,
        generation,
        verificationEpoch,
        options.extra?['skipCaptcha'] == true, (proof, challenge) {
      Object? verifiedData = retryData;
      if (challenge.field.isNotEmpty) {
        if (retryData is FormData) {
          retryData.fields.removeWhere((e) => e.key == challenge.field);
          retryData.fields.add(MapEntry(challenge.field, proof));
        } else if (retryData is Map<String, dynamic>) {
          verifiedData = {...retryData, challenge.field: proof};
        }
      }
      return dio.post(url,
          data: verifiedData,
          queryParameters: challenge.field.isEmpty ||
                  verifiedData is FormData ||
                  verifiedData is Map
              ? queryParameters
              : {...?queryParameters, challenge.field: proof},
          options: options,
          cancelToken: cancelToken);
    });
    _checkSession(generation, verified);
    return verified;
  }

  void _checkSession(int generation, Response response) {
    if (generation != GlobalData().sessionGeneration) {
      throw DioException(
          requestOptions: response.requestOptions,
          type: DioExceptionType.cancel,
          error: '账号已切换，已忽略旧请求');
    }
  }

  Future<Response<dynamic>> _verifyAndRetry(
      Response<dynamic> response,
      (bool, String, String) session,
      int generation,
      int verificationEpoch,
      bool skip,
      Future<Response<dynamic>> Function(String, CaptchaChallenge)
          retry) async {
    final uri = response.requestOptions.uri;
    if (skip ||
        generation != GlobalData().sessionGeneration ||
        _verifying ||
        captchaVerifier == null ||
        session !=
            (GlobalData().isLogin, GlobalData().uid, GlobalData().token) ||
        uri.scheme != 'https' ||
        !['api.coolapk.com', 'api2.coolapk.com'].contains(uri.host)) {
      return response;
    }
    final challenge = CaptchaChallenge.fromBody(response.data);
    if (challenge == null) return response;
    final device = response.requestOptions.headers['X-App-Device'];
    if (device != null && device != GStorage.xAppDevice) return response;
    final currentProof = ApiInterceptor.currentCaptchaCookie;
    if (challenge.field.isEmpty &&
        currentProof != null &&
        currentProof != response.requestOptions.extra['apiCaptchaCookie']) {
      // Another request has already established a newer proof. Reuse it once;
      // this late challenge must not delete it or reopen the verification UI.
      final retried = await retry('', challenge);
      _checkSession(generation, retried);
      return retried;
    }
    if (verificationEpoch != _verificationEpoch) {
      response.extra['captchaVerification'] = 'cancelled';
      return response;
    }
    final verificationContext = ApiSessionStore().capture();
    // Opening the verification UI is the only visible sign of a stale device
    // identity; the next request rotates it once the cooldown allows.
    SzlmIdentityService.instance.noteChallenge();
    _verifying = true;
    _verificationEpoch++;
    try {
      if (challenge.field.isEmpty) {
        await ApiInterceptor.invalidateCaptchaCookie();
      }
      final proof = await captchaVerifier!(challenge);
      if (proof == null ||
          generation != GlobalData().sessionGeneration ||
          (device != null && device != GStorage.xAppDevice) ||
          !challenge.acceptsProof(proof) ||
          response.requestOptions.cancelToken?.isCancelled == true ||
          session !=
              (GlobalData().isLogin, GlobalData().uid, GlobalData().token)) {
        response.extra['captchaVerification'] =
            proof == null ? 'cancelled' : 'incomplete';
        return response;
      }
      // Direct Dio call, deliberately outside this helper: no verification loop,
      // network retries or replay after ambiguous transport errors.
      if (challenge.field.isEmpty) ApiInterceptor.setCaptchaCookie(proof);
      final verified = await retry(proof, challenge);
      _checkSession(generation, verified);
      if ((device != null && device != GStorage.xAppDevice) ||
          session !=
              (GlobalData().isLogin, GlobalData().uid, GlobalData().token)) {
        throw DioException(
            requestOptions: verified.requestOptions,
            type: DioExceptionType.cancel,
            error: '会话已变化，已忽略旧验证结果');
      }
      if (challenge.field.isEmpty &&
          CaptchaChallenge.fromBody(verified.data) != null) {
        await ApiInterceptor.invalidateCaptchaCookie();
      } else if (challenge.field.isEmpty) {
        try {
          readApiObject(verified);
          final acceptedSession = verified.extra['apiAcceptedSession'];
          if (acceptedSession is String) {
            await ApiSessionStore().saveValidation(
                Uri.encodeQueryComponent(proof), verificationContext,
                acceptedSession: acceptedSession);
            ApiInterceptor.clearCaptchaCookie();
          }
        } catch (_) {
          // Persist only an accepted JSON result; persistence must not change a
          // successful remote operation into an error that could be repeated.
        }
      }
      verified.extra['captchaVerification'] = 'submitted';
      return verified;
    } finally {
      _verifying = false;
    }
  }
}
