import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:c001apk_flutter/utils/storage_util.dart';
import 'package:c001apk_flutter/utils/token_util.dart';
import 'package:hive/hive.dart';

class RegistrationOverride extends HttpOverrides {
  int calls = 0;
  Future<String> Function() result =
      () async => 'DUsyntheticAUTOMATIC123456789';
  @override
  HttpClient createHttpClient(SecurityContext? context) => FakeClient(this);
}

class FakeClient implements HttpClient {
  FakeClient(this.owner);
  final RegistrationOverride owner;
  @override
  set connectionTimeout(Duration? value) {}
  @override
  Future<HttpClientRequest> postUrl(Uri uri) async {
    if (uri.host != 'auni.telecome.cn') {
      throw StateError('Unexpected network target');
    }
    owner.calls++;
    return FakeRequest(owner);
  }

  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRequest implements HttpClientRequest {
  FakeRequest(this.owner);
  final RegistrationOverride owner;
  @override
  final HttpHeaders headers = FakeHeaders();
  @override
  set contentLength(int value) {}
  @override
  set followRedirects(bool value) {}
  @override
  void add(List<int> data) {}
  @override
  Future<HttpClientResponse> close() async {
    final id = await owner.result();
    final plain = utf8.encode(jsonEncode({'err': '0', 'n_a': id}));
    final key =
        utf8.encode(r'xp7j@&!v5]2k#+3z{n9$q^r%[8f1*d4e:c>0l?m/6)yb-=w}');
    return FakeResponse(
        List.generate(plain.length, (i) => plain[i] ^ key[i % key.length]));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  FakeResponse(this.bytes);
  final List<int> bytes;
  @override
  int get statusCode => HttpStatus.ok;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Directory> setupStorage() async {
  final dir = await Directory.systemTemp.createTemp('c001apk-pr11-offline-');
  Hive.init(dir.path);
  GStorage.settings = await Hive.openBox('settings');
  await GStorage.settings.putAll({
    SettingsBoxKey.xAppDevice: await TokenUtils.encodeDevice(
        'ca_synthetic; ; ; ; Google; google; Pixel 7; TQ3A.230805.001; null'),
    SettingsBoxKey.versionCode: '2604201',
    SettingsBoxKey.versionName: '16.2.0',
    SettingsBoxKey.apiVersion: '16',
    SettingsBoxKey.sdkInt: '33',
    SettingsBoxKey.userAgent: 'synthetic-agent',
  });
  return dir;
}
