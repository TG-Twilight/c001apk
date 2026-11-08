import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:get/get.dart';
import 'package:html/dom.dart' as dom;

import '../utils/markdown_content.dart';
import '../utils/storage_util.dart';
import '../utils/utils.dart';
import 'html_text.dart';
import 'imageview.dart';
import '../logic/media/feed_media.dart';

/// Posts opt into Markdown without changing the legacy comment/chat renderer.
class FeedText extends StatelessWidget {
  const FeedText(this.source,
      {super.key,
      this.fontSize = 16,
      this.lineHeight = 1.5,
      this.preview = false,
      this.forcePlain = false,
      this.picArr,
      this.mediaItems,
      this.contentId,
      this.contentType = MediaContentType.feed});

  final String source;
  final double fontSize;
  final double lineHeight;
  final bool preview;
  final bool forcePlain;
  final List<String>? picArr;
  final List<FeedMedia>? mediaItems;
  final String? contentId;
  final MediaContentType contentType;

  @override
  Widget build(BuildContext context) {
    if (forcePlain) {
      return SelectableText(source,
          style: TextStyle(fontSize: fontSize, height: lineHeight));
    }
    final content =
        MarkdownContent.parse(source, showEmoji: GStorage.showEmoji);
    if (!content.isMarkdown) {
      return htmlText(source,
          fontSize: fontSize,
          lineHeight: lineHeight,
          picArr: picArr,
          mediaItems: mediaItems,
          contentId: contentId,
          contentType: contentType);
    }
    if (preview) {
      return Text(content.preview,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: fontSize, height: 1.5));
    }
    return MarkdownBody(
        content: content,
        fontSize: fontSize,
        lineHeight: lineHeight,
        picArr: picArr,
        mediaItems: mediaItems,
        contentId: contentId,
        contentType: contentType);
  }
}

class MarkdownBody extends StatelessWidget {
  const MarkdownBody(
      {super.key,
      required this.content,
      this.fontSize = 16,
      this.lineHeight = 1.5,
      this.baseUrl,
      this.picArr,
      this.mediaItems,
      this.contentId,
      this.contentType = MediaContentType.feed,
      this.onTapUrl});

  final MarkdownContent content;
  final double fontSize;
  final double lineHeight;
  final Uri? baseUrl;
  final List<String>? picArr;
  final List<FeedMedia>? mediaItems;
  final String? contentId;
  final MediaContentType contentType;
  final FutureOr<bool> Function(String)? onTapUrl;

  @override
  Widget build(BuildContext context) {
    if (!content.isMarkdown) {
      return SelectableText(content.source,
          style: TextStyle(fontSize: fontSize, height: lineHeight));
    }
    final colors = Theme.of(context).colorScheme;
    final effectiveBase = baseUrl ?? Uri.parse('https://www.coolapk.com/');
    Map<String, String>? styles(dom.Element element) {
      switch (element.localName) {
        case 'a':
          return {'text-decoration': 'none'};
        case 'p':
          return {'margin': '0 0 10px 0'};
        case 'h1':
        case 'h2':
        case 'h3':
        case 'h4':
        case 'h5':
        case 'h6':
          return {'margin': '14px 0 8px 0', 'line-height': '1.35'};
        case 'blockquote':
          return {
            'margin': '8px 0',
            'padding-left': '12px',
            'border-left':
                '3px solid #${colors.outlineVariant.toARGB32().toRadixString(16).substring(2)}'
          };
        case 'th':
        case 'td':
          return {
            'padding': '8px',
            'border':
                '1px solid #${colors.outlineVariant.toARGB32().toRadixString(16).substring(2)}'
          };
        case 'code':
          return {
            'font-family': 'monospace',
            'background-color':
                '#${colors.surfaceContainerHighest.toARGB32().toRadixString(16).substring(2)}'
          };
      }
      return null;
    }

    FutureOr<bool> open(String url) {
      if (url.startsWith('#') || url.startsWith('$effectiveBase#')) {
        return false;
      }
      if (!MarkdownContent.allowsUrl(url)) return true;
      if (onTapUrl != null) return onTapUrl!(url);
      final uri = Uri.tryParse(url);
      if (uri?.host == 'image.coolapk.com' &&
          ['http', 'https'].contains(uri?.scheme)) {
        final images = {...?picArr, ...content.imageUrls, url}.toList();
        Get.toNamed('/imageview',
            arguments: mediaGalleryArguments(images,
                mediaItems: mediaItems,
                contentId: contentId,
                contentType: contentType,
                initialPage: images.indexOf(url)));
        return true;
      }
      final resolved = baseUrl?.resolve(url).toString() ?? url;
      Utils.onOpenLink(resolved, null, true, context);
      return true;
    }

    Widget? custom(dom.Element element) {
      if (element.localName == 'pre') {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(element.text.replaceFirst(RegExp(r'\n$'), ''),
                style: TextStyle(
                    fontFamily: 'monospace',
                    color: colors.onSurface,
                    fontSize: fontSize * .9,
                    height: 1.5)),
          ),
        );
      }
      if (element.localName == 'img') {
        final emoji = element.attributes['data-emoji'];
        if (emoji != null) {
          final size = MediaQuery.textScalerOf(context).scale(fontSize) * 1.3;
          return InlineCustomWidget(
            alignment: PlaceholderAlignment.middle,
            child: emoji.endsWith('.png')
                ? Image.asset('assets/emojis/$emoji', width: size, height: size)
                : emoji.endsWith('.icon')
                    ? Icon(Icons.photo_outlined,
                        size: size, color: colors.primary)
                    : Text(emoji,
                        style: TextStyle(
                            color: colors.primary, fontSize: fontSize - 2)),
          );
        }
        final src = element.attributes['src'] ?? '';
        if (!MarkdownContent.allowsUrl(src, image: true)) {
          return const SizedBox.shrink();
        }
        final images = {...?picArr, ...content.imageUrls, src}.toList();
        final arguments = mediaGalleryArguments(images,
            mediaItems: mediaItems,
            contentId: contentId,
            contentType: contentType,
            initialPage: images.indexOf(src));
        final media = arguments['mediaItems'] as List<FeedMedia>;
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: GestureDetector(
              onTap: () => Get.toNamed('/imageview', arguments: arguments),
              child: mediaThumbnail(media[images.indexOf(src)],
                  fit: BoxFit.contain),
            ));
      }
      return null;
    }

    return HtmlWidget(content.html,
        baseUrl: effectiveBase,
        rebuildTriggers: [colors, MediaQuery.textScalerOf(context)],
        textStyle: TextStyle(fontSize: fontSize, height: lineHeight),
        customStylesBuilder: styles,
        customWidgetBuilder: custom,
        onTapUrl: open);
  }
}
