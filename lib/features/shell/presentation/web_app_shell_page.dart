import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/app_config.dart';

class WebAppShellPage extends StatefulWidget {
  const WebAppShellPage({
    super.key,
    required this.config,
    required this.onLogout,
  });

  final AppConfig config;
  final Future<void> Function() onLogout;

  @override
  State<WebAppShellPage> createState() => _WebAppShellPageState();
}

class _WebAppShellPageState extends State<WebAppShellPage>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  late final Uri _startUri;
  late final Set<String> _allowedHosts;

  int _progress = 0;
  bool _hasMainFrameError = false;
  String _errorMessage = '';
  Uri? _currentUri;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _startUri = widget.config.webAppUrl;
    _allowedHosts = widget.config.allowedHosts;
    _currentUri = _startUri;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (!mounted) return;
            setState(() => _progress = value.clamp(0, 100));
          },
          onPageStarted: (url) {
            _setCurrentUri(url);
            if (!mounted) return;
            setState(() {
              _hasMainFrameError = false;
              _errorMessage = '';
            });
          },
          onPageFinished: (url) {
            _setCurrentUri(url);
            if (!mounted) return;
            setState(() => _progress = 100);
          },
          onNavigationRequest: _onNavigationRequest,
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            if (!mounted) return;
            setState(() {
              _hasMainFrameError = true;
              _errorMessage = error.description;
            });
          },
        ),
      )
      ..loadRequest(_startUri);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.runJavaScript('window.dispatchEvent(new Event("focus"));');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<NavigationDecision> _onNavigationRequest(
    NavigationRequest request,
  ) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    _currentUri = uri;

    if (_isDownloadUrl(uri) ||
        _isExternalScheme(uri) ||
        !_isInternalHost(uri)) {
      await _openExternal(uri);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  bool _isExternalScheme(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return scheme != 'http' && scheme != 'https';
  }

  bool _isInternalHost(Uri uri) {
    final host = uri.host.toLowerCase();
    return _allowedHosts.any((allowedHost) {
      return host == allowedHost || host.endsWith('.$allowedHost');
    });
  }

  bool _isDownloadUrl(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.endsWith('.pdf') ||
        path.endsWith('.zip') ||
        path.endsWith('.xlsx') ||
        path.endsWith('.xls') ||
        path.endsWith('.csv');
  }

  Future<void> _openExternal(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel abrir o link.')),
      );
    }
  }

  Future<void> _reload() async {
    setState(() {
      _hasMainFrameError = false;
      _errorMessage = '';
      _progress = 0;
    });
    await _controller.reload();
  }

  Future<void> _goHome() async {
    setState(() {
      _hasMainFrameError = false;
      _errorMessage = '';
      _progress = 0;
    });
    await _controller.loadRequest(_startUri);
  }

  void _setCurrentUri(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed != null) {
      _currentUri = parsed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
          return;
        }
        await SystemNavigator.pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  if (_progress < 100)
                    LinearProgressIndicator(
                      value: _progress == 0 ? null : _progress / 100,
                      minHeight: 2,
                    ),
                  Expanded(child: WebViewWidget(controller: _controller)),
                ],
              ),
              if (_hasMainFrameError)
                _ErrorOverlay(
                  message: _errorMessage,
                  onRetry: _reload,
                  onGoHome: _goHome,
                ),
            ],
          ),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'refresh',
              onPressed: _reload,
              child: const Icon(Icons.refresh),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.small(
              heroTag: 'external',
              onPressed: _currentUri == null
                  ? null
                  : () => _openExternal(_currentUri!),
              child: const Icon(Icons.open_in_browser),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.small(
              heroTag: 'logout',
              onPressed: widget.onLogout,
              child: const Icon(Icons.logout),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({
    required this.message,
    required this.onRetry,
    required this.onGoHome,
  });

  final String message;
  final Future<void> Function() onRetry;
  final Future<void> Function() onGoHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xF0101114),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: Colors.white70),
            const SizedBox(height: 16),
            const Text(
              'Falha ao carregar o app',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message.isEmpty
                  ? 'Verifique sua conexao e tente novamente.'
                  : message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onGoHome,
                child: const Text('Ir para inicio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
