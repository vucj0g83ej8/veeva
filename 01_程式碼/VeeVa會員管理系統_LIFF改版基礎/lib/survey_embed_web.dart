// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      return html.IFrameElement()
        ..src = widget.url
        ..title = 'Veeva 問卷填寫'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.borderRadius = '8px'
        ..allow = 'clipboard-read; clipboard-write'
        ..referrerPolicy = 'strict-origin-when-cross-origin';
    });
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
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('submit-survey-button'),
                onPressed: widget.onSurveyCompleted,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('我已完成問卷，送出審核'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
