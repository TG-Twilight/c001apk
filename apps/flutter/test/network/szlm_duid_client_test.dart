import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:c001apk_flutter/utils/szlm_duid_client.dart';
import 'package:flutter_test/flutter_test.dart';

const _poolKey = r'xp7j@&!v5]2k#+3z{n9$q^r%[8f1*d4e:c>0l?m/6)yb-=w}';
const _seed = '0123456789abcdef0123456789abcdef';
const _id = 'DUsynthetic0000000000000000000000000AB';
List<int> _xor(List<int> data) => List.generate(
    data.length, (i) => data[i] ^ _poolKey.codeUnitAt(i % _poolKey.length));
List<int> _response(Map<String, dynamic> body, {bool compressed = true}) {
  final bytes = utf8.encode(jsonEncode(body));
  return _xor(compressed ? ZLibCodec().encode(bytes) : bytes);
}

Map<String, dynamic> _report(List<int> bytes) =>
    jsonDecode(utf8.decode(ZLibCodec().decode(_xor(bytes))))
        as Map<String, dynamic>;

void main() {
  group('time-dependent field codec', () {
    test('all permutations match independent upstream codec vectors', () {
      const vectors = <int, String>{
        0: 'g8f7e6d5c4b3:291',
        168: 'r<q=p>o?n@mAEBDC',
        281: ' }{RPNLJ~|zQOMKI',
        399: '[]_ac-/1\\^`bd.02'
      };
      for (final entry in vectors.entries) {
        expect(
            SzlmFieldCodec.encode('0123456789abcdef', entry.key), entry.value);
      }
    });
    test('timestamp parameter uses unpadded fractional tail', () {
      expect(SzlmFieldCodec.parameter('1700000004.7'), 47);
      expect(SzlmFieldCodec.parameter('1700000000.1'), 1);
      expect(SzlmFieldCodec.parameter('1700000000.123456281'), 281);
    });
    test('mode 10 removes the time-selected character and offsets checksum',
        () {
      const anchors = {
        0: '8f7e6d5c4b3:291',
        168: 'r<q=p>o?n@mAEBD',
        281: ' |zQOMKI}{RPNLJ',
        399: '[]_bd.02\\^`c-/1'
      };
      const checksums = {
        0: '3B712DE',
        168: '3FE78A8',
        281: '4A213D3',
        399: 'FE709C6'
      };
      for (final p in anchors.keys) {
        expect(SzlmFieldCodec.anchor('0123456789abcdef', p), anchors[p]);
        expect(SzlmFieldCodec.checksum('0123456789abcdef', p), checksums[p]);
      }
    });
  });
  group('responses', () {
    test('accepts compressed and plain responses, integer and string success',
        () {
      for (final compressed in [false, true]) {
        for (final err in [0, '0']) {
          expect(
              SzlmDuidClient.decodeId(
                  _response({'err': err, 'n_a': _id}, compressed: compressed)),
              _id);
          expect(
              SzlmDuidClient.decodeId(
                  _response({'err': err, 'cdd': _id}, compressed: compressed)),
              _id);
        }
      }
    });
    test('does not accept error receipts or explicit rejection via cdd', () {
      for (final body in [
        {'err': '1', 'n_a': _id},
        {'n_a': _id},
        {'err': '0', 'n_a': '0000000000000000', 'cdd': _id},
        {'err': '0', 'n_a': 123},
        {'err': '0', 'cdd': 'short'}
      ]) {
        expect(SzlmDuidClient.decodeId(_response(body)), isNull);
      }
    });
    test('rejects HTML, malformed and oversized decompressed responses', () {
      expect(
          SzlmDuidClient.decodeId(utf8.encode('<html>blocked</html>')), isNull);
      expect(SzlmDuidClient.decodeId([]), isNull);
      expect(
          SzlmDuidClient.decodeId(
              _response({'err': '0', 'n_a': _id, 'padding': 'x' * 100000})),
          isNull);
    });
  });
  group('fetch', () {
    test('consistent anchors with fresh timestamps and request IDs', () async {
      final reports = <Map<String, dynamic>>[], urls = <Uri>[];
      for (var i = 0; i < 2; i++) {
        expect(
            await SzlmDuidClient.fetch(
                seed: _seed,
                random: Random(i),
                now: DateTime.fromMillisecondsSinceEpoch(1700000000000),
                post: (uri, body) async {
                  urls.add(uri);
                  reports.add(_report(body));
                  return _response({'err': '0', 'n_a': _id});
                }),
            _id);
      }
      expect(urls.first.queryParameters['r'],
          isNot(urls.last.queryParameters['r']));
      expect(reports.first['2cO'], isNot(reports.last['2cO']));
      expect(reports.first['P1J'], reports.last['P1J']);
      for (final report in reports) {
        final p = SzlmFieldCodec.parameter(report['2cO'] as String);
        expect(report['foO'], SzlmFieldCodec.anchor(_seed.substring(0, 16), p));
        expect(
            report['sfOo'], SzlmFieldCodec.checksum(_seed.substring(0, 16), p));
        expect(report.keys, isNot(contains('6yY')));
        expect(report.keys, isNot(contains('Q23')));
      }
    });
    test('transport failure uses same body at one sequential fallback',
        () async {
      final sent = <List<int>>[], targets = <String>[];
      expect(
          await SzlmDuidClient.fetch(
              seed: _seed,
              post: (uri, body) async {
                targets.add(uri.host);
                sent.add(body);
                if (targets.length == 1) {
                  throw const SocketException('private test diagnostic');
                }
                return _response({'err': 0, 'cdd': _id});
              }),
          _id);
      expect(targets, [SzlmDuidClient.host, SzlmDuidClient.fallbackHost]);
      expect(sent.first, sent.last);
    });
    test('explicit rejection does not register at second host', () async {
      var calls = 0;
      await expectLater(
          SzlmDuidClient.fetch(
              seed: _seed,
              post: (uri, body) async {
                calls++;
                return _response({'err': '0', 'n_a': '0000000000000000'});
              }),
          throwsA(isA<SzlmDuidException>()));
      expect(calls, 1);
    });
    test('network errors do not leak raw exceptions', () async {
      var calls = 0;
      await expectLater(
          SzlmDuidClient.fetch(
              seed: _seed,
              post: (uri, body) async {
                calls++;
                throw TimeoutException('private diagnostic with secret');
              }),
          throwsA(isA<SzlmDuidException>().having(
              (e) => e.message, 'safe message', isNot(contains('secret')))));
      expect(calls, 2);
    });
  });
}
