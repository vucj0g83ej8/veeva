// ignore_for_file: avoid_web_libraries_in_flutter

@TestOn('browser')
library;

import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veeva_member_app/survey_embed_web.dart';

void main() {
  testWidgets('OneTrust submit event completes the survey once',
      (tester) async {
    var completedCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmbeddedSurveyWebForm(
            url: 'https://privacyportal.onetrust.com/webform/test',
            onSurveyCompleted: () => completedCount += 1,
          ),
        ),
      ),
    );
    await tester.pump();

    html.window.dispatchEvent(
      html.CustomEvent('OneTrustWebFormSubmitted', detail: {
        'requestId': 'request-001',
      }),
    );
    await tester.pump();

    html.window.dispatchEvent(
      html.CustomEvent('OneTrustWebFormSubmitted', detail: {
        'requestId': 'request-001',
      }),
    );
    await tester.pump();

    expect(completedCount, 1);
  });

  testWidgets('trusted OneTrust postMessage completes the survey',
      (tester) async {
    var completedCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmbeddedSurveyWebForm(
            url: 'https://privacyportal.onetrust.com/webform/test',
            onSurveyCompleted: () => completedCount += 1,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final iframe = html.document.querySelector(
      'iframe[data-veeva-survey-iframe="true"]',
    ) as html.IFrameElement?;

    final eventInit = js_util.newObject();
    js_util.setProperty(
      eventInit,
      'data',
      js_util.jsify({
        'source': 'OneTrust',
        'event': 'WebFormSubmitted',
        'requestId': 'request-002',
      }),
    );
    js_util.setProperty(
      eventInit,
      'origin',
      'https://privacyportal.onetrust.com',
    );
    js_util.setProperty(eventInit, 'source', iframe?.contentWindow);
    final messageEvent = js_util.callConstructor<html.Event>(
      js_util.getProperty<Object>(html.window, 'MessageEvent'),
      ['message', eventInit],
    );
    html.window.dispatchEvent(messageEvent);
    await tester.pump();

    expect(completedCount, 1);
  });

}
