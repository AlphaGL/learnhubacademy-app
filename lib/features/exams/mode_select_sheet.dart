import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Bottom sheet to pick Exam Mode (timed, no feedback until the end) or
/// Test Mode (instant feedback + explanation after each answer) — matches
/// the two modes the website itself offers.
Future<String?> showExamModeSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => const _ModeSheet(),
  );
}

class _ModeSheet extends StatelessWidget {
  const _ModeSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.rXl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choose a mode',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            _ModeOption(
              icon: Icons.timer_rounded,
              title: 'Exam Mode',
              subtitle: 'Timed. Results and explanations only at the end.',
              onTap: () => Navigator.of(context).pop('exam'),
            ),
            const SizedBox(height: 12),
            _ModeOption(
              icon: Icons.school_rounded,
              title: 'Test Mode',
              subtitle: 'See if you\'re right after every question, with explanations.',
              onTap: () => Navigator.of(context).pop('test'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(AppTheme.rMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
