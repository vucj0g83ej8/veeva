import 'package:flutter/material.dart';

class EmbeddedSurveyWebForm extends StatelessWidget {
  const EmbeddedSurveyWebForm({
    required this.url,
    required this.onSurveyCompleted,
    super.key,
  });

  final String url;
  final VoidCallback onSurveyCompleted;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Veeva 問卷表單',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              url,
              style: const TextStyle(color: Color(0xFF216B57)),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 320,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6F4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDDE5DF)),
              ),
              child: const Text('跨平台 WebView 預覽區'),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('submit-survey-button'),
                onPressed: onSurveyCompleted,
                icon: const Icon(Icons.send_outlined),
                label: const Text('我已完成問卷，送出審核'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
