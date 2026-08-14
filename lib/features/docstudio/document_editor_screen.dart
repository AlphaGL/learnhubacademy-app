import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/services/app_api_client.dart';
import '../../core/services/docstudio_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'docstudio_home_screen.dart' show docTypeIcon;

class DocumentEditorScreen extends StatefulWidget {
  const DocumentEditorScreen({super.key, required this.documentId});
  final int documentId;

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  DocumentModel? _document;
  bool _loading = true;
  String? _loadError;
  bool _unlocking = false;
  bool _generatingAll = false;
  bool _downloading = false;
  final Set<int> _generatingSectionIds = {};

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
      final document = await DocStudioApiService.instance.detail(widget.documentId);
      if (mounted) setState(() => _document = document);
    } on DocStudioException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlock() async {
    setState(() => _unlocking = true);
    try {
      final url = await DocStudioApiService.instance.initiatePayment(widget.documentId);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Complete payment in your browser, then come back and pull to refresh.'),
          duration: Duration(seconds: 5),
        ));
      }
    } on DocStudioException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _generateSection(DocumentSectionModel section) async {
    setState(() => _generatingSectionIds.add(section.id));
    try {
      final updated = await DocStudioApiService.instance.generateSection(widget.documentId, section.id);
      _replaceSection(updated);
    } on DocStudioException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _generatingSectionIds.remove(section.id));
    }
  }

  Future<void> _generateAll() async {
    final doc = _document;
    if (doc?.sections == null) return;
    setState(() => _generatingAll = true);
    for (final section in doc!.sections!) {
      if (!mounted) break;
      setState(() => _generatingSectionIds.add(section.id));
      try {
        final updated =
            await DocStudioApiService.instance.generateSection(widget.documentId, section.id);
        _replaceSection(updated);
      } on DocStudioException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        break;
      } finally {
        if (mounted) setState(() => _generatingSectionIds.remove(section.id));
      }
    }
    if (mounted) setState(() => _generatingAll = false);
  }

  void _replaceSection(DocumentSectionModel updated) {
    final doc = _document;
    if (doc?.sections == null) return;
    setState(() {
      _document = DocumentModel(
        id: doc!.id,
        title: doc.title,
        topic: doc.topic,
        instructions: doc.instructions,
        documentType: doc.documentType,
        isUnlocked: doc.isUnlocked,
        updatedAt: doc.updatedAt,
        sections: [
          for (final s in doc.sections!) if (s.id == updated.id) updated else s,
        ],
      );
    });
  }

  Future<void> _saveSection(int sectionId, {String? title, String? content}) async {
    try {
      await DocStudioApiService.instance
          .saveSection(widget.documentId, sectionId, title: title, content: content);
    } on DocStudioException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _addSection() async {
    try {
      final section = await DocStudioApiService.instance.addSection(widget.documentId, 'New Section');
      final doc = _document;
      if (doc == null) return;
      setState(() {
        _document = DocumentModel(
          id: doc.id,
          title: doc.title,
          topic: doc.topic,
          instructions: doc.instructions,
          documentType: doc.documentType,
          isUnlocked: doc.isUnlocked,
          updatedAt: doc.updatedAt,
          sections: [...(doc.sections ?? []), section],
        );
      });
    } on DocStudioException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteSection(DocumentSectionModel section) async {
    final doc = _document;
    if (doc?.sections == null) return;
    final remaining = doc!.sections!.where((s) => s.id != section.id).toList();
    setState(() {
      _document = DocumentModel(
        id: doc.id,
        title: doc.title,
        topic: doc.topic,
        instructions: doc.instructions,
        documentType: doc.documentType,
        isUnlocked: doc.isUnlocked,
        updatedAt: doc.updatedAt,
        sections: remaining,
      );
    });
    try {
      await DocStudioApiService.instance.deleteSection(widget.documentId, section.id);
    } on DocStudioException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      _load();
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final doc = _document;
    if (doc?.sections == null) return;
    final sections = [...doc!.sections!];
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = sections.removeAt(oldIndex);
    sections.insert(newIndex, moved);
    setState(() {
      _document = DocumentModel(
        id: doc.id,
        title: doc.title,
        topic: doc.topic,
        instructions: doc.instructions,
        documentType: doc.documentType,
        isUnlocked: doc.isUnlocked,
        updatedAt: doc.updatedAt,
        sections: sections,
      );
    });
    try {
      await DocStudioApiService.instance.reorderSections(widget.documentId, sections.map((s) => s.id).toList());
    } on DocStudioException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _download() async {
    final doc = _document;
    if (doc == null) return;
    setState(() => _downloading = true);
    try {
      final token = await AppApiClient.instance.ensureToken();
      final ext = doc.documentType.outputFormat == 'pptx' ? 'pptx' : 'docx';
      final safeTitle = doc.title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
      final filename = '${safeTitle.isEmpty ? 'document' : safeTitle}.$ext';
      final task = DownloadTask(
        url: '${AppConfig.siteUrl}/api/docstudio/documents/${doc.id}/download/',
        filename: filename,
        baseDirectory: BaseDirectory.applicationSupport,
        headers: {'Authorization': 'Bearer $token'},
        updates: Updates.status,
        allowPause: false,
        retries: 1,
      );
      final result = await FileDownloader().download(task);
      if (result.status == TaskStatus.complete) {
        await FileDownloader().moveToSharedStorage(task, SharedStorage.downloads);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Saved $filename to Downloads')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Download ${result.status.name}')));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download failed')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _document;
    return Scaffold(
      appBar: AppBar(
        title: Text(doc?.title ?? 'Document', overflow: TextOverflow.ellipsis),
        actions: [
          if (doc != null && doc.isUnlocked)
            IconButton(
              onPressed: _downloading ? null : _download,
              icon: _downloading
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded),
              tooltip: 'Download',
            ),
        ],
      ),
      body: _loading
          ? const SkeletonList()
          : _loadError != null
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load document',
                  message: _loadError,
                  onRetry: _load,
                )
              : doc == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: !doc.isUnlocked
                          ? _buildPaywall(doc)
                          : _buildEditor(doc),
                    ),
    );
  }

  Widget _buildPaywall(DocumentModel doc) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PremiumCard(
          gradient: AppTheme.brandGradient,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 28),
              const SizedBox(height: 10),
              const Text('Unlock this document',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 6),
              const Text('Pay ₦500 to generate and download this document, or subscribe for free access.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Unlock for ₦500',
                loading: _unlocking,
                onPressed: _unlocking ? null : _unlock,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('${doc.sections?.length ?? 0} ${doc.documentType.sectionNoun.toLowerCase()}(s) ready to write',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildEditor(DocumentModel doc) {
    final sections = doc.sections ?? [];
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
                child: Icon(docTypeIcon(doc.documentType.slug), color: AppTheme.brand, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.documentType.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (doc.topic.isNotEmpty)
                      Text(doc.topic,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SectionHeader(title: '${doc.documentType.sectionNoun}s'),
            ),
            TextButton.icon(
              onPressed: _generatingAll ? null : _addSection,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        GradientButton(
          label: _generatingAll ? 'Generating…' : 'Generate all with AI',
          icon: Icons.auto_awesome_rounded,
          loading: _generatingAll,
          onPressed: _generatingAll || sections.isEmpty ? null : _generateAll,
        ),
        const SizedBox(height: 14),
        if (sections.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No sections yet — add one above.')),
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: _reorder,
            children: [
              for (final section in sections)
                _SectionCard(
                  key: ValueKey(section.id),
                  section: section,
                  generating: _generatingSectionIds.contains(section.id),
                  onGenerate: () => _generateSection(section),
                  onSave: (title, content) => _saveSection(section.id, title: title, content: content),
                  onDelete: () => _deleteSection(section),
                ),
            ],
          ),
      ],
    );
  }
}

class _SectionCard extends StatefulWidget {
  const _SectionCard({
    super.key,
    required this.section,
    required this.generating,
    required this.onGenerate,
    required this.onSave,
    required this.onDelete,
  });

  final DocumentSectionModel section;
  final bool generating;
  final VoidCallback onGenerate;
  final void Function(String? title, String? content) onSave;
  final VoidCallback onDelete;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late FocusNode _titleFocus;
  late FocusNode _contentFocus;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.section.title);
    _contentController = TextEditingController(text: widget.section.content);
    _titleFocus = FocusNode()..addListener(_onTitleFocusChange);
    _contentFocus = FocusNode()..addListener(_onContentFocusChange);
  }

  @override
  void didUpdateWidget(covariant _SectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section.content != widget.section.content && !_contentFocus.hasFocus) {
      _contentController.text = widget.section.content;
    }
    if (oldWidget.section.title != widget.section.title && !_titleFocus.hasFocus) {
      _titleController.text = widget.section.title;
    }
  }

  void _onTitleFocusChange() {
    if (!_titleFocus.hasFocus) widget.onSave(_titleController.text.trim(), null);
  }

  void _onContentFocusChange() {
    if (!_contentFocus.hasFocus) widget.onSave(null, _contentController.text);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = widget.section.content.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
                ReorderableDragStartListener(
                  index: 0,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.drag_handle_rounded, size: 20),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            TextField(
              controller: _contentController,
              focusNode: _contentFocus,
              maxLines: null,
              minLines: 3,
              style: const TextStyle(fontSize: 13.5, height: 1.4),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Not generated yet — tap "Generate" to have AI write this section.',
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: widget.generating
                  ? const SizedBox(
                      height: 32, width: 32, child: CircularProgressIndicator(strokeWidth: 2))
                  : OutlinedButton.icon(
                      onPressed: widget.onGenerate,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: Text(hasContent ? 'Regenerate' : 'Generate'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
