// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'dart:async';
import 'dart:convert';
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class EmbeddedSurveyWebForm extends StatefulWidget {
  const EmbeddedSurveyWebForm({
    required this.url,
    required this.onSurveyCompleted,
    super.key,
  });

  final String url;
  final VoidCallback onSurveyCompleted;

  @override
  State<EmbeddedSurveyWebForm> createState() => _EmbeddedSurveyWebFormState();
}

class _EmbeddedSurveyWebFormState extends State<EmbeddedSurveyWebForm> {
  late final String viewType =
      'veeva-survey-iframe-${widget.url.hashCode}-${identityHashCode(this)}';
  late final html.IFrameElement _iframe;
  StreamSubscription<html.Event>? _formSubmittedSubscription;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  bool _completionCaptured = false;

  @override
  void initState() {
    super.initState();
    _iframe = html.IFrameElement()
      ..src = widget.url
      ..title = 'Veeva 問卷填寫'
      ..dataset['veevaSurveyIframe'] = 'true'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.borderRadius = '8px'
      ..allow = 'clipboard-read; clipboard-write'
      ..referrerPolicy = 'strict-origin-when-cross-origin';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      return _iframe;
    });
    _formSubmittedSubscription =
        html.window.on['OneTrustWebFormSubmitted'].listen(
      (_) => _completeFromOneTrustSignal('OneTrustWebFormSubmitted'),
    );
    _messageSubscription = html.window.onMessage.listen(_handleMessage);
  }

  @override
  void dispose() {
    _formSubmittedSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  void _handleMessage(html.MessageEvent event) {
    if (!_isTrustedOneTrustMessage(event, widget.url, _iframe)) {
      return;
    }
    final messageText = _stringifyMessageData(event.data);
    _rememberLastOneTrustMessage(messageText);
    if (!_looksLikeOneTrustSubmission(messageText)) {
      return;
    }
    _completeFromOneTrustSignal('OneTrustPostMessage');
  }

  void _completeFromOneTrustSignal(String source) {
    if (_completionCaptured || !mounted) {
      return;
    }
    _completionCaptured = true;
    html.window.console.info('VeeVa survey completed by $source');
    widget.onSurveyCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final iframeHeight = screenHeight < 760 ? 560.0 : 680.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: iframeHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDDE5DF)),
              ),
              clipBehavior: Clip.antiAlias,
              child: HtmlElementView(viewType: viewType),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isTrustedOneTrustMessage(
  html.MessageEvent event,
  String formUrl,
  html.IFrameElement iframe,
) {
  if (!_isTrustedOneTrustOrigin(event.origin, formUrl)) {
    return false;
  }
  final source = event.source;
  final iframeWindow = iframe.contentWindow;
  if (source != null && iframeWindow != null && source != iframeWindow) {
    return false;
  }
  return true;
}

bool _isTrustedOneTrustOrigin(String origin, String formUrl) {
  final originUri = Uri.tryParse(origin);
  final formUri = Uri.tryParse(formUrl);
  if (originUri == null || originUri.scheme != 'https') {
    return false;
  }
  final host = originUri.host.toLowerCase();
  final formHost = formUri?.host.toLowerCase();
  if (formHost != null && formHost.isNotEmpty && host == formHost) {
    return true;
  }
  return host == 'onetrust.com' || host.endsWith('.onetrust.com');
}

bool _looksLikeOneTrustSubmission(String messageText) {
  final normalized = messageText.toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  final hasSubmitSignal = normalized.contains('submit') ||
      normalized.contains('submitted') ||
      normalized.contains('submission') ||
      normalized.contains('requestsubmission') ||
      normalized.contains('request_submission') ||
      normalized.contains('request id') ||
      normalized.contains('requestid') ||
      normalized.contains('webformsubmitted') ||
      normalized.contains('formsubmitted');
  if (!hasSubmitSignal) {
    return false;
  }
  return normalized.contains('onetrust') ||
      normalized.contains('webform') ||
      normalized.contains('privacyportal') ||
      normalized.contains('request') ||
      normalized.contains('form');
}

String _stringifyMessageData(Object? data) {
  if (data == null) {
    return '';
  }
  if (data is String) {
    return data;
  }
  if (data is num || data is bool) {
    return data.toString();
  }
  try {
    return jsonEncode(data);
  } catch (_) {
    try {
      final jsonObject = js_util.getProperty<Object?>(html.window, 'JSON');
      if (jsonObject != null) {
        final value = js_util.callMethod<Object?>(
          jsonObject,
          'stringify',
          [data],
        );
        if (value is String) {
          return value;
        }
      }
    } catch (_) {
      // Fall through to the object's basic representation.
    }
  }
  return data.toString();
}

void _rememberLastOneTrustMessage(String messageText) {
  try {
    js_util.setProperty(html.window, 'veevaLastOneTrustMessage', messageText);
  } catch (_) {
    // Debug-only helper; failure should not affect completion detection.
  }
}
