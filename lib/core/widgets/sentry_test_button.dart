// lib/features/auth/widgets/sentry_test_button.dart

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SentryTestButton extends StatelessWidget {
  const SentryTestButton({Key? key}) : super(key: key);

  Future<void> _sendTestError(BuildContext context) async {
    try {
      throw Exception('🧪 Тестова помилка для Sentry - користувач натиснув кнопку');
    } catch (error, stackTrace) {
      try {
        await Sentry.captureException(
          error,
          stackTrace: stackTrace,
        );
        // Коротке підтвердження для користувача
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Тестова помилка відправлена в Sentry'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не вдалося відправити в Sentry'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.center,
        child: OutlinedButton.icon(
          onPressed: () => _sendTestError(context),
          icon: const Icon(Icons.bug_report_rounded, size: 18, color: Color(0xFF7B6EC9)),
          label: const Text(
            'Відправити тест Sentry',
            style: TextStyle(
              color: Color(0xFF7B6EC9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFEEE8FF)),
            backgroundColor: const Color(0xFFFAF8FF),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}