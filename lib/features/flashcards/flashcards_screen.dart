import 'package:flutter/material.dart';

import '../../core/services/flashcards_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  late Future<List<FlashcardItem>> _future;
  List<FlashcardItem> _cards = [];
  int _index = 0;
  bool _revealed = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FlashcardItem>> _load() async {
    final cards = await FlashcardsApiService.instance.due();
    if (mounted) setState(() => _cards = cards);
    return cards;
  }

  Future<void> _submit(bool gotIt) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final card = _cards[_index];
    try {
      await FlashcardsApiService.instance.review(card.flashcardId, gotIt);
    } on FlashcardsException catch (_) {
      // Best-effort — still advance so the student isn't stuck.
    } finally {
      if (mounted) {
        setState(() {
          _index += 1;
          _revealed = false;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flashcards')),
      body: FutureBuilder<List<FlashcardItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load flashcards',
              message: snap.error.toString(),
              onRetry: () => setState(() => _future = _load()),
            );
          }
          if (_index >= _cards.length) {
            return const EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'All caught up!',
              message: 'No flashcards due right now — come back tomorrow, or miss a '
                  'question on an exam and it will show up here.',
            );
          }
          return _buildDeck(context);
        },
      ),
    );
  }

  Widget _buildDeck(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = _cards[_index];
    final progress = _index / _cards.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 6),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: PremiumCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (card.source.isNotEmpty)
                      Text(card.source,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Text(card.question.text,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16.5, height: 1.4)),
                    const SizedBox(height: 16),
                    for (final option in card.question.options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: (_revealed && option.isCorrect == true)
                                ? AppTheme.success.withOpacity(0.12)
                                : null,
                            border: Border.all(
                              color: (_revealed && option.isCorrect == true)
                                  ? AppTheme.success
                                  : scheme.outlineVariant.withOpacity(0.5),
                            ),
                            borderRadius: BorderRadius.circular(AppTheme.rSm),
                          ),
                          child: Row(
                            children: [
                              Text('${option.label}.',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: (_revealed && option.isCorrect == true)
                                          ? AppTheme.success
                                          : null)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(option.text,
                                    style: TextStyle(
                                        color: (_revealed && option.isCorrect == true)
                                            ? AppTheme.success
                                            : null)),
                              ),
                              if (_revealed && option.isCorrect == true)
                                const Icon(Icons.check, size: 16, color: AppTheme.success),
                            ],
                          ),
                        ),
                      ),
                    if (_revealed &&
                        card.explanation != null &&
                        card.explanation!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(AppTheme.rSm),
                        ),
                        child: Text(card.explanation!,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_revealed)
            FilledButton(
              onPressed: () => setState(() => _revealed = true),
              child: const Text('Show answer'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => _submit(false),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                    child: const Text('Still learning'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : () => _submit(true),
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
                    child: const Text('Got it!'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
