import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/docstudio_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'document_create_screen.dart';
import 'document_editor_screen.dart';

IconData docTypeIcon(String slug) {
  switch (slug) {
    case 'thesis-project':
      return Icons.school_rounded;
    case 'report':
      return Icons.bar_chart_rounded;
    case 'essay-assignment':
      return Icons.edit_note_rounded;
    case 'presentation':
      return Icons.slideshow_rounded;
    default:
      return Icons.description_rounded;
  }
}

class DocStudioHomeScreen extends StatefulWidget {
  const DocStudioHomeScreen({super.key});

  @override
  State<DocStudioHomeScreen> createState() => _DocStudioHomeScreenState();
}

class _DocStudioHomeScreenState extends State<DocStudioHomeScreen> {
  late Future<({List<DocumentTypeModel> types, bool isSubscriber})> _typesFuture;
  late Future<List<DocumentModel>> _documentsFuture;

  @override
  void initState() {
    super.initState();
    _typesFuture = DocStudioApiService.instance.types();
    _documentsFuture = DocStudioApiService.instance.documents();
  }

  Future<void> _refresh() async {
    setState(() {
      _typesFuture = DocStudioApiService.instance.types();
      _documentsFuture = DocStudioApiService.instance.documents();
    });
    await Future.wait([_typesFuture, _documentsFuture]);
  }

  void _openDocument(int id) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => DocumentEditorScreen(documentId: id)))
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document Studio')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<({List<DocumentTypeModel> types, bool isSubscriber})>(
              future: _typesFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SkeletonList();
                }
                if (snap.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load Document Studio',
                    message: snap.error.toString(),
                    onRetry: () => setState(() => _typesFuture = DocStudioApiService.instance.types()),
                  );
                }
                final result = snap.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PremiumCard(
                      gradient: AppTheme.brandGradient,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                          const SizedBox(height: 10),
                          const Text('AI writes your first draft',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(height: 6),
                          Text(
                            result.isSubscriber
                                ? "You're a subscriber — Document Studio is free."
                                : 'Free for subscribers, or ₦500 per document.',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Start a new document'),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.15,
                      children: [
                        for (final type in result.types)
                          _TypeCard(
                            type: type,
                            onTap: () => Navigator.of(context)
                                .push(MaterialPageRoute(
                                    builder: (_) => DocumentCreateScreen(documentType: type)))
                                .then((_) => _refresh()),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Your documents'),
            const SizedBox(height: 8),
            FutureBuilder<List<DocumentModel>>(
              future: _documentsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SkeletonList();
                }
                final docs = snap.data ?? [];
                if (docs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.note_add_outlined,
                    title: 'No documents yet',
                    message: 'Pick a type above to create your first one.',
                  );
                }
                return Column(
                  children: [
                    for (final doc in docs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DocumentRow(document: doc, onTap: () => _openDocument(doc.id)),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.type, required this.onTap});
  final DocumentTypeModel type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(docTypeIcon(type.slug), color: Colors.white, size: 20),
          ),
          const Spacer(),
          Text(type.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          const SizedBox(height: 2),
          Text(type.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document, required this.onTap});
  final DocumentModel document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updated = DateTime.tryParse(document.updatedAt);
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppTheme.brand.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(docTypeIcon(document.documentType.slug), color: AppTheme.brand, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Pill(document.documentType.name),
                    const SizedBox(width: 6),
                    if (document.isUnlocked)
                      const Icon(Icons.lock_open_rounded, size: 13, color: AppTheme.success)
                    else
                      const Icon(Icons.lock_outline_rounded, size: 13, color: AppTheme.warning),
                    if (updated != null) ...[
                      const SizedBox(width: 6),
                      Text(DateFormat('MMM d').format(updated),
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
