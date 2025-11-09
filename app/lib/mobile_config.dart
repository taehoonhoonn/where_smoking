import 'dart:io' show Platform;

const String _defaultWebAppUrl = String.fromEnvironment(
  'WEB_APP_URL',
  defaultValue: 'https://wheresmoking.kr',
);

const bool _preferLocalWebApp = bool.fromEnvironment(
  'USE_LOCAL_WEB_APP',
  defaultValue: false,
);

const String _localWebAppUrl = String.fromEnvironment(
  'LOCAL_WEB_APP_URL',
  defaultValue: 'http://localhost:8080',
);

String getInitialWebAppUrl() {
  final target = _preferLocalWebApp ? _localWebAppUrl : _defaultWebAppUrl;

  if (target.contains('localhost')) {
    // Map emulator loopback domains to host equivalents.
    if (Platform.isAndroid) {
      return target.replaceFirst('localhost', '10.0.2.2');
    }
    if (Platform.isIOS) {
      return target.replaceFirst('localhost', '127.0.0.1');
    }
  }

  return target;
}
