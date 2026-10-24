import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'official_device_identity.dart';

/// Local failure for one acquisition attempt. Neither the report nor the raw
/// response may enter the message, a log or the UI.
class SzlmDuidException implements Exception {
  const SzlmDuidException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Client for the 数字联盟 (cn.shuzilm) registration endpoint the official
/// client uses to obtain a DUID. The identifier is the same value the official
/// app exports as `ShuzlmID`, which this app stores as the first slot of
/// `X-App-Device`.
///
/// Wire format, captured from `libdu.so` (see docs/SZLM_AUTO.md):
/// compact UTF-8 JSON with `/` written as `\/`, zlib level 6, then XOR with the
/// 48-byte pool constant. The response uses the same two steps in reverse.
///
/// A report carries 79 fields. Only six are re-drawn per attempt: the anchor
/// triple `sfOo`/`foO`/`2cO` and the three device hashes `w91`/`gEd`/`6yY`.
/// Re-drawing the anchors alone is rejected by the server, so the three hashes
/// must move with them; every other field stays as captured.
class SzlmDuidClient {
  static const String host = 'auni.telecome.cn';
  static const String reportPath =
      '/a/mdna/report?v=8.7&t=m&p=F9BD0FBDACFE80FCF34370FBCFEE1A98'
      '&r=5bb7efdd4c794f0e9563317b7802b995&n=0&l=2&h=0';
  static const Duration timeout = Duration(seconds: 15);

  static const String _userAgent =
      'Dalvik/2.1.0 (Linux; U; Android 8.1; TK Watch Build/OPM2.171019.012)';
  static const String _poolKey =
      r'xp7j@&!v5]2k#+3z{n9$q^r%[8f1*d4e:c>0l?m/6)yb-=w}';
  static const String _alphabet =
      r"!#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~";
  static const String _template = r"""{"DUv":"com.coolapk.market","Qg1":1790980402778,"LMi":1790980402778,"Zrs":2609151,"EV2":"16.6.2","SAN":27,"h6Z":"酷安","R41":"8.1","Ra":"ABSENT","R53":"0","R63":"running","QgA":1,"qH9":"0","iZS":0,"ZZA":0,"S6e":1,"90P":"IJ","Q23":"user:e4e40166.0+CN=数据包捕获CA证书;user:87bc3517.0+OU=HttpCanary,O=HttpCanary,CN=HttpCanary Root CA;","YWu":"127.0.0.1+localhost;::1+ip6-localhost;","bzt":"0000","5mZ":0,"0KQ":0,"Chh":0,"Xl9":"0000","D32":4,"LAh":"IIJIIIII","wlM":1,"nur":0,"tth":1,"c2O":"1","PV8":"7","AYk":"13A365:CCAF40:AD4AA9","P1J":"13A365:CCAF40:AD4AA9","R37":"TK Watch","R3d":"TK Watch","AAA":"v1.0","BBB":"v1.0","3mS":"v9.0.1","2cO":"1791105420.764024281","K5f":"F8E4D9D1F967D773DFA6381BA10102E9","GVp":"coolapk","iYB":{"txo":"Iz1(&","Zne":"vOM|S}RL~S}SQSNLNzSIKEOQ}SQJK S MI~KQSNQRM9MHLIII9MH|zP~SPPKNSI~tMH~M OS }QRI~KQSNQRM9MHR}MJSOO JSQSNLNzSIKEKPGGGJEONRS}KJ{SIOSQ ","MCN":"vGGGJ9J SL   SO I~KQSNQRMHJIIIHEOzM~S K}OSQSNLNzSIKt","mch":"bb_p","AWo":"IIIIIJIIII","8tS":1048576,"Hsz":1048576},"7S2":{"0":{"txo":"Iz1(&","Zne":"vOM|S}RL~S}SQSNLNzSIKEOQ}SQJK S MI~KQSNQRM9MHLIII9MH|zP~SPPKNSI~tMH~M OS }QRI~KQSNQRM9MHR}MJSOO JSQSNLNzSIKEKPGGGJEONRS}KJ{SIOSQ ","MCN":"vGGGJ9J SL   SO I~KQSNQRMHJIIIHEOzM~S K}OSQSNLNzSIKt"}},"ne8":"97313e29420c51d0d8cc6e3a3586889a","sfOo":"801C14F","foO":"RP|Q|zQKOJ~I~}Q","dJs":"IMPIIJPK}KJQKIJNI|NMINIMMMLNNIIJ","w91":"529D912CF3C16EC094E0AD57FFD19589","G8U":{"MYA":"IOPOIOKMIEPRQ","H4S":"PIMGEPMMNNOOJNNPGK"},"zvW":"||RJI}JKQKQR{}{OON}KQJQMJR}}RN I","gEd":"9e077ef78ef33b84b98eeb2615feacee","5Tv":"||I}z LRO~| ~PLK}K}z{~KL LzL}{ P","52J":"RLOJREKKKESEKMPELOSLEJIREKOSKEKQRJISMJESNPKOSRKRSRKIIJSIRJLOMNQSORRLOOMISLJEKQNJJMP","p1m":"PIIJ2NMINI","Bos":"PQRRJQJRNPERRRIGJIOLJRRRIGJIOLJPQRRJQJRNP","IJK":"PRMILMMIJPERRROGJRPLJKJINGQNJRJLRRRJKKQNP","ura":"PRMILMMIJPERRROGJRPLJKJINGQNJRJLRRRJKKQNP","ibF":"IIIFFI","IAI":"JPMIMILNNPERRRLGJIOLJOPIRGQOQOJOQRRNRJRNP","aFw":"NRMIRJMIJPERRRKGIRPLJOJIRGLNJRJMRRRPRKQNP","KyU":"JRMIPNLIJPRJIRGRNJRJ","6yY":"0306f8ee3e9e99964ce29c62439d4e5f937e2f9189c18d6a8e844d27eb38b95b","UOv":"NQQLRLRQJPKQRJGKNIRJ","JPd":"0","J7w":0,"zpA":"WIFI","bf7":"0","wSK":"10.0.0.37","fPV":"CN,zh","Db2":2,"QVn":0,"msg":{"custom":""},"dLH":" NNzM~FRQKLFP{K| |JOLRONLQFKMzKFPOO{","4VP":1,"za7":"1_1791105420_","75c":"11e7b222083a4b732b4b14811f6fc05995a01415eb","fxb":100344,"B3k":67020,"cHo":0}""";

  /// A report for one attempt. `ts` is `"seconds.nanoseconds"`; the fraction is
  /// a fresh random value, not a real clock reading.
  static Map<String, dynamic> buildReport({
    required String sfOo,
    required String foO,
    required String ts,
    required String w91,
    required String gEd,
    required String y6Y,
  }) {
    final decoded = jsonDecode(_template);
    if (decoded is! Map<String, dynamic> || decoded.length != 79) {
      throw const SzlmDuidException('设备标识报文模板无法读取');
    }
    return decoded
      ..['sfOo'] = sfOo
      ..['foO'] = foO
      ..['2cO'] = ts
      ..['w91'] = w91
      ..['gEd'] = gEd
      ..['6yY'] = y6Y;
  }

  /// Compact JSON, `/` escaped, zlib level 6, then the pool XOR.
  static Uint8List encodeReport(Map<String, dynamic> report) {
    final plain = jsonEncode(report).replaceAll('/', r'\/');
    return _xor(ZLibCodec(level: 6).encode(utf8.encode(plain)));
  }

  /// The issued identifier, or null when the report was rejected (`n_a` all
  /// zeroes) or the payload is not a decodable report.
  static String? decodeId(List<int> raw) {
    final plain = _xor(Uint8List.fromList(raw));
    Object? body;
    try {
      body = jsonDecode(utf8.decode(ZLibCodec().decode(plain)));
    } catch (_) {
      try {
        body = jsonDecode(utf8.decode(plain));
      } catch (_) {
        return null;
      }
    }
    if (body is! Map) return null;
    return OfficialDeviceIdentity.validate(body['n_a']);
  }

  /// Draws a fresh identity. `post` and `random` exist for tests: the real call
  /// is the only network access this method makes.
  static Future<String> fetch({
    Future<List<int>> Function(Uri uri, List<int> body)? post,
    Random? random,
    DateTime? now,
  }) async {
    final source = random ?? Random.secure();
    final report = buildReport(
      sfOo: _randomHex(source, 7, upper: true),
      foO: _randomToken(source, 15),
      ts: _randomClock(source, now ?? DateTime.now()),
      w91: _randomHex(source, 32, upper: true),
      gEd: _randomHex(source, 32, upper: false),
      y6Y: _randomHex(source, 64, upper: false),
    );
    final sender = post ?? _post;
    final raw =
        await sender(Uri.parse('https://$host$reportPath'), encodeReport(report))
            .timeout(timeout);
    final id = decodeId(raw);
    if (id == null) {
      throw const SzlmDuidException('取号失败：服务端没有返回有效的设备标识');
    }
    return id;
  }

  static Future<List<int>> _post(Uri uri, List<int> body) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(uri);
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded')
        ..set(HttpHeaders.userAgentHeader, _userAgent)
        ..set(HttpHeaders.acceptHeader, '*/*')
        ..set(HttpHeaders.acceptEncodingHeader, 'identity');
      request.contentLength = body.length;
      request.add(body);
      final response = await request.close();
      // A rejected report still answers with a decodable body; decodeId decides.
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      return bytes;
    } finally {
      client.close(force: true);
    }
  }

  static String _randomHex(Random random, int length, {required bool upper}) {
    final digits = upper ? '0123456789ABCDEF' : '0123456789abcdef';
    return String.fromCharCodes(
      List<int>.generate(length, (_) => digits.codeUnitAt(random.nextInt(16))),
    );
  }

  static String _randomToken(Random random, int length) =>
      String.fromCharCodes(List<int>.generate(
        length,
        (_) => _alphabet.codeUnitAt(random.nextInt(_alphabet.length)),
      ));

  static String _randomClock(Random random, DateTime now) {
    final fraction = random.nextInt(999999999) + 1;
    return '${now.millisecondsSinceEpoch ~/ 1000}.'
        '${fraction.toString().padLeft(9, '0')}';
  }

  static Uint8List _xor(List<int> data) {
    final key = utf8.encode(_poolKey);
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      out[i] = data[i] ^ key[i % key.length];
    }
    return out;
  }
}
