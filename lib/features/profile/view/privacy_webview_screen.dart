import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_urls.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';

class PrivacyWebViewScreen extends StatefulWidget {
  const PrivacyWebViewScreen({
    super.key,
    this.initialUrl = AppUrls.privacyPolicy,
    this.webViewOverride,
  });

  final String initialUrl;

  /// Replaces the platform web view. Tests use this so the screen can render
  /// without a [WebViewController].
  final WidgetBuilder? webViewOverride;

  @override
  State<PrivacyWebViewScreen> createState() => _PrivacyWebViewScreenState();
}

class _PrivacyWebViewScreenState extends State<PrivacyWebViewScreen> {
  WebViewController? _controller;
  var _isLoading = true;
  var _hasFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.webViewOverride != null) {
      _isLoading = false;
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(ZipColors.ink)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _markLoading(),
          onPageFinished: (_) => _markFinished(),
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            _markFailed();
          },
          onHttpError: (error) {
            final uri = error.request?.uri;
            if (uri != null && uri.toString() != widget.initialUrl) return;
            _markFailed();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
    _controller = controller;
  }

  void _markLoading() {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasFailed = false;
    });
  }

  void _markFinished() {
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _markFailed() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasFailed = true;
    });
  }

  void _retry() {
    final controller = _controller;
    if (controller == null) return;
    _markLoading();
    controller.loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZipColors.ink,
      appBar: AppBar(
        title: const Text(AppStrings.profilePrivacyPolicy),
        backgroundColor: ZipColors.ink,
        foregroundColor: ZipColors.onInk,
      ),
      body: _hasFailed
          ? _FailureBody(onRetry: _retry)
          : _WebBody(
              isLoading: _isLoading,
              controller: _controller,
              webViewOverride: widget.webViewOverride,
            ),
    );
  }
}

class _WebBody extends StatelessWidget {
  const _WebBody({
    required this.isLoading,
    required this.controller,
    required this.webViewOverride,
  });

  final bool isLoading;
  final WebViewController? controller;
  final WidgetBuilder? webViewOverride;

  @override
  Widget build(BuildContext context) {
    final override = webViewOverride;
    final webController = controller;
    return Stack(
      children: [
        if (override != null)
          override(context)
        else if (webController != null)
          WebViewWidget(controller: webController),
        if (isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.profilePrivacyFailed,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: ZipColors.onInk),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text(AppStrings.profilePrivacyRetry),
            ),
          ],
        ),
      ),
    );
  }
}
