import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/exam_api_service.dart';
import 'mode_select_sheet.dart';
import 'models/exam_models.dart';
import 'take_exam_screen.dart';

/// Shared entry point for both exam-year and material quizzes: offers to
/// resume an in-progress attempt on this exact content if one was left
/// unfinished (see TakeExamScreen's resume marker — mobile apps get
/// killed/backgrounded far more often than a browser tab), otherwise asks
/// for a mode and starts fresh.
Future<void> startOrResumeExam(
  BuildContext context, {
  required ExamKind kind,
  required int contentId,
  required String title,
  required Future<ExamSession> Function(String mode) start,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final marker = prefs.getString('active_exam');
  if (marker != null) {
    final parts = marker.split('|');
    if (parts.length == 4 && parts[0] == kind.name && parts[2] == '$contentId') {
      if (!context.mounted) return;
      final resume = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Resume exam?'),
          content: Text('You have an unfinished attempt at "${parts[3]}".'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Start new')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Resume')),
          ],
        ),
      );
      if (resume == true) {
        try {
          final session = await ExamApiService.instance.resumeExam(kind, parts[1]);
          if (session != null && context.mounted) {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  TakeExamScreen(session: session, title: title, contentId: contentId),
            ));
            return;
          }
        } on ExamException catch (_) {/* fall through to a fresh start below */}
      }
    }
  }

  if (!context.mounted) return;
  final mode = await showExamModeSheet(context);
  if (mode == null || !context.mounted) return;

  try {
    final session = await start(mode);
    if (context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TakeExamScreen(session: session, title: title, contentId: contentId),
      ));
    }
  } on ExamException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
