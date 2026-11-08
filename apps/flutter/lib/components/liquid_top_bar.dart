import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../utils/storage_util.dart';
import '../utils/extensions.dart';
import 'basic_glass.dart';
export 'basic_glass.dart' show LiquidGlassButton;

/// Root toolbar surfaces share the navigation glass preference and optics.
/// Keep the body in the same element slot when preferences change.
class LiquidTopBarScaffold extends StatelessWidget {
  const LiquidTopBarScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onSearch,
    this.actions = const [],
    this.overlayBody = true,
    this.titleSpacing,
    this.glassTitle,
    this.compactTitle = false,
    this.floatWithoutGlass = false,
    this.glassActions,
  });

  final Widget title, body;

  /// Root pages opt in without changing the body element's position.
  final WidgetBuilder? glassTitle;
  final List<Widget> Function(BuildContext context)? glassActions;
  final bool compactTitle, floatWithoutGlass;
  final VoidCallback? onSearch;
  final List<Widget> actions;
  final bool overlayBody;
  final double? titleSpacing;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: GStorage.settings.listenable(keys: [
          SettingsBoxKey.floatingNavigation,
          SettingsBoxKey.liquidGlass,
          SettingsBoxKey.liquidGlassLevel,
        ]),
        builder: (context, _, __) {
          final media = MediaQuery.of(context);
          final glass = glassTitle != null &&
              GStorage.floatingNavigation &&
              (GStorage.liquidGlass || floatWithoutGlass);
          final height = glass
              ? math.max(64.0, media.textScaler.scale(20) + 16)
              : kToolbarHeight;
          final inset = media.padding.top + height;
          final overlay = glass && overlayBody;
          final search = IconButton(
            onPressed: onSearch,
            icon: const Icon(Icons.search),
            tooltip: '搜索',
          );
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: height,
              titleSpacing: glass ? 12 : titleSpacing,
              backgroundColor: glass ? Colors.transparent : null,
              forceMaterialTransparency: glass,
              systemOverlayStyle:
                  glass ? context.fitSystemUiOverlayStyle : null,
              elevation: glass ? 0 : null,
              scrolledUnderElevation: glass ? 0 : null,
              title: glass
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: compactTitle ? double.infinity : 720),
                        child: Row(children: [
                          Flexible(
                            fit: compactTitle ? FlexFit.tight : FlexFit.loose,
                            child: Align(
                                widthFactor: compactTitle ? null : 1,
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  key: const ValueKey('glass-top-title'),
                                  height: height - 16,
                                  child: glassTitle!(context),
                                )),
                          ),
                          if (onSearch != null) ...[
                            const SizedBox(width: 10),
                            LiquidGlassButton(
                              key: const ValueKey('glass-search'),
                              level: GStorage.liquidGlassLevel,
                              enabled: GStorage.liquidGlass,
                              tooltip: '搜索',
                              height: height - 16,
                              width: height - 16,
                              onPressed: onSearch!,
                              child: const Center(child: Icon(Icons.search)),
                            ),
                          ],
                          if (glassActions != null) ...glassActions!(context),
                        ]),
                      ),
                    )
                  : title,
              actions:
                  glass ? null : [...actions, if (onSearch != null) search],
            ),
            body: Padding(
              padding: EdgeInsets.only(top: overlay ? 0 : inset),
              child: MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(top: overlay ? inset : 0),
                ),
                child: body,
              ),
            ),
          );
        },
      );
}
