import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'components/custom_toast.dart';
import 'components/app_keyboard_navigation.dart';
import 'components/announcement_monitor.dart';
import 'logic/announcements/app_announcements.dart';
import 'constants/constants.dart';
import 'logic/network/request.dart';
import 'logic/szlm_identity_service.dart';
import 'pages/webview/captcha_page.dart';
import 'router/app_pages.dart';
import 'router/page_transitions.dart';
import 'utils/storage_util.dart';
import 'utils/app_theme.dart';
import 'utils/desktop_window.dart';
import 'utils/android_links.dart';
import 'utils/utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    // The native runner starts on the primary display. Keep sizing and
    // positioning there so mixed-DPI monitors do not mix logical coordinates.
    final display = await screenRetriever.getPrimaryDisplay();
    final bounds = desktopStartupBounds(
        (display.visiblePosition ?? Offset.zero) &
            (display.visibleSize ?? display.size));
    WindowOptions windowOptions = WindowOptions(
      minimumSize: Size(bounds.width.clamp(0, 400).toDouble(),
          bounds.height.clamp(0, 540).toDouble()),
      size: bounds.size,
      skipTaskbar: false,
      titleBarStyle:
          Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions);
    await windowManager.setPosition(bounds.topLeft);
    await windowManager.show();
    await windowManager.focus();
  }

  await GStorage.init();
  // An identity that is already stored is reused as-is; only a first run, or
  // one whose identity was rejected, has to register a device. The call must
  // not delay the first frame.
  unawaited(SzlmIdentityService.instance.ensure());
  await AppAnnouncements.initialize();
  HttpOverrides.global = CustomHttpOverrides();

  if (Platform.isAndroid || Platform.isIOS) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
      statusBarBrightness: GStorage.getBrightness(),
      systemNavigationBarIconBrightness: GStorage.getBrightness(),
    ));
  }

  Request().captchaVerifier = verifyCaptcha;
  final links = Platform.isAndroid
      ? (AndroidLinks(onOpen: Utils.onOpenLink)..listen())
      : null;
  runApp(AnnouncementMonitor(
      service: AppAnnouncements.service!, child: const C001APKAPP()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (links != null) unawaited(links.ready());
  });
}

class C001APKAPP extends StatelessWidget {
  const C001APKAPP({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
      return ValueListenableBuilder(
        valueListenable: GStorage.settings.listenable(keys: [
          SettingsBoxKey.useMaterial,
          SettingsBoxKey.staticColor,
          SettingsBoxKey.selectedTheme,
          SettingsBoxKey.fontScale,
        ]),
        builder: (context, settings, _) =>
            _buildApp(context, lightDynamic, darkDynamic),
      );
    });
  }

  Widget _buildApp(BuildContext context, ColorScheme? lightDynamic,
      ColorScheme? darkDynamic) {
    bool useMaterial =
        GStorage.settings.get(SettingsBoxKey.useMaterial, defaultValue: true);
    int staticColor =
        GStorage.settings.get(SettingsBoxKey.staticColor, defaultValue: 0);
    double fontScale =
        GStorage.settings.get(SettingsBoxKey.fontScale, defaultValue: 1.0);
    ColorScheme? lightColorScheme;
    ColorScheme? darkColorScheme;
    if (lightDynamic != null && darkDynamic != null && useMaterial) {
      lightColorScheme = lightDynamic.harmonized();
      darkColorScheme = darkDynamic.harmonized();
    } else {
      lightColorScheme = ColorScheme.fromSeed(
        seedColor: Constants.seedColors[staticColor],
        brightness: Brightness.light,
      );
      darkColorScheme = ColorScheme.fromSeed(
        seedColor: Constants.seedColors[staticColor],
        brightness: Brightness.dark,
      );
    }

    final lightTheme = applyAppTypography(ThemeData(
      colorScheme: lightColorScheme,
      useMaterial3: true,
      navigationBarTheme: NavigationBarThemeData(
          surfaceTintColor: (lightDynamic != null && useMaterial)
              ? lightColorScheme.surfaceTint
              : lightColorScheme.surfaceContainer),
      snackBarTheme: SnackBarThemeData(
        actionTextColor: lightColorScheme.primary,
        backgroundColor: lightColorScheme.secondaryContainer,
        closeIconColor: lightColorScheme.secondary,
        contentTextStyle: TextStyle(color: lightColorScheme.secondary),
        elevation: 20,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: AppPredictiveBackPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      popupMenuTheme: PopupMenuThemeData(
        surfaceTintColor: lightColorScheme.surfaceTint,
      ),
      cardTheme: CardThemeData(
        surfaceTintColor: lightColorScheme.surfaceTint,
        shadowColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        surfaceTintColor: lightColorScheme.surfaceTint,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: lightColorScheme.onInverseSurface,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        refreshBackgroundColor: lightColorScheme.onSecondary,
      ),
    ));
    final darkTheme = applyAppTypography(ThemeData(
      colorScheme: darkColorScheme,
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: AppPredictiveBackPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      navigationBarTheme: NavigationBarThemeData(
          surfaceTintColor: (lightDynamic != null && useMaterial)
              ? darkColorScheme.surfaceTint
              : darkColorScheme.surfaceContainer),
      snackBarTheme: SnackBarThemeData(
        actionTextColor: darkColorScheme.primary,
        backgroundColor: darkColorScheme.secondaryContainer,
        closeIconColor: darkColorScheme.secondary,
        contentTextStyle: TextStyle(color: darkColorScheme.secondary),
        elevation: 20,
      ),
      popupMenuTheme: PopupMenuThemeData(
        surfaceTintColor: darkColorScheme.surfaceTint,
      ),
      cardTheme: CardThemeData(
        surfaceTintColor: darkColorScheme.surfaceTint,
        shadowColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        surfaceTintColor: darkColorScheme.surfaceTint,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: darkColorScheme.onInverseSurface,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        refreshBackgroundColor: darkColorScheme.onSecondary,
      ),
    ));
    return GetMaterialApp(
      title: Constants.APP_NAME,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: GStorage.getThemeMode(),
      getPages: AppPages.getPages,
      customTransition: AppPageTransition(),
      transitionDuration: const Duration(milliseconds: 450),
      initialRoute: '/',
      builder: (BuildContext context, Widget? child) {
        final brightness = switch (GStorage.getThemeMode()) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => MediaQuery.platformBrightnessOf(context),
        };
        // GetMaterialApp retains its initial themes. Apply the current theme
        // above the navigator so asynchronous system colors and settings
        // changes also reach existing routes and dialogs.
        return AnimatedTheme(
          data: brightness == Brightness.dark ? darkTheme : lightTheme,
          child: FlutterSmartDialog(
            toastBuilder: (String msg) => CustomToast(msg: msg),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: AppTextScaler(
                      MediaQuery.textScalerOf(context), fontScale)),
              child: NotificationListener<NavigationNotification>(
                onNotification: (notification) {
                  if (Platform.isAndroid) {
                    unawaited(const MethodChannel('samples.flutter.dev/channel')
                        .invokeMethod<void>('setPredictiveBackEnabled',
                            notification.canHandlePop));
                  }
                  return false;
                },
                child: AppKeyboardNavigation(
                  navigatorKey: Get.key,
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CustomHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..userAgent = GStorage.userAgent;
  }
}
