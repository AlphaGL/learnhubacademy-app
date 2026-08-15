import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/studynotes_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';

class StudyNoteDetailScreen extends StatefulWidget {
  const StudyNoteDetailScreen({super.key, required this.noteId});
  final int noteId;

  @override
  State<StudyNoteDetailScreen> createState() => _StudyNoteDetailScreenState();
}

class _StudyNoteDetailScreenState extends State<StudyNoteDetailScreen> {
  StudyNoteModel? _note;
  bool _loading = true;
  String? _loadError;
  bool _unlocking = false;
  bool _generating = false;
  bool _generatingAudio = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final note = await StudyNotesApiService.instance.detail(widget.noteId);
      if (mounted) setState(() => _note = note);
    } on StudyNotesException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlock() async {
    setState(() => _unlocking = true);
    try {
      final url = await StudyNotesApiService.instance.initiatePayment(widget.noteId);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Complete payment in your browser, then come back and pull to refresh.'),
          duration: Duration(seconds: 5),
        ));
      }
    } on StudyNotesException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final updated = await StudyNotesApiService.instance.generate(widget.noteId);
      if (mounted) setState(() => _note = updated);
    } on StudyNotesException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _generateAudio() async {
    setState(() => _generatingAudio = true);
    try {
      final updated = await StudyNotesApiService.instance.generateAudio(widget.noteId);
      if (mounted) setState(() => _note = updated);
    } on StudyNotesException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _generatingAudio = false);
    }
  }

  Future<void> _playAudio(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await StudyNotesApiService.instance.deleteNote(widget.noteId);
      if (mounted) Navigator.of(context).pop();
    } on StudyNotesException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    return Scaffold(
      appBar: AppBar(
        title: Text(note?.title ?? 'Study Note', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: _loading
          ? const SkeletonList()
          : _loadError != null
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load this note',
                  message: _loadError,
                  onRetry: _load,
                )
              : note == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(onRefresh: _load, child: _buildBody(note)),
    );
  }

  Widget _buildBody(StudyNoteModel note) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: AppTheme.brand.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.brand, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(note.sourceFilename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!note.isUnlocked) _buildPaywall() else _buildGenerateSection(note),
        const SizedBox(height: 16),
        _buildSummary(note),
        if (note.isUnlocked && note.summary.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildAudioSection(note),
        ],
      ],
    );
  }

  Widget _buildPaywall() {
    return PremiumCard(
      gradient: AppTheme.brandGradient,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 28),
          const SizedBox(height: 10),
          const Text('Unlock this note',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 6),
          const Text('Pay ₦500 to get your AI summary, or subscribe for free access.',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          GradientButton(label: 'Unlock for ₦500', loading: _unlocking, onPressed: _unlocking ? null : _unlock),
        ],
      ),
    );
  }

  Widget _buildGenerateSection(StudyNoteModel note) {
    final hasSummary = note.summary.trim().isNotEmpty;
    return GradientButton(
      label: _generating
          ? 'Reading your PDF…'
          : hasSummary
              ? 'Regenerate summary'
              : 'Generate summary',
      icon: Icons.auto_awesome_rounded,
      loading: _generating,
      onPressed: _generating ? null : _generate,
    );
  }

  Widget _buildAudioSection(StudyNoteModel note) {
    final hasAudio = note.audioUrl.isNotEmpty;
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.headphones_rounded, color: AppTheme.brand, size: 20),
              const SizedBox(width: 8),
              const Text('Listen as a conversation',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasAudio
                ? 'AI turned this summary into a two-person conversation.'
                : 'Turn this summary into a natural two-person conversation you can listen to.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          if (hasAudio)
            OutlinedButton.icon(
              onPressed: () => _playAudio(note.audioUrl),
              icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
              label: const Text('Play conversation'),
            )
          else
            OutlinedButton.icon(
              onPressed: _generatingAudio ? null : _generateAudio,
              icon: _generatingAudio
                  ? const SizedBox(
                      height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.mic_rounded, size: 18),
              label: Text(_generatingAudio ? 'Recording conversation…' : 'Generate audio version'),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(StudyNoteModel note) {
    if (note.summary.trim().isEmpty) {
      return EmptyState(
        icon: Icons.file_present_outlined,
        title: note.isUnlocked ? 'No summary yet' : 'Locked',
        message: note.isUnlocked
            ? 'Tap "Generate summary" above and AI will read your PDF and write a revision-ready summary.'
            : 'Unlock this note to generate your summary.',
      );
    }
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: SelectableText(
        note.summary,
        style: const TextStyle(fontSize: 14, height: 1.6),
      ),
    );
  }
}
