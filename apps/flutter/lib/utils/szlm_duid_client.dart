import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'official_device_identity.dart';

/// Never includes reports, response contents or raw transport exceptions.
class SzlmDuidException implements Exception {
  const SzlmDuidException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// libdu field codec: szlm_res a7b7b883, tools/unenc.py (MIT).
/// P derivation, permutations and checksum offset credited to People-11 there.
/// The input is an installation seed, never AndroidID or a hardware identifier.
class SzlmFieldCodec {
  static int parameter(String timestamp) =>
      int.parse(timestamp.substring(timestamp.length - 3).replaceAll('.', ''));

  static String encode(String value, int p) {
    final k = p % 100 % 57 + 1;
    final s = value.codeUnits.map((c) => (c - 32 + k) % 95 + 32).toList();
    final n = s.length, m = n ~/ 2;
    final out = <int>[];
    switch (p ~/ 100 % 4) {
      case 0:
        if (n.isOdd) out.add(s[m]);
        for (var i = 0; i < m; i++) {
          out.addAll([s[n - 1 - i], s[m - 1 - i]]);
        }
        break;
      case 1:
        for (var i = 0; i < m; i++) {
          out.addAll([s[n - 1 - i], s[i]]);
        }
        if (n.isOdd) out.add(s[m]);
        break;
      case 2:
        for (var i = n - 1; i >= 0; i -= 2) {
          out.add(s[i]);
        }
        for (var i = n - 2; i >= 0; i -= 2) {
          out.add(s[i]);
        }
        break;
      case 3:
        for (var i = 0; i < n; i += 2) {
          out.add(s[i]);
        }
        for (var i = 1; i < n; i += 2) {
          out.add(s[i]);
        }
    }
    return String.fromCharCodes(out);
  }

  static String anchor(String value, int p) {
    final index =
        value.length > 9 ? value.length - 1 - p % 10 : value.length - 1;
    return encode(value.substring(0, index) + value.substring(index + 1), p);
  }

  static String checksum(String value, int p) => md5
      .convert(utf8.encode(
          '${value.codeUnits.fold<int>(0, (a, b) => a + b) + p % 100 ~/ 10}'))
      .toString()
      .toUpperCase()
      .substring(0, 7);
}

class SzlmDuidClient {
  static const String host = 'auni.telecome.cn';
  static const String fallbackHost = 'global-auni.checktrustworthiness.com';
  static const String reportPath =
      '/a/mdna/report?v=8.7&t=m&p=F9BD0FBDACFE80FCF34370FBCFEE1A98';
  static const Duration timeout = Duration(seconds: 15);
  static const int maxResponseBytes = 64 * 1024;
  static const String _poolKey =
      r'xp7j@&!v5]2k#+3z{n9$q^r%[8f1*d4e:c>0l?m/6)yb-=w}';

  static String createSeed([Random? random]) {
    final source = random ?? Random.secure();
    return List.generate(32, (_) => source.nextInt(16).toRadixString(16))
        .join();
  }

  /// Sends only protocol anchors and non-unique model properties. The seed is
  /// not an issued SDK identity and is never applied to X-App-Device itself.
  static Map<String, dynamic> buildReport({
    required String seed,
    required String ts,
    String manufacturer = 'Google',
    String model = 'Pixel 7',
    String androidVersion = '13',
    int sdkInt = 33,
  }) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(seed)) {
      throw const SzlmDuidException('本机设备报文配置无法读取');
    }
    final input = seed.substring(0, 16);
    final p = SzlmFieldCodec.parameter(ts);
    final hash = sha1.convert(utf8.encode(input)).toString().toUpperCase();
    final mac =
        '${hash.substring(1, 7)}:${hash.substring(13, 19)}:${hash.substring(7, 13)}';
    return {
      'DUv': 'com.coolapk.market',
      '75c': '11e7b222083a4b732b4b14811f6fc05995a01415eb',
      '3mS': 'v9.0.1',
      'AAA': 'v1.0',
      'BBB': 'v1.0',
      '2cO': ts,
      'foO': SzlmFieldCodec.anchor(input, p),
      'sfOo': SzlmFieldCodec.checksum(input, p),
      'P1J': mac,
      'AYk': mac,
      'dLH': SzlmFieldCodec.encode(seed, p),
      'R37': manufacturer,
      'R3d': model,
      'R41': androidVersion,
      'SAN': sdkInt,
    };
  }

  static Uint8List encodeReport(Map<String, dynamic> report) =>
      _xor(ZLibCodec(level: 6)
          .encode(utf8.encode(jsonEncode(report).replaceAll('/', r'\/'))));

  static String? decodeId(List<int> raw) {
    if (raw.isEmpty || raw.length > maxResponseBytes) return null;
    final plain = _xor(raw);
    Object? body;
    try {
      if (plain.length >= 2 &&
          plain[0] == 0x78 &&
          ((plain[0] << 8) + plain[1]) % 31 == 0) {
        final sink = _LimitedResponseSink();
        final decoder = ZLibDecoder().startChunkedConversion(sink);
        decoder.add(plain);
        decoder.close();
        body = jsonDecode(utf8.decode(sink.bytes.takeBytes()));
      } else {
        body = jsonDecode(utf8.decode(plain));
      }
    } catch (_) {
      return null;
    }
    if (body is! Map || !(body['err'] == '0' || body['err'] == 0)) return null;
    final primary = body['n_a'];
    // An explicit all-zero rejection must never fall through to a cached ID.
    if (primary != null && primary != '') {
      return OfficialDeviceIdentity.validate(primary);
    }
    return OfficialDeviceIdentity.validate(body['cdd']);
  }

  /// One body, then a sequential fallback on transport failure only. Never
  /// races two registrations or retries an explicit service rejection.
  static Future<String> fetch({
    required String seed,
    String manufacturer = 'Google',
    String model = 'Pixel 7',
    String androidVersion = '13',
    int sdkInt = 33,
    Future<List<int>> Function(Uri uri, List<int> body)? post,
    Random? random,
    DateTime? now,
  }) async {
    final source = random ?? Random.secure();
    final time = now ?? DateTime.now();
    final nanos = time.microsecondsSinceEpoch.remainder(1000000) * 1000 +
        source.nextInt(999) +
        1;
    final ts = '${time.millisecondsSinceEpoch ~/ 1000}.$nanos';
    final body = encodeReport(buildReport(
        seed: seed,
        ts: ts,
        manufacturer: manufacturer,
        model: model,
        androidVersion: androidVersion,
        sdkInt: sdkInt));
    final path = '$reportPath&r=${createSeed(source)}&n=0&l=2&h=0';
    final sender = post ?? _post;
    for (final target in [host, fallbackHost]) {
      List<int> raw;
      try {
        raw = await sender(Uri.parse('https://$target$path'), body)
            .timeout(timeout);
      } catch (_) {
        if (target == host) continue;
        throw const SzlmDuidException('无法连接设备标识服务，请检查网络后稍后重试');
      }
      final id = decodeId(raw);
      if (id == null) {
        throw const SzlmDuidException('取号失败：服务端没有返回有效的设备标识');
      }
      return id;
    }
    throw const SzlmDuidException('无法连接设备标识服务，请稍后重试');
  }

  static Future<List<int>> _post(Uri uri, List<int> body) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      return await (() async {
        final request = await client.postUrl(uri);
        request.followRedirects = false;
        request.headers
          ..set(HttpHeaders.contentTypeHeader, 'application/octet-stream')
          ..set(HttpHeaders.acceptEncodingHeader, 'identity');
        request.contentLength = body.length;
        request.add(body);
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw const SzlmDuidException('设备标识服务暂时不可用');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response) {
          if (bytes.length + chunk.length > maxResponseBytes) {
            throw const SzlmDuidException('设备标识服务响应异常');
          }
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      })()
          .timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }

  static Uint8List _xor(List<int> data) {
    final key = utf8.encode(_poolKey);
    return Uint8List.fromList(
        List.generate(data.length, (i) => data[i] ^ key[i % key.length]));
  }
}

class _LimitedResponseSink implements Sink<List<int>> {
  final bytes = BytesBuilder(copy: false);
  @override
  void add(List<int> data) {
    if (bytes.length + data.length > SzlmDuidClient.maxResponseBytes) {
      throw const FormatException('Oversized identity response');
    }
    bytes.add(data);
  }

  @override
  void close() {}
}
