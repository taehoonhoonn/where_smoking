import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'mobile_config.dart';

void runMobileApp() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MobileWebViewApp());
}

class MobileWebViewApp extends StatelessWidget {
  const MobileWebViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '흡연구역 찾기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MobileWebViewHome(),
    );
  }
}

class MobileWebViewHome extends StatefulWidget {
  const MobileWebViewHome({super.key});

  @override
  State<MobileWebViewHome> createState() => _MobileWebViewHomeState();
}

class _MobileWebViewHomeState extends State<MobileWebViewHome> {
  late final WebViewController _controller;
  double _loadingProgress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _hasError = false;
  String? _lastErrorMessage;
  late final Uri _initialUri;

  @override
  void initState() {
    super.initState();
    _initialUri = Uri.parse(getInitialWebAppUrl());

    PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();

    if (Platform.isIOS) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    }

    final controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (WebViewPermissionRequest request) {
        request.grant();
      },
    );

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() {
              _loadingProgress = 0;
              _hasError = false;
              _lastErrorMessage = null;
            });
          },
          onProgress: (progress) {
            setState(() {
              _loadingProgress = progress.clamp(0, 100) / 100;
            });
          },
          onPageFinished: (_) async {
            await _updateNavigationAvailability();
            if (mounted) {
              setState(() {
                _loadingProgress = 0;
              });
            }
          },
          onWebResourceError: (error) {
            setState(() {
              _hasError = true;
              _lastErrorMessage = error.description.isNotEmpty
                  ? error.description
                  : (error.errorType?.name ?? 'unknown');
            });
          },
        ),
      )
      ..loadRequest(_initialUri);

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final AndroidWebViewController androidController =
          controller.platform as AndroidWebViewController;
      unawaited(androidController.setMediaPlaybackRequiresUserGesture(false));
      unawaited(androidController.setGeolocationEnabled(true));
      unawaited(
        androidController.setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: (GeolocationPermissionsRequestParams params) async {
            return const GeolocationPermissionsResponse(
              allow: true,
              retain: true,
            );
          },
        ),
      );
    }

    if (controller.platform is WebKitWebViewController) {
      (controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    _controller = controller;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLocationPermission();
    });
  }

  Future<void> _ensureLocationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    PermissionStatus status = await Permission.locationWhenInUse.status;
    if (status.isGranted || status.isLimited) {
      return;
    }

    status = await Permission.locationWhenInUse.request();

    if (!mounted) {
      return;
    }

    if (status.isGranted || status.isLimited) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('위치 권한을 허용해야 현재 위치 기능을 사용할 수 있습니다.'),
        action: status.isPermanentlyDenied
            ? SnackBarAction(label: '설정 열기', onPressed: openAppSettings)
            : null,
      ),
    );
  }

  Future<void> _updateNavigationAvailability() async {
    final canGoBack = await _controller.canGoBack();
    final canGoForward = await _controller.canGoForward();
    if (!mounted) {
      return;
    }
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  Future<void> _reload() async {
    setState(() {
      _hasError = false;
      _lastErrorMessage = null;
    });
    await _controller.reload();
  }

  Future<void> _goBack() async {
    if (!_canGoBack) return;
    await _controller.goBack();
    await _updateNavigationAvailability();
  }

  Future<void> _goForward() async {
    if (!_canGoForward) return;
    await _controller.goForward();
    await _updateNavigationAvailability();
  }

  Widget _buildErrorView() {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '페이지를 불러오지 못했습니다.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _lastErrorMessage ?? '네트워크 연결을 확인한 뒤 다시 시도해주세요.',
            style: const TextStyle(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        if (await _controller.canGoBack()) {
          await _controller.goBack();
          await _updateNavigationAvailability();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('흡연구역 찾기'),
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _canGoBack ? _goBack : null,
              tooltip: '이전으로',
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _canGoForward ? _goForward : null,
              tooltip: '다음으로',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reload,
              tooltip: '새로고침',
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_hasError) Positioned.fill(child: _buildErrorView()),
            if (_loadingProgress > 0 && _loadingProgress < 1)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(value: _loadingProgress),
              ),
          ],
        ),
      ),
    );
  }
}
