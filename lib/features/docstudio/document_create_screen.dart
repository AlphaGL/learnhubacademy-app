import 'package:flutter/material.dart';

import '../../core/services/docstudio_api_service.dart';
import '../../shared/widgets/app_widgets.dart';
import 'document_editor_screen.dart';

class DocumentCreateScreen extends StatefulWidget {
  const DocumentCreateScreen({super.key, required this.documentType});
  final DocumentTypeModel documentType;

  @override
  State<DocumentCreateScreen> createState() => _DocumentCreateScreenState();
}

class _DocumentCreateScreenState extends State<DocumentCreateScreen> {
  final _titleController = TextEditingController();
  final _topicController = TextEditingController();
  late List<TextEditingController> _sectionControllers;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _sectionControllers = widget.documentType.defaultSections
        .map((s) => TextEditingController(text: s))
        .toList();
    if (_sectionControllers.isEmpty) {
      _sectionControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _topicController.dispose();
    for (final c in _sectionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addSectionField() {
    setState(() => _sectionControllers.add(TextEditingController()));
  }

  void _removeSectionField(int index) {
    setState(() {
      _sectionControllers.removeAt(index).dispose();
    });
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    final topic = _topicController.text.trim();
    final sectionTitles = _sectionControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (title.isEmpty || topic.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please add a title and extra instructions.')));
      return;
    }
    if (sectionTitles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Add at least one ${widget.documentType.sectionNoun.toLowerCase()}.')));
      return;
    }

    setState(() => _creating = true);
    try {
      final document = await DocStudioApiService.instance.create(
        typeSlug: widget.documentType.slug,
        title: title,
        topic: topic,
        instructions: '',
        sectionTitles: sectionTitles,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DocumentEditorScreen(documentId: document.id)),
        );
      }
    } on DocStudioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noun = widget.documentType.sectionNoun;
    return Scaffold(
      appBar: AppBar(title: Text('New ${widget.documentType.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _topicController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Extra instructions',
              hintText: "Describe what it's about and any specifics — e.g. Department of "
                  'Computer Science, 300 level, formal tone, focus on practical '
                  'implementation. The more detail, the better the draft.',
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(
            title: '$noun list',
            action: TextButton.icon(
              onPressed: _addSectionField,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
            ),
          ),
          for (var i = 0; i < _sectionControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _sectionControllers[i],
                      decoration: InputDecoration(labelText: '$noun ${i + 1}'),
                    ),
                  ),
                  IconButton(
                    onPressed: _sectionControllers.length > 1 ? () => _removeSectionField(i) : null,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          GradientButton(label: 'Create document', loading: _creating, onPressed: _creating ? null : _create),
        ],
      ),
    );
  }
}
