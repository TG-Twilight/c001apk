import '../logic/model/feed/datum.dart';

final _tags = RegExp(r'<[^>]*>');
final _entities = RegExp(r'&(nbsp|#160|#xa0);', caseSensitive: false);
// The coin family shown on the emoji panel's coin tab: [酷币], [酷币1分] ...
// [酷币2€], plus [新币1分].
final _coinEmoji = RegExp(r'\[(?:酷币[^\[\]\s]{0,6}|新币1分)\]');

/// True when a reply says nothing but coin emoji: at least one coin token,
/// otherwise only whitespace, and no pictures.
bool isCoinOnlyText(String message) {
  final text = message.replaceAll(_tags, '').replaceAll(_entities, ' ');
  if (!_coinEmoji.hasMatch(text)) return false;
  return text.replaceAll(_coinEmoji, '').trim().isEmpty;
}

bool isCoinOnlyReply(Datum reply) =>
    (reply.picArr == null || reply.picArr!.every((pic) => pic.isEmpty)) &&
    (reply.pic == null || reply.pic!.isEmpty) &&
    isCoinOnlyText(reply.message ?? '');
