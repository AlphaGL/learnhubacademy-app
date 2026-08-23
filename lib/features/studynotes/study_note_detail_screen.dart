import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/services/studynotes_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'library_note_detail_screen.dart';

const _pricingUrl = '${AppConfig.siteUrl}/pricing/';

// Fixed, small vocabulary matching studynotes/models.py's LEVEL_CHOICES —
// not worth a network round-trip just for this dropdown.
const _levelOptions = [
  ('100L', '100 Level'),
  ('200L', '200 Level'),
  ('300L', '300 Level'),
  ('400L', '400 Level'),
  ('500L', '500 Level'),
  ('600L', '600 Level'),
];

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
  bool _openingPricing = false;
  bool _generating = false;
  bool _generatingAudio = false;
  bool _publishing = false;
  String? _selectedLevel;
  String _selectedTestType = 'cbt';
  final _courseController = TextEditingController();

  @override
  void dispose() {
    _courseController.dispose();
    super.dispose();
  }

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

  Future<void> _openPricing() async {
    setState(() => _openingPricing = true);
    try {
      await launchUrl(Uri.parse(_pricingUrl), mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Subscribe in your browser, then come back and pull to refresh.'),
          duration: Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _openingPricing = false);
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

  Future<void> _publish() async {
    if (_selectedLevel == null || _courseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please choose a level and course.')));
      return;
    }
    setState(() => _publishing = true);
    try {
      final updated = await StudyNotesApiService.instance.publish(
        widget.noteId,
        level: _selectedLevel!,
        courseName: _courseController.text.trim(),
        testType: _selectedTestType,
      );
      if (mounted) setState(() => _note = updated);
    } on StudyNotesException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _publishing = false);
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
          const SizedBox(height: 16),
          _buildPublishSection(note),
        ],
      ],
    );
  }

  Widget _buildPublishSection(StudyNoteModel note) {
    if (note.isPublished) {
      return PremiumCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Published to ${note.level} · ${note.courseName}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LibraryNoteDetailScreen(noteId: note.id),
              )),
              child: const Text('View'),
            ),
          ],
        ),
      );
    }
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Publish to the Level library',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          const SizedBox(height: 6),
          Text(
            'Share this note with other students. AI will generate a CBT or Theory test from it once.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedLevel,
            decoration: const InputDecoration(labelText: 'Level', isDense: true),
            items: [
              for (final (value, label) in _levelOptions)
                DropdownMenuItem(value: value, child: Text(label)),
            ],
            onChanged: (v) => setState(() => _selectedLevel = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _courseController,
            decoration: const InputDecoration(
              labelText: 'Course',
              hintText: 'e.g. MTH201 or Cell Biology',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('CBT'),
                  value: 'cbt',
                  groupValue: _selectedTestType,
                  onChanged: (v) => setState(() => _selectedTestType = v!),
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Theory'),
                  value: 'theory',
                  groupValue: _selectedTestType,
                  onChanged: (v) => setState(() => _selectedTestType = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GradientButton(
            label: _publishing ? 'Generating test…' : 'Publish',
            icon: Icons.upload_rounded,
            loading: _publishing,
            onPressed: _publishing ? null : _publish,
          ),
        ],
      ),
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
          const Text('Subscription required',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 6),
          const Text('Study Notes is a subscriber-only feature — your subscription isn\'t active right now.',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Subscribe',
            icon: Icons.star_rounded,
            loading: _openingPricing,
            onPressed: _openingPricing ? null : _openPricing,
          ),
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
