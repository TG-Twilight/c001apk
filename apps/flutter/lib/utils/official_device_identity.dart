/// The official "复制 OAID" action includes this field after five taps.
/// OAID, AndroidID and UUID are deliberately not accepted as substitutes.
class OfficialDeviceIdentity {
  static const guideUrl =
      'https://github.com/TG-Twilight/c001apk/blob/main/docs/DEVICE_ID_IMPORT.md';

  static final _valuePattern = RegExp(r'^[A-Za-z0-9_+/.=-]{8,4096}$');

  /// Accepts only a well-formed identifier. An all-zero value is the server's
  /// rejection answer, never a usable identity, so it is refused here as well.
  static String? validate(Object? value) {
    if (value is! String) return null;
    final id = value.trim();
    if (!_valuePattern.hasMatch(id)) return null;
    if (id.codeUnits.every((unit) => unit == 0x30)) return null;
    return id;
  }

  static String parse(String text) {
    if (text.length > 32768) {
      throw const FormatException('复制内容过长，请重新从官方酷安复制');
    }
    final matches = RegExp(r'^\s*ShuzlmID\s*[:：]\s*([^\r\n]*)$',
            multiLine: true, caseSensitive: false)
        .allMatches(text.replaceAll('\uFEFF', ''))
        .toList();
    if (matches.length != 1) {
      throw const FormatException(
          '未识别到唯一的 ShuzlmID。请在官方同一页面累计点击“复制 OAID”5次，再粘贴完整内容');
    }
    final id = matches.single.group(1)!.trim();
    if (id.toLowerCase() == 'null' ||
        id.toLowerCase() == 'undefined' ||
        validate(id) == null) {
      throw const FormatException('数盟 ID 为空或格式不正确，请打开官方酷安稍等后重新复制');
    }
    return id;
  }
}
