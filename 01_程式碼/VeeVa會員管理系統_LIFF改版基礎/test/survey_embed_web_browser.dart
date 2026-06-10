// ignore_for_file: avoid_web_libraries_in_flutter

@TestOn('browser')
library;

import 'dart:html' as html;

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

    html.window.dispatchEvent(
      html.MessageEvent(
        'message',
        data: {
          'source': 'OneTrust',
          'event': 'WebFormSubmitted',
          'requestId': 'request-002',
        },
        origin: 'https://privacyportal.onetrust.com',
      ),
    );
    await tester.pump();

    expect(completedCount, 1);
  });
}
