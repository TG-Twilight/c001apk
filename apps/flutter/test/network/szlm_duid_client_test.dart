import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:c001apk_flutter/utils/official_device_identity.dart';
import 'package:c001apk_flutter/utils/szlm_duid_client.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pool constant is repeated here on purpose: the encoder must match the
/// captured wire format, not this test's idea of it.
const _poolKey = r'xp7j@&!v5]2k#+3z{n9$q^r%[8f1*d4e:c>0l?m/6)yb-=w}';

// A report for the captured device. `getduid.py` produces the same plain JSON
// and the same 1371-byte wire body for these anchors.
const _capturedSfOo = '801C14F';
const _capturedFoO = r'RP|Q|zQKOJ~I~}Q';
const _capturedTs = '1791105420.764024281';
const _capturedW91 = '529D912CF3C16EC094E0AD57FFD19589';
const _capturedGEd = '9e077ef78ef33b84b98eeb2615feacee';
const _capturedY6Y =
    '0306f8ee3e9e99964ce29c62439d4e5f937e2f9189c18d6a8e844d27eb38b95b';

// A second vector with every re-drawn field changed.
const _mixedSfOo = '0001A2B';
const _mixedFoO = '0123456789abcde';
const _mixedTs = '1700000000.123456789';
const _mixedW91 = '00112233445566778899AABBCCDDEEFF';
const _mixedGEd = '00112233445566778899aabbccddeeff';
const _mixedY6Y =
    '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

/// `{"n_a":"DUsynthetic0000000000000000000000000AB","err":"0"}`, encoded the
/// way the SDK encodes a response.
const _issuedHex =
    '00ec9c3c8aad6e22870f40620e85ff51b22614ed3d68b22047a5f245be36bfefbaa933a4063eb30138de';

List<int> _xor(List<int> data) {
  final key = utf8.encode(_poolKey);
  return List<int>.generate(data.length, (i) => data[i] ^ key[i % key.length]);
}

List<int> _response(Map<String, dynamic> body) =>
    _xor(ZLibCodec(level: 6).encode(utf8.encode(jsonEncode(body))));

String _plainOf(List<int> wireBody) =>
    utf8.decode(ZLibCodec().decode(Uint8List.fromList(_xor(wireBody))));

List<int> _hexToBytes(String hex) => List<int>.generate(hex.length ~/ 2,
    (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));

Map<String, dynamic> _reportWith({
  String sfOo = _capturedSfOo,
  String foO = _capturedFoO,
  String ts = _capturedTs,
  String w91 = _capturedW91,
  String gEd = _capturedGEd,
  String y6Y = _capturedY6Y,
}) =>
    SzlmDuidClient.buildReport(
        sfOo: sfOo, foO: foO, ts: ts, w91: w91, gEd: gEd, y6Y: y6Y);

void main() {
  group('report encoding', () {
    test('matches the captured report field for field', () {
      final body = SzlmDuidClient.encodeReport(_reportWith());
      final plain = _plainOf(body);
      expect(plain.length, 2337);
      expect(jsonDecode(plain), hasLength(79));
      expect(sha256.convert(utf8.encode(plain)).toString(),
          '864bcac2d581ec92548962e88d67c5313664c954c4e7feb491c289ea135a2a43');
      // The captured body is 1371 bytes; the exact deflate output depends on the
      // platform zlib, so only the decoded JSON above is asserted byte-exactly.
      expect(body.length, inInclusiveRange(1200, 1600));
    });

    test('keeps every field that was not re-drawn', () {
      final plain = _plainOf(SzlmDuidClient.encodeReport(_reportWith(
          sfOo: _mixedSfOo,
          foO: _mixedFoO,
          ts: _mixedTs,
          w91: _mixedW91,
          gEd: _mixedGEd,
          y6Y: _mixedY6Y)));
      expect(sha256.convert(utf8.encode(plain)).toString(),
          '59f70c1aea7774183a436fd3f945e544f4ea29718670a3038fffb9fdaa6269e7');
      final report = jsonDecode(plain) as Map<String, dynamic>;
      expect(report, hasLength(79));
      expect(report['DUv'], 'com.coolapk.market');
      expect(report['R37'], 'TK Watch');
      expect(report['sfOo'], _mixedSfOo);
      expect(report['foO'], _mixedFoO);
      expect(report['2cO'], _mixedTs);
      expect(report['w91'], _mixedW91);
    });
  });

  group('response decoding', () {
    test('returns the issued identity', () {
      expect(SzlmDuidClient.decodeId(_hexToBytes(_issuedHex)),
          'DUsynthetic0000000000000000000000000AB');
    });

    test('rejects the all-zero rejection answer', () {
      expect(
          SzlmDuidClient.decodeId(_response({
            'n_a': '000000000000000000000000000000000000',
            'err': '0'
          })),
          isNull);
    });

    test('rejects payloads that are not a decodable report', () {
      expect(SzlmDuidClient.decodeId(const []), isNull);
      expect(SzlmDuidClient.decodeId(utf8.encode('{}')), isNull);
      expect(
          SzlmDuidClient.decodeId(
              _response({'error': 'no n_a', 'n_a': ' short '})),
          isNull);
    });
  });

  group('fetch', () {
    test('draws the six fields and keeps the anchors intact', () async {
      late Uri requested;
      late List<int> sent;
      final id = await SzlmDuidClient.fetch(
          now: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          post: (uri, body) async {
            requested = uri;
            sent = body;
            return _hexToBytes(_issuedHex);
          });
      expect(id, 'DUsynthetic0000000000000000000000000AB');
      expect(requested.host, 'auni.telecome.cn');
      expect(requested.path, '/a/mdna/report');
      expect(requested.queryParameters['p'],
          'F9BD0FBDACFE80FCF34370FBCFEE1A98');
      expect(requested.queryParameters['h'], '0');

      final report = jsonDecode(_plainOf(sent)) as Map<String, dynamic>;
      expect(report, hasLength(79));
      expect(report['sfOo'], matches(RegExp(r'^[0-9A-F]{7}$')));
      expect(report['foO'], matches(RegExp(r'^[!-~]{15}$')));
      expect(report['2cO'], matches(RegExp(r'^1700000000\.\d{9}$')));
      expect(report['w91'], matches(RegExp(r'^[0-9A-F]{32}$')));
      expect(report['gEd'], matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(report['6yY'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(report['DUv'], 'com.coolapk.market');
      // The three hashes must move with the anchors; a report that only changes
      // the anchors is answered with an all-zero identity.
      expect(report['w91'], isNot(_capturedW91));
      expect(report['gEd'], isNot(_capturedGEd));
      expect(report['6yY'], isNot(_capturedY6Y));
    });

    test('surfaces a rejected registration without exposing the payload',
        () async {
      final failure = await SzlmDuidClient.fetch(
              post: (uri, body) async => _response({
                    'n_a': '000000000000000000000000000000000000',
                    'err': '0'
                  }))
          .then<Object?>((id) => null, onError: (Object error) => error);
      expect(failure, isA<SzlmDuidException>());
      expect('$failure', isNot(contains('0000000000')));
    });

    test('surfaces an unreadable response', () async {
      await expectLater(
          SzlmDuidClient.fetch(post: (uri, body) async => const [1, 2, 3]),
          throwsA(isA<SzlmDuidException>()));
    });
  });

  group('identity validation', () {
    test('accepts the identifier shape the app stores', () {
      expect(OfficialDeviceIdentity.validate('DUsynthetic0123456789_-'),
          'DUsynthetic0123456789_-');
      expect(
          OfficialDeviceIdentity.validate(
              '  DUaVFlbAMrmH2Z57PEhm_N9EO4RoUdvNstg5 '),
          'DUaVFlbAMrmH2Z57PEhm_N9EO4RoUdvNstg5');
    });

    test('refuses the rejection answer and malformed values', () {
      expect(OfficialDeviceIdentity.validate('0000000000000000'), isNull);
      expect(OfficialDeviceIdentity.validate('short'), isNull);
      expect(OfficialDeviceIdentity.validate('DU has space 0123456'), isNull);
      expect(OfficialDeviceIdentity.validate('DU数盟0123456789'), isNull);
      expect(OfficialDeviceIdentity.validate(null), isNull);
    });
  });
}
