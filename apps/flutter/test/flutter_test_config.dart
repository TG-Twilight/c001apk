import 'dart:async';
import 'dart:io';

// Existing API tests replace Dio's transport. Identity registration uses a
// separate HttpClient and must also stay offline unless a test supplies a fake.
class _OfflineRegistration extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..connectionFactory = (uri, proxyHost, proxyPort) {
        if (uri.host == 'auni.telecome.cn' ||
            uri.host == 'global-auni.checktrustworthiness.com') {
          throw const SocketException(
              'Identity registration is offline in tests');
        }
        return Socket.startConnect(
            proxyHost ?? uri.host, proxyPort ?? uri.port);
      };
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  HttpOverrides.global = _OfflineRegistration();
  await testMain();
}
