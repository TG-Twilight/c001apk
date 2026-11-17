import '../logic/model/feed/datum.dart';
import 'emoji_util.dart';

final _tags = RegExp(r'<[^>]*>');
final _entities = RegExp(r'&(nbsp|#160|#xa0);', caseSensitive: false);

// Exactly the emoji on the composer's coin tab: every key containing 酷币
// ([酷币5毛], [灰色酷币], [新酷币2€] ...) plus [新币1分].
final _coinEmoji = RegExp(EmojiUtil.emojiMap.keys
    .where((key) => key.contains('酷币') || key == '[新币1分]')
    .map(RegExp.escape)
    .join('|'));

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
